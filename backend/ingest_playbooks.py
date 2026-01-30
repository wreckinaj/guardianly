import os
import glob
from pinecone import Pinecone, ServerlessSpec
from openai import OpenAI
from dotenv import load_dotenv

# 1. Load environment variables from .env file
load_dotenv()

# Retrieve keys safely
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Basic error handling to ensure keys exist
if not PINECONE_API_KEY or not OPENAI_API_KEY:
    raise ValueError("Error: PINECONE_API_KEY or OPENAI_API_KEY missing from .env file")

# 2. Configuration
INDEX_NAME = "guardianly-playbooks"

# Initialize clients
pc = Pinecone(api_key=PINECONE_API_KEY)
client = OpenAI(api_key=OPENAI_API_KEY)

# 3. Create Index if it doesn't exist
existing_indexes = pc.list_indexes().names()
if INDEX_NAME not in existing_indexes:
    print(f"Creating index: {INDEX_NAME}...")
    pc.create_index(
        name=INDEX_NAME,
        dimension=1536,  # Matches text-embedding-3-small
        metric='cosine',
        spec=ServerlessSpec(cloud='aws', region='us-east-1')
    )
else:
    print(f"Index {INDEX_NAME} already exists.")

index = pc.Index(INDEX_NAME)

# 4. Read and Embed Files
playbook_files = glob.glob("mock_playbook_*.txt")

print(f"Found {len(playbook_files)} playbooks to ingest.")

for file_path in playbook_files:
    with open(file_path, "r") as f:
        text_content = f.read()
    
    # Generate Embedding
    try:
        response = client.embeddings.create(
            input=text_content,
            model="text-embedding-3-small"
        )
        embedding = response.data[0].embedding
        
        # Determine hazard type for metadata filtering
        filename = os.path.basename(file_path)
        if "road_closure" in filename:
            hazard_type = "road_closure"
        elif "severe_weather" in filename:
            hazard_type = "severe_weather_rain"
        else:
            hazard_type = "general"

        # Upsert to Pinecone
        index.upsert(vectors=[
            {
                "id": filename,
                "values": embedding,
                "metadata": {
                    "text": text_content,
                    "hazard": hazard_type,
                    "source": filename
                }
            }
        ])
        print(f"Successfully indexed: {filename}")
        
    except Exception as e:
        print(f"Failed to index {filename}: {e}")

print("Ingestion complete.")