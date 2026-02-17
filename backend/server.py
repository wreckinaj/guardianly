from flask import jsonify, request, Flask
import requests
import os
import datetime
import json
from functools import wraps
from marshmallow import ValidationError
import firebase_admin
from firebase_admin import credentials, auth, messaging # Added messaging import
from schemas import GeneratePromptRequestSchema, AlertRecommendationSchema
from pinecone import Pinecone
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# --- Initialize Clients ---
# Ensure these environment variables are set in your deployment environment
pc = Pinecone(api_key=os.environ.get('PINECONE_API_KEY'))
openai_client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))
index = pc.Index("guardianly-playbooks")

# --- Configuration ---
MAPBOX_ACCESS_TOKEN = os.environ.get('MAPBOX_ACCESS_TOKEN', 'your_mapbox_token_here')

# --- Initialize Firebase Admin SDK ---
try:
    # Ensure 'admin_key.json' is present in the backend directory for local dev
    cred = credentials.Certificate("admin_key.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin Initialized")
except Exception as e:
    print(f"Warning: Firebase Admin failed to initialize. Auth will fail. Error: {e}")

# --- Mock Data Storage (In-Memory) ---
notifications = []
mock_notification_settings = {}

# --- Authentication Decorator ---
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            # Verify the Firebase ID token
            decoded_token = auth.verify_id_token(token)
            current_user_uid = decoded_token['uid']
            
        except ValueError:
            return jsonify({'error': 'Invalid token'}), 401
        except auth.ExpiredIdTokenError:
            return jsonify({'error': 'Token has expired'}), 401
        except auth.RevokedIdTokenError:
            return jsonify({'error': 'Token has been revoked'}), 401
        except Exception as e:
            return jsonify({'error': f'Authentication failed: {str(e)}'}), 401
        
        return f(current_user_uid, *args, **kwargs)
    
    return decorated

@app.route('/')
def home():
    return jsonify({
        'message': 'Guardianly Backend API',
        'endpoints': {
            'push_notification': '/api/push (POST, requires auth)',
            'get_notifications': '/api/notifications (GET, requires auth)',
            'generate_prompt': '/api/generate_prompt (POST, requires auth)',
            'geocoding': '/geocode?place=Corvallis',
            'directions': '/directions?start=Corvallis,OR&end=Albany,OR'
        }
    })

# --- Notification Endpoints ---

@app.route('/api/push', methods=['POST'])
@token_required
def push_endpoint(current_user_uid):
    """Send a real Push Notification via Firebase Cloud Messaging"""
    data = request.get_json()
    
    # Validation
    if not data or not data.get("title") or not data.get("message"):
        return jsonify({"error": "Title and message are required"}), 400
    
    registration_token = data.get('fcm_token')
    if not registration_token:
        return jsonify({"error": "FCM Token (fcm_token) is required"}), 400

    # 1. Construct the Message
    message = messaging.Message(
        notification=messaging.Notification(
            title=data["title"],
            body=data["message"],
        ),
        token=registration_token,
    )

    try:
        # 2. Send via Firebase
        response = messaging.send(message)
        
        # 3. Log locally (Optional, for history)
        note = {
            "user": current_user_uid,
            "title": data["title"],
            "message": data["message"],
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "message_id": response
        }
        notifications.append(note)
        print(f"[Notification] Sent to {current_user_uid}: {response}")

        return jsonify({
            "status": "success", 
            "message_id": response,
            "notification": note
        }), 201

    except Exception as e:
        print(f"[Notification Error] {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@token_required
def get_notifications(current_user_uid):
    """Retrieve all notifications for the authenticated user"""
    user_notes = [n for n in notifications if n["user"] == current_user_uid]
    return jsonify({
        "status": "success",
        "count": len(user_notes),
        "notifications": user_notes
    }), 200

@app.route('/api/notifications/settings', methods=['GET'])
@token_required
def get_notification_settings(current_user_uid):
    settings = mock_notification_settings.get(current_user_uid, {"enabled_types": []})
    return jsonify({
        "status": "success",
        "user": current_user_uid,
        "settings": settings
    }), 200

@app.route('/api/notifications/settings', methods=['PUT'])
@token_required
def update_notification_settings(current_user_uid):
    data = request.get_json()
    enabled_types = data.get("enabled_types", [])
    mock_notification_settings[current_user_uid] = {"enabled_types": enabled_types}
    
    return jsonify({
        "status": "success",
        "message": "Notification settings updated",
        "user": current_user_uid,
        "settings": mock_notification_settings[current_user_uid]
    }), 200

# --- Mapbox Endpoints ---

@app.route('/geocode')
def geocode():
    place = request.args.get('place', 'Corvallis OR')
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{place}.json'
    params = {'access_token': MAPBOX_ACCESS_TOKEN, 'limit': 5}
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        return jsonify({'query': place, 'results': response.json().get('features', [])})
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

@app.route('/reverse')
def reverse_geocode():
    lng = request.args.get('lng', '-123.262')
    lat = request.args.get('lat', '44.565')
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json'
    params = {'access_token': MAPBOX_ACCESS_TOKEN}
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        return jsonify({'coordinates': {'lng': lng, 'lat': lat}, 'results': response.json().get('features', [])})
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

@app.route('/directions')
def directions():
    start = request.args.get('start', 'Corvallis,OR')
    end = request.args.get('end', 'Albany,OR')
    profile = request.args.get('profile', 'driving')
    
    try:
        url = f'https://api.mapbox.com/directions/v5/mapbox/{profile}/{start};{end}'
        params = {'access_token': MAPBOX_ACCESS_TOKEN, 'geometries': 'geojson', 'steps': 'true'}
        response = requests.get(url, params=params)
        response.raise_for_status()
        return jsonify({'routes': response.json().get('routes', [])})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- AI & RAG Logic ---

def get_retrieved_context(hazard_key, user_lat, user_lng):
    """
    Embeds the hazard query and retrieves relevant playbook sections from Pinecone.
    """
    query_text = f"Procedures for {hazard_key} hazard near {user_lat}, {user_lng}"
    
    try:
        response = openai_client.embeddings.create(
            input=query_text,
            model="text-embedding-3-small"
        )
        query_vector = response.data[0].embedding

        search_results = index.query(
            vector=query_vector,
            top_k=2,
            include_metadata=True
        )

        context_parts = [match['metadata']['text'] for match in search_results['matches']]
        return "\n---\n".join(context_parts) if context_parts else "No specific playbook found."
    except Exception as e:
        print(f"RAG Retrieval Error: {e}")
        return "Context retrieval failed."

@app.route('/api/generate_prompt', methods=['POST'])
@token_required
def generate_prompt_endpoint(current_user_uid):
    """
    Generates a structured safety recommendation using RAG context and OpenAI.
    """
    try:
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400

    raw_hazard = data['hazard']
    user_lat = data['user_lat']
    user_lng = data['user_lng']
    
    # Normalize hazard string for display
    hazard_display = raw_hazard.replace("_", " ").title()
    
    # 1. Retrieve Context (RAG)
    retrieved_context = get_retrieved_context(raw_hazard, user_lat, user_lng)

    # 2. Construct System Prompt
    system_prompt = """
    You are Guardianly, an advanced safety AI. 
    Your goal is to analyze a hazard and provided safety context to generate a structured alert.

    You must output a VALID JSON object with exactly these keys:
    - "severity": "High", "Moderate", or "Low"
    - "message": A concise, reassuring summary of the situation (1-2 sentences).
    - "actions": A list of 2-3 specific, actionable steps the user should take immediately.
    - "source": "Guardianly AI Agent"

    Base your advice strictly on the provided Context. If the Context is insufficient, provide general safety best practices.
    """

    # 3. Construct User Prompt
    user_message = f"""
    Hazard Type: {hazard_display}
    User Location: {user_lat}, {user_lng}

    Context from Playbooks:
    {retrieved_context}

    Generate the safety recommendation now.
    """

    try:
        # 4. Call OpenAI with JSON mode
        completion = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            response_format={"type": "json_object"},
            temperature=0.3
        )

        # 5. Parse and Validate Response
        llm_response_text = completion.choices[0].message.content
        generated_data = json.loads(llm_response_text)
        
        # Ensure the AI output matches our Schema
        final_recommendation = AlertRecommendationSchema().load(generated_data)
        
        return jsonify({
            "status": "success",
            "hazard": hazard_display,
            "retrieved_context": retrieved_context,
            "recommendation": final_recommendation
        }), 200

    except Exception as e:
        print(f"AI Generation Error: {e}")
        return jsonify({
            "status": "warning",
            "hazard": hazard_display,
            "message": "AI generation unavailable, providing default safety tips.",
            "recommendation": {
                "severity": "Unknown",
                "message": f"Caution: {hazard_display} reported. Please proceed with care.",
                "actions": ["Stay alert", "Check local news", "Move to safety if unsure"],
                "source": "Guardianly System (Fallback)"
            }
        }), 200

if __name__ == "__main__":
    app.run(port=5000, debug=True)