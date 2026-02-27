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
    Now includes mocks for both Embeddings (RAG) and Chat Completions (Generation).
    """
    with patch('server.openai_client') as mock_openai_instance:
        # 1. Setup OpenAI Embeddings Mock (for RAG retrieval)
        mock_embedding_response = MagicMock()
        mock_embedding_response.data = [MagicMock(embedding=[0.1] * 1536)]
        mock_openai_instance.embeddings.create.return_value = mock_embedding_response
        
        # 2. Setup OpenAI Chat Completion Mock (for Generation)
        # We need to simulate the nested structure: response.choices[0].message.content
        mock_chat_completion = MagicMock()
        mock_chat_message = MagicMock()
        
        # This string must match the JSON structure your server expects
        mock_chat_message.content = json.dumps({
            "severity": "High",
            "message": "AI generated safety alert.",
            "actions": ["Take cover", "Avoid area"],
            "source": "Guardianly AI Agent"
        })
        
        # Build the chain: completion -> choices[0] -> message
        mock_choice = MagicMock()
        mock_choice.message = mock_chat_message
        mock_chat_completion.choices = [mock_choice]
        
        mock_openai_instance.chat.completions.create.return_value = mock_chat_completion
        
        with patch('server.index') as mock_pinecone_index:
            # 3. Setup Pinecone Index Mock
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

@pytest.fixture
def mock_messaging():
    """
    Patches the 'messaging' module imported in server.py.
    This captures calls to messaging.Message() and messaging.send().
    """
    with patch('server.messaging') as mock_msg_module:
        yield mock_msg_module

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

def test_push_notification_success(client, auth_headers, mock_messaging):
    """Test successful dispatch of a push notification."""
    
    # 1. Setup Mock: Simulate a successful response from Firebase
    mock_messaging.send.return_value = "projects/guardianly/messages/test_msg_id_123"
    
    payload = {
        "fcm_token": "fake_device_token_xyz",
        "title": "Evacuate",
        "message": "Fire reported in your sector."
    }

    # 2. Execute Request
    response = client.post(
        "/api/push",
        data=json.dumps(payload),
        content_type="application/json",
        headers=auth_headers
    )

    # 3. Assertions
    assert response.status_code == 201
    data = response.get_json()
    
    assert data["status"] == "success"
    assert data["message_id"] == "projects/guardianly/messages/test_msg_id_123"
    
    # Verify messaging.send was called
    mock_messaging.send.assert_called_once()
    
    # --- FIX: Check constructor calls instead of attribute access ---
    
    # 1. Verify Notification was created with the correct text
    mock_messaging.Notification.assert_called_once_with(
        title="Evacuate",
        body="Fire reported in your sector."
    )
    
    # 2. Verify Message was created with the correct token
    # We check call_args.kwargs to ensure the 'token' param was passed correctly
    call_args = mock_messaging.Message.call_args
    assert call_args.kwargs['token'] == "fake_device_token_xyz"

def test_push_notification_firebase_error(client, auth_headers, mock_messaging):
    """Test handling of Firebase errors (e.g., invalid token)."""
    
    # 1. Setup Mock: Simulate an exception from Firebase
    mock_messaging.send.side_effect = Exception("Invalid registration token")
    
    payload = {
        "fcm_token": "bad_token",
        "title": "Test",
        "message": "This should fail"
    }

    # 2. Execute Request
    response = client.post(
        "/api/push",
        data=json.dumps(payload),
        content_type="application/json",
        headers=auth_headers
    )

    # 3. Assertions
    assert response.status_code == 500
    data = response.get_json()
    assert "Invalid registration token" in data["error"]