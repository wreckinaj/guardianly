import pytest
import json
import sys
import os

# Add the backend directory to sys.path so we can import server.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server import app as flask_app

@pytest.fixture
def client():
    flask_app.config['TESTING'] = True
    with flask_app.test_client() as client:
        yield client

@pytest.fixture
def auth_token(client):
    """Logs in a test user to retrieve a valid JWT token."""
    login_payload = {
        "username": "testuser",
        "password": "testpass123"
    }
    response = client.post(
        '/api/login',
        data=json.dumps(login_payload),
        content_type='application/json'
    )
    data = response.get_json()
    return data['token']

def test_generate_prompt_mapbox_mock(client, auth_token):
    # 1. Mock Mapbox Response (Optional: Logic currently hardcoded in server.py)
    # Since get_retrieved_context in server.py uses simulated strings, 
    # patching isn't strictly needed yet, but here is how you set up the request.

    payload = {
        "hazard": "Road Closure",
        "user_lat": 44.95,
        "user_lng": -123.03
    }

    # 2. Make the request with the Authorization header
    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(payload),
        content_type="application/json",
        headers={"Authorization": f"Bearer {auth_token}"}
    )

    # 3. Assertions
    assert response.status_code == 200
    data = response.get_json()

    # Check for the simulated prototype success keys
    assert data["status"] == "prototype_success"
    assert "retrieved_context" in data
    assert "final_prompt_to_llm" in data
    
    # Verify the content reflects the hazard type
    assert "road-closure" in data["retrieved_context"]