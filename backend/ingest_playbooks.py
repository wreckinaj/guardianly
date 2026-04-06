import os
import glob
from pinecone import Pinecone, ServerlessSpec
from openai import OpenAI
from dotenv import load_dotenv

# 1. Load environment variables
load_dotenv(override=True)

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not PINECONE_API_KEY or not OPENAI_API_KEY:
    raise ValueError("Error: API keys missing from .env file")

# 2. Configuration
INDEX_NAME = "guardianly-playbooks"

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

# 4. Read and Embed Files from the 'playbooks' subdirectory
script_dir = os.path.dirname(os.path.abspath(__file__))
playbooks_dir = os.path.join(script_dir, "playbooks")
search_pattern = os.path.join(playbooks_dir, "mock_playbook_*.txt")

playbook_files = glob.glob(search_pattern)
print(f"Found {len(playbook_files)} playbooks to ingest in '{playbooks_dir}'.")

for file_path in playbook_files:
    # Define filename first
    filename = os.path.basename(file_path)
    
    with open(file_path, "r", encoding="utf-8") as f:
        text_content = f.read()
    
    try:
        # Generate Embedding
        response = client.embeddings.create(
            input=text_content,
            model="text-embedding-3-small"
        )
        embedding = response.data[0].embedding
        
        # Expanded hazard type mapping based on the filename
        # Ensure your filenames match these keywords (e.g. 'mock_playbook_flood.txt')
        hazard_type = "general"
        if "flood" in filename: hazard_type = "flood"
        elif "building_fire" in filename: hazard_type = "building_fire"
        elif "wildfire" in filename: hazard_type = "wildfire"
        elif "hurricane" in filename: hazard_type = "hurricane"
        elif "tornado" in filename: hazard_type = "tornado"
        elif "active_shooter" in filename: hazard_type = "active_shooter"
        elif "police_activity" in filename: hazard_type = "police_activity"
        elif "road_closure" in filename: hazard_type = "road_closure"
        elif "severe_weather" in filename: hazard_type = "severe_weather"
        elif "earthquake" in filename: hazard_type = "earthquake"
        elif "hazmat" in filename: hazard_type = "hazmat_spill"
        elif "gas_leak" in filename: hazard_type = "gas_leak"
        elif "volcanic" in filename or "volcano" in filename: hazard_type = "volcanic_eruption"
        elif "tsunami" in filename: hazard_type = "tsunami"
        elif "power_outage" in filename: hazard_type = "power_outage"
        elif "icy_roads" in filename: hazard_type = "icy_roads"
        elif "heavy_traffic" in filename: hazard_type = "heavy_traffic"
        elif "construction" in filename: hazard_type = "construction_zone"
        elif "low_visibility" in filename: hazard_type = "low_visibility"
        elif "wildlife" in filename: hazard_type = "wildlife"
        elif "civil_unrest" in filename: hazard_type = "civil_unrest"
        elif "transit_disruption" in filename: hazard_type = "transit_disruption"
        elif "extreme_heat" in filename: hazard_type = "extreme_heat"
        elif "air_quality" in filename: hazard_type = "air_quality"
        elif "blizzard" in filename: hazard_type = "blizzard"
        elif "flooded_pathway" in filename: hazard_type = "flooded_pathway"
        elif "suspicious_package" in filename: hazard_type = "suspicious_package"
        elif "sinkhole" in filename: hazard_type = "sinkhole"
        elif "downed_power_lines" in filename: hazard_type = "downed_power_lines"

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
        print(f"Successfully indexed: {filename} as '{hazard_type}'")
        
    except Exception as e:
        print(f"Failed to index {filename}: {e}")

print("Ingestion complete.")