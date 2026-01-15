import pytest
import json
import sys
import os
from unittest.mock import MagicMock, patch

# --- STEP 1: Mock External Modules BEFORE Import ---
# We replace the real 'pinecone' and 'openai' modules with Mocks in sys.modules.
# This ensures that when server.py runs "from pinecone import Pinecone", it gets our Mock.
# This prevents the real code from trying to connect to the internet during import.

mock_pinecone_module = MagicMock()
sys.modules["pinecone"] = mock_pinecone_module

mock_openai_module = MagicMock()
sys.modules["openai"] = mock_openai_module

# --- STEP 2: Set Dummy Environment Variables ---
# Prevents KeyErrors if code accesses os.environ directly
os.environ['PINECONE_API_KEY'] = 'testing'
os.environ['OPENAI_API_KEY'] = 'testing'
os.environ['MAPBOX_ACCESS_TOKEN'] = 'testing'

# --- STEP 3: Add Backend Path and Import Server ---
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server import app as flask_app

# --- STEP 4: Test Fixtures ---

@pytest.fixture
def client():
    flask_app.config['TESTING'] = True
    with flask_app.test_client() as client:
        yield client

@pytest.fixture
def mock_auth():
    """Patches Firebase auth in server.py"""
    with patch('server.auth.verify_id_token') as mock_verify:
        yield mock_verify

@pytest.fixture
def mock_rag_dependencies():
    """
    Patches the *instances* of clients that server.py created.
    Even though we mocked the module above, we use 'patch' here to 
    reset the mocks and define specific return values for each test.
    """
    with patch('server.openai_client') as mock_openai_instance:
        # 1. Setup OpenAI Mock
        mock_embedding_response = MagicMock()
        # Mocking the embedding vector response
        mock_embedding_response.data = [MagicMock(embedding=[0.1] * 1536)]
        mock_openai_instance.embeddings.create.return_value = mock_embedding_response
        
        with patch('server.index') as mock_pinecone_index:
            # 2. Setup Pinecone Index Mock
            # This mimics the response from index.query()
            mock_pinecone_index.query.return_value = {
                'matches': [
                    {
                        'id': 'mock_playbook_123',
                        'score': 0.95,
                        'metadata': {
                            'text': 'Mock Playbook Content: Road closures require detours.',
                            'hazard': 'road_closure'
                        }
                    }
                ]
            }
            
            yield mock_openai_instance, mock_pinecone_index

@pytest.fixture
def auth_headers(mock_auth):
    mock_auth.return_value = {'uid': 'test_firebase_uid_123'}
    return {"Authorization": "Bearer dummy_token"}

# --- STEP 5: Tests ---

def test_generate_prompt_with_rag(client, auth_headers, mock_rag_dependencies):
    payload = {
        "hazard": "Road Closure",
        "user_lat": 44.95,
        "user_lng": -123.03
    }

    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(payload),
        content_type="application/json",
        headers=auth_headers
    )

    assert response.status_code == 200
    data = response.get_json()

    assert data["status"] == "success"
    # Ensure the context comes from our mock, not the real file/DB
    assert "Mock Playbook Content" in data["retrieved_context"]
    
    recommendation = data["recommendation"]
    assert recommendation["severity"] in ["High", "Moderate", "Low"]
    assert recommendation["source"] == "Guardianly AI Agent"

def test_generate_prompt_validation_error(client, auth_headers):
    invalid_payload = {
        "user_lat": 44.95,
        "user_lng": -123.03
    }
    
    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(invalid_payload),
        content_type="application/json",
        headers=auth_headers
    )
    
    assert response.status_code == 400
    data = response.get_json()
    assert "Invalid input data" in data["error"]