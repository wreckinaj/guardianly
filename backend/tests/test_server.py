import pytest
import json
import sys
import os
from unittest.mock import patch

# Add the backend directory to sys.path so we can import server.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server import app as flask_app

@pytest.fixture
def client():
    flask_app.config['TESTING'] = True
    with flask_app.test_client() as client:
        yield client

@pytest.fixture
def mock_auth():
    """
    Patches the Firebase auth.verify_id_token function in server.py.
    This prevents the test from trying to contact real Firebase servers.
    """
    with patch('server.auth.verify_id_token') as mock_verify:
        yield mock_verify

@pytest.fixture
def auth_headers(mock_auth):
    """
    Configures the mock to accept a dummy token and returns the headers.
    """
    # When server.py calls auth.verify_id_token('dummy_token'), return this user dict:
    mock_auth.return_value = {'uid': 'test_firebase_uid_123'}
    
    return {"Authorization": "Bearer dummy_token"}

def test_generate_prompt_mapbox_mock(client, auth_headers):
    """
    Tests the /api/generate_prompt endpoint using the mocked auth headers.
    """
    payload = {
        "hazard": "Road Closure",
        "user_lat": 44.95,
        "user_lng": -123.03
    }

    # 1. Make the request with the Mocked Authorization header
    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(payload),
        content_type="application/json",
        headers=auth_headers
    )

    # 2. Assertions
    assert response.status_code == 200
    data = response.get_json()

    assert data["status"] == "success"
    assert data["hazard"] == "Road Closure"
    assert "retrieved_context" in data
    assert "recommendation" in data 

    # Verify the content reflects the hazard type
    assert "road-closure" in data["retrieved_context"]
    
    recommendation = data["recommendation"]
    assert recommendation["severity"] == "High"
    assert "message" in recommendation
    assert isinstance(recommendation["actions"], list)
    assert recommendation["source"] == "Guardianly AI Agent"


def test_generate_prompt_validation_error(client, auth_headers):
    """
    Tests the validation logic for required fields.
    """
    invalid_payload = {
        # 'hazard' is missing
        "user_lat": 44.95,
        "user_lng": -123.03
    }
    
    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(invalid_payload),
        content_type="application/json",
        headers=auth_headers
    )
    
    # Expect a 400 Bad Request due to ValidationError
    assert response.status_code == 400
    data = response.get_json()
    assert "Invalid input data" in data["error"]
    assert "hazard" in data["messages"]