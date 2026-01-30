from flask import jsonify, request, Flask
import requests
import os
import datetime
from functools import wraps
from marshmallow import ValidationError
import firebase_admin
from firebase_admin import credentials, auth
from schemas import GeneratePromptRequestSchema, AlertRecommendationSchema
from pinecone import Pinecone
from openai import OpenAI

app = Flask(__name__)

# Initialize Clients
pc = Pinecone(api_key=os.environ.get('PINECONE_API_KEY'))
openai_client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))
index = pc.Index("guardianly-playbooks")

# --- Configuration ---
MAPBOX_ACCESS_TOKEN = os.environ.get('MAPBOX_ACCESS_TOKEN', 'your_mapbox_token_here')

# Initialize Firebase Admin SDK
# ERROR HANDLING NOTE: Ensure 'serviceAccountKey.json' is in your backend directory
# and added to .gitignore so you don't commit it!
try:
    cred = credentials.Certificate("admin_key.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin Initialized")
except Exception as e:
    print(f"Warning: Firebase Admin failed to initialize. Auth will fail. Error: {e}")

# --- Mock Data Storage (In-Memory) ---
# In a real app, these would also be in Firestore, but we keep them here
# to support your existing notification endpoints without breaking them.
# Keys are now Firebase UIDs instead of simple usernames.
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
            
            # The 'uid' is the unique Firebase user ID
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
            'get_notification_settings': '/api/notifications/settings (GET, requires auth)',
            'update_notification_settings': '/api/notifications/settings (PUT, requires auth)',
            'generate_prompt': '/api/generate_prompt (POST, requires auth)',
            'geocoding': '/geocode?place=Corvallis OR',
            'reverse_geocoding': '/reverse?lng=-123.262&lat=44.565',
            'directions': '/directions?start=Corvallis,OR&end=Albany,OR'
        }
    })

# --- Notification Endpoints ---

@app.route('/api/push', methods=['POST'])
@token_required
def push_endpoint(current_user_uid):
    """Send/Store push notification (requires authentication)"""
    data = request.get_json()
    if not data or not data.get("title") or not data.get("message"):
        return jsonify({"error": "Title and message are required"}), 400

    note = {
        "user": current_user_uid, # Storing against Firebase UID
        "title": data["title"],
        "message": data["message"],
        "timestamp": datetime.datetime.utcnow().isoformat()
    }
    notifications.append(note)
    print(f"[Notification] For User {current_user_uid}: {note}")

    return jsonify({
        "status": "success",
        "message": "Notification stored successfully",
        "notification": note
    }), 201

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
    """Get user notification settings (mocked in memory)"""
    settings = mock_notification_settings.get(current_user_uid, {"enabled_types": []})
    return jsonify({
        "status": "success",
        "user": current_user_uid,
        "settings": settings
    }), 200

@app.route('/api/notifications/settings', methods=['PUT'])
@token_required
def update_notification_settings(current_user_uid):
    """Update user notification settings"""
    data = request.get_json()
    enabled_types = data.get("enabled_types", [])
    
    # Save or update settings in memory
    mock_notification_settings[current_user_uid] = {"enabled_types": enabled_types}
    
    return jsonify({
        "status": "success",
        "message": "Notification settings updated",
        "user": current_user_uid,
        "settings": mock_notification_settings[current_user_uid]
    }), 200

# --- Mapbox & Logic Endpoints ---

@app.route('/geocode')
def geocode():
    """Forward geocoding - convert place name to coordinates"""
    place = request.args.get('place', 'Corvallis OR')
    
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{place}.json'
    params = {
        'access_token': MAPBOX_ACCESS_TOKEN,
        'limit': 5
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        return jsonify({
            'query': place,
            'results': data.get('features', [])
        })
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

@app.route('/reverse')
def reverse_geocode():
    """Reverse geocoding - convert coordinates to place name"""
    lng = request.args.get('lng', '-123.262')
    lat = request.args.get('lat', '44.565')
    
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json'
    params = {
        'access_token': MAPBOX_ACCESS_TOKEN
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        return jsonify({
            'coordinates': {'lng': lng, 'lat': lat},
            'results': data.get('features', [])
        })
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

def is_place_name(location):
    if ',' not in location:
        return True
    cleaned = location.replace(',', '').replace('.', '').replace('-', '')
    return not cleaned.isdigit()

@app.route('/directions')
def directions():
    """Get directions between two points"""
    start = request.args.get('start', 'Corvallis,OR')
    end = request.args.get('end', 'Albany,OR')
    profile = request.args.get('profile', 'driving')
    
    try:
        if is_place_name(start):
            geocode_url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{start}.json'
            geocode_params = {'access_token': MAPBOX_ACCESS_TOKEN, 'limit': 1}
            start_response = requests.get(geocode_url, params=geocode_params)
            start_response.raise_for_status()
            start_coords = start_response.json()['features'][0]['geometry']['coordinates']
            start_coords_str = f"{start_coords[0]},{start_coords[1]}"
        else:
            start_coords_str = start
        
        if is_place_name(end):
            geocode_url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{end}.json'
            geocode_params = {'access_token': MAPBOX_ACCESS_TOKEN, 'limit': 1}
            end_response = requests.get(geocode_url, params=geocode_params)
            end_response.raise_for_status()
            end_coords = end_response.json()['features'][0]['geometry']['coordinates']
            end_coords_str = f"{end_coords[0]},{end_coords[1]}"
        else:
            end_coords_str = end
        
        url = f'https://api.mapbox.com/directions/v5/mapbox/{profile}/{start_coords_str};{end_coords_str}'
        params = {
            'access_token': MAPBOX_ACCESS_TOKEN,
            'geometries': 'geojson',
            'steps': 'true'
        }
        
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        return jsonify({
            'start': start,
            'end': end,
            'profile': profile,
            'routes': data.get('routes', [])
        })
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

# --- Prompt Generation / RAG Logic ---

def get_retrieved_context(hazard_key, user_lat, user_lng):
    """
    Real RAG: Embeds the hazard query and retrieves relevant playbook sections.
    """
    # 1. Create a query vector based on the hazard
    query_text = f"Procedures for {hazard_key} hazard near {user_lat}, {user_lng}"
    
    response = openai_client.embeddings.create(
        input=query_text,
        model="text-embedding-3-small"
    )
    query_vector = response.data[0].embedding

    # 2. Query Pinecone
    search_results = index.query(
        vector=query_vector,
        top_k=2,
        include_metadata=True
    )

    # 3. Format the results into a string for the LLM
    context_parts = []
    for match in search_results['matches']:
        context_parts.append(match['metadata']['text'])
    
    return "\n---\n".join(context_parts) if context_parts else "No specific playbook found."

@app.route('/api/generate_prompt', methods=['POST'])
@token_required
def generate_prompt_endpoint(current_user_uid):
    """
    Generates a structured safety recommendation using RAG context.
    """
    try:
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400

    raw_hazard = data['hazard']
    user_lat = data['user_lat']
    user_lng = data['user_lng']

    HAZARDS = {
        "road_closure": "Road Closure",
        "severe_weather_rain": "Severe Weather (Heavy Rain)",
    }
    
    hazard_key = raw_hazard.strip().lower().replace(" ", "_")

    if hazard_key not in HAZARDS:
        return jsonify({
            "error": f"Invalid hazard type provided: '{raw_hazard}'",
            "allowed": list(HAZARDS.values())
        }), 400

    hazard_display = HAZARDS[hazard_key]
    retrieved_context = get_retrieved_context(hazard_key, user_lat, user_lng)

    # Mock LLM Logic
    if hazard_key == "road_closure":
        mock_llm_response = {
            "severity": "High",
            "message": "Immediate road closure detected. A guaranteed, safe detour route is calculated.",
            "actions": [
                "Immediately divert to the new Mapbox suggested route.",
                "Verify the entire route is clear after starting the detour.",
                f"Be aware of the nearest police station for assistance, as noted in context: {retrieved_context.split('|')[-1].strip()}"
            ],
            "source": "Guardianly AI Agent"
        }
    elif hazard_key == "severe_weather_rain":
        mock_llm_response = {
            "severity": "Moderate",
            "message": "Severe rain is making travel hazardous. Please find a safe covered shelter to pause your trip.",
            "actions": [
                "Find and park at the nearest covered shelter (0.5 miles away).",
                "Wait for the weather alert to pass.",
                "If waiting is not possible, significantly reduce your speed and use hazard lights."
            ],
            "source": "Guardianly AI Agent"
        }
    else:
         mock_llm_response = {
            "severity": "Low",
            "message": "Default caution alert triggered. No critical hazard detected.",
            "actions": ["Proceed with caution.", "Check local news for any further updates."],
            "source": "Guardianly AI Agent"
        }

    try:
        final_recommendation = AlertRecommendationSchema().dump(mock_llm_response)
        
        return jsonify({
            "status": "success",
            "hazard": hazard_display,
            "retrieved_context": retrieved_context,
            "recommendation": final_recommendation
        }), 200

    except ValidationError as err:
        return jsonify({"error": "Failed to serialize recommendation (Internal Error)", "messages": err.messages}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)