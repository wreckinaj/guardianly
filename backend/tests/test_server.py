import pytest
import json
import sys
import os

# Add the backend directory to sys.path so we can import server.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server import app as flask_app
# NOTE: To run this file successfully, you must ensure 'schemas.py' exists 
# and Flask/Marshmallow/PyJWT are installed as per the README.

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
    """
    Tests the updated /api/generate_prompt endpoint for the 'Road Closure' hazard.
    The test now expects a structured JSON object in the response.
    """
    payload = {
        "hazard": "Road Closure",
        "user_lat": 44.95,
        "user_lng": -123.03
    }

    # 1. Make the request with the Authorization header
    response = client.post(
        "/api/generate_prompt",
        data=json.dumps(payload),
        content_type="application/json",
        headers={"Authorization": f"Bearer {auth_token}"}
    )

    # 2. Assertions
    assert response.status_code == 200
    data = response.get_json()

    # Assertions for the NEW response structure
    assert data["status"] == "success" # No longer "prototype_success"
    assert data["hazard"] == "Road Closure"
    assert "retrieved_context" in data
    assert "recommendation" in data # New key for the structured object

    # Verify the content reflects the hazard type
    assert "road-closure" in data["retrieved_context"]
    
    # Assertions for the structured recommendation object
    recommendation = data["recommendation"]
    assert isinstance(recommendation, dict)
    assert recommendation["severity"] == "High"
    assert "message" in recommendation
    assert isinstance(recommendation["actions"], list)
    assert recommendation["source"] == "Guardianly AI Agent"


def test_generate_prompt_validation_error(client, auth_token):
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
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    # Expect a 400 Bad Request due to ValidationError
    assert response.status_code == 400
    data = response.get_json()
    assert "Invalid input data" in data["error"]
    assert "hazard" in data["messages"] # Checks that the 'hazard' field caused the error