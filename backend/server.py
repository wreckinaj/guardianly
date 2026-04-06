from flask import jsonify, request, Flask
from flask_cors import CORS
from flask_caching import Cache
import requests
import os
import datetime
import json
from functools import wraps
from marshmallow import ValidationError
import firebase_admin
from firebase_admin import credentials, auth, messaging, firestore
from schemas import GeneratePromptRequestSchema, AlertRecommendationSchema
from pinecone import Pinecone
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# --- Cache Configuration ---
app.config['CACHE_TYPE'] = 'SimpleCache'
app.config['CACHE_DEFAULT_TIMEOUT'] = 86400 # 24 hours in seconds
cache = Cache(app)

CORS(app)

# --- Initialize Clients ---
pc = Pinecone(api_key=os.environ.get('PINECONE_API_KEY'))
openai_client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))
index = pc.Index("guardianly-playbooks")

MAPBOX_ACCESS_TOKEN = os.environ.get('MAPBOX_ACCESS_TOKEN', 'your_mapbox_token_here')

# --- Initialize Firebase Admin SDK ---
try:
    cred = credentials.Certificate("admin_key.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase Admin & Firestore Initialized")
except Exception as e:
    print(f"Warning: Firebase Admin failed to initialize. Error: {e}")

# --- Security Checkpoint ---
def check_token(f):
    @wraps(f)
    def wrap(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'status': 'error', 'message': 'Missing or invalid token'}), 401
        
        try:
            token = auth_header.split('Bearer ')[1]
            decoded_token = auth.verify_id_token(token)
            request.uid = decoded_token['uid'] 
        except Exception as e:
            return jsonify({'status': 'error', 'message': f'Invalid token: {str(e)}'}), 401
            
        return f(*args, **kwargs)
    return wrap

@app.route('/')
def home():
    return jsonify({
        'message': 'Guardianly Backend API',
        'endpoints': {
            'profile': '/api/profile (GET, requires auth)',
            'push_notification': '/api/push (POST, requires auth)',
            'get_notifications': '/api/notifications (GET, requires auth)',
            'create_alert': '/api/alerts (POST)',
            'generate_prompt': '/api/generate_prompt (POST, requires auth)',
            'geocoding': '/geocode?place=Corvallis',
            'directions': '/directions?start=Corvallis,OR&end=Albany,OR'
        }
    })

# --- User & Profile Endpoints ---
@app.route('/api/profile', methods=['GET'])
@check_token
def get_profile():
    try:
        user_uid = request.uid 
        user_doc_ref = db.collection('users').document(user_uid)
        user_doc = user_doc_ref.get()
        
        if user_doc.exists:
            return jsonify({'status': 'success', 'profile': user_doc.to_dict()}), 200
        else:
            return jsonify({'status': 'error', 'message': 'User profile not found'}), 404
            
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

# --- Alert & Notification Endpoints ---
@app.route('/api/alerts', methods=['POST'])
def save_alert():
    try:
        data = request.get_json()
        new_alert_ref = db.collection('alerts').document()
        
        alert_payload = {
            'title': data.get('title', 'System Alert'),
            'message': data.get('message', ''),
            'hazardType': data.get('hazardType', 'general'),
            'lat': data.get('lat', 0.0),
            'lng': data.get('lng', 0.0),
            'timestamp': firestore.SERVER_TIMESTAMP 
        }
        
        new_alert_ref.set(alert_payload)
        
        return jsonify({'status': 'success', 'message': 'Alert saved to Firestore!', 'id': new_alert_ref.id}), 201
        
    except Exception as e:
        print(f"Error saving alert: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@check_token
def get_notifications():
    try:
        user_uid = request.uid
        alerts_ref = db.collection('alerts')
        docs = alerts_ref.order_by('timestamp', direction=firestore.Query.DESCENDING).stream()
        
        notifications = []
        for doc in docs:
            alert_data = doc.to_dict()
            alert_data['id'] = doc.id 
            if 'timestamp' in alert_data and alert_data['timestamp'] is not None:
                alert_data['timestamp'] = alert_data['timestamp'].isoformat()
            notifications.append(alert_data)
            
        return jsonify({'status': 'success', 'notifications': notifications}), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/push', methods=['POST'])
@check_token
def push_endpoint():
    data = request.get_json()
    if not data or not data.get("title") or not data.get("message"):
        return jsonify({"error": "Title and message are required"}), 400
    
    registration_token = data.get('fcm_token')
    if not registration_token:
        return jsonify({"error": "FCM Token (fcm_token) is required"}), 400

    lat = data.get("lat", 44.5646) 
    lng = data.get("lng", -123.2620)
    icon = data.get("icon", "warning")
    color = data.get("color", "red")

    message = messaging.Message(
        notification=messaging.Notification(
            title=data["title"],
            body=data["message"],
        ),
        data={
            "lat": str(lat),   
            "lng": str(lng),
            "icon": icon,
            "color": color
        },
        token=registration_token,
    )

    try:
        response = messaging.send(message)
        db.collection('alerts').add({
            "user": request.uid,
            "title": data["title"],
            "message": data["message"],
            "hazardType": data.get('hazardType', 'general'),
            "lat": lat,          
            "lng": lng,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "message_id": response
        })
        return jsonify({"status": "success", "message_id": response}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Mapbox Endpoints & Helpers ---
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

def get_human_readable_location(lat, lng):
    """Helper function to get spatial context before hitting the LLM"""
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json'
    params = {'access_token': MAPBOX_ACCESS_TOKEN}
    try:
        response = requests.get(url, params=params, timeout=3)
        if response.status_code == 200:
            features = response.json().get('features', [])
            if features:
                # Return the most relevant local place name (e.g., street or neighborhood)
                return features[0].get('place_name', f"coordinates {lat}, {lng}")
    except Exception:
        pass
    return f"coordinates {lat}, {lng}"

# --- AI & RAG Logic ---

# 1. Enforce strict Supported Hazards Whitelist
SUPPORTED_HAZARDS = {
    "flood", "building_fire", "wildfire", "hurricane", 
    "tornado", "active_shooter", "police_activity", 
    "road_closure", "severe_weather", "earthquake", 
    "hazmat_spill", "gas_leak", "volcanic_eruption", "tsunami"
}

@cache.memoize(timeout=86400) 
def get_retrieved_context(hazard_key):
    query_text = f"Standard operating procedures and protocols for a {hazard_key} emergency."
    
    try:
        response = openai_client.embeddings.create(
            input=query_text,
            model="text-embedding-3-small"
        )
        query_vector = response.data[0].embedding

        search_results = index.query(
            vector=query_vector,
            top_k=1, 
            include_metadata=True,
            filter={"hazard": {"$eq": hazard_key}} 
        )

        # 1. Pinecone v3 requires dot notation
        matches = search_results.matches
        
        if not matches:
            print(f"RAG Warning: No playbooks found matching filter '{hazard_key}'")
            return None 
            
        top_match = matches[0]
        score = top_match.score
        
        # Log the score so you can tune your threshold
        print(f"RAG Success: Found playbook for '{hazard_key}' with similarity score: {score}")

        # 2. Adjusted threshold. Text-embedding-3-small cosine scores 
        # often hover between 0.40 and 0.60 for related concepts.
        SIMILARITY_THRESHOLD = 0.40 
        
        if score < SIMILARITY_THRESHOLD:
            print(f"RAG Warning: Match rejected. Score {score} is below threshold {SIMILARITY_THRESHOLD}")
            return None

        return top_match.metadata.get('text', '')
        
    except Exception as e:
        # Ensures Python errors aren't silently swallowed
        print(f"RAG Retrieval Critical Error: {type(e).__name__} - {str(e)}") 
        return None

@cache.memoize(timeout=3600) 
def generate_ai_recommendation(hazard_display, event_description, retrieved_context, location_string):
    system_prompt = """
    You are Guardianly, an advanced safety AI. 
    Your goal is to analyze a specific hazard event and provided safety context to generate a structured alert.

    You must output a VALID JSON object with exactly these keys:
    - "severity": "High", "Moderate", "Low", or "Unknown"
    - "message": A concise summary tailoring the playbook to the Specific Event Details.
    - "actions": A list of 2-3 specific, actionable steps.
    - "source": "Guardianly AI Agent"

    CRITICAL RULE: You must adapt the 'Context from Playbooks' to fit the 'Specific Event Details'. If the playbook mentions 'Heavy Rain' but the specific event is just 'Slippery Conditions', focus your advice on the slippery conditions while using the playbook's broader procedures (like finding safe parking).
    """

    user_message = f"""
    Hazard Type: {hazard_display}
    Specific Event Details: {event_description}
    User Location: {location_string}

    Context from Playbooks:
    {retrieved_context if retrieved_context else "None available."}

    Generate the safety recommendation now.
    """
    
    completion = openai_client.chat.completions.create(
        model="gpt-4o-mini", # Upgraded model for better JSON adherence
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        response_format={"type": "json_object"},
        temperature=0.0 # Set to 0 to eliminate creative hallucination
    )

    llm_response_text = completion.choices[0].message.content
    generated_data = json.loads(llm_response_text)
    return AlertRecommendationSchema().load(generated_data)

@app.route('/api/generate_prompt', methods=['POST'])
@check_token
def generate_prompt_endpoint():
    # 1. Validate incoming request data from the frontend
    try:
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400

    raw_hazard = data['hazard'].lower()
    user_lat = data['user_lat']
    user_lng = data['user_lng']
    event_description = data.get('event_description', 'No specific details provided.')
    
    hazard_display = raw_hazard.replace("_", " ").title()

    # 2. Pre-Flight Whitelist Check
    if raw_hazard not in SUPPORTED_HAZARDS:
        return jsonify({
            "status": "warning",
            "hazard": hazard_display,
            "message": "Hazard type not recognized by standard playbooks.",
            "recommendation": {
                "severity": "Unknown",
                "message": f"Caution: {hazard_display} reported. No specific procedures available.",
                "actions": ["Stay alert", "Monitor local news channels"],
                "source": "Guardianly System (Fallback)"
            }
        }), 200
    
    # 3. Main RAG and AI Generation Flow
    try:
        # Convert coordinates into localized context via Mapbox
        location_string = get_human_readable_location(user_lat, user_lng)

        # Retrieve Context (with threshold and filters applied)
        retrieved_context = get_retrieved_context(raw_hazard)

        # Generate structured recommendation via GPT-4o-mini
        final_recommendation = generate_ai_recommendation(
            hazard_display,
            event_description, 
            retrieved_context, 
            location_string
        )
        
        return jsonify({
            "status": "success",
            "hazard": hazard_display,
            "location_context": location_string,
            "retrieved_context": retrieved_context or "No matching playbook met the confidence threshold.",
            "recommendation": final_recommendation
        }), 200

    except ValidationError as err:
        # This catches instances where the LLM breaks the JSON schema constraints
        print(f"LLM Schema Validation Error: {err.messages}")
        return jsonify({
            'status': 'error', 
            'message': 'AI generated an invalid response format.', 
            'details': err.messages
        }), 500
        
    except Exception as e:
        # This catches general Python/API errors, timeouts, etc.
        print(f"AI Generation Error: {e}")
        return jsonify({'status': 'error', 'message': 'Internal Server Error processing RAG flow.'}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)