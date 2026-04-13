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
            'update_alert': '/api/alerts/<id> (PUT)',
            'delete_alert': '/api/alerts/<id> (DELETE)',
            'sync_usgs': '/api/sync/usgs (POST)',
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

# --- Alert & Notification Endpoints (CRUD) ---

@app.route('/api/alerts', methods=['POST'])
def create_alert():
    """CREATE: Save a new manual alert to Firestore"""
    try:
        data = request.get_json()
        new_alert_ref = db.collection('alerts').document()
        
        alert_payload = {
            'title': data.get('title', 'System Alert'),
            'message': data.get('message', ''),
            'hazardType': data.get('hazardType', 'general'),
            'lat': data.get('lat', 0.0),
            'lng': data.get('lng', 0.0),
            'timestamp': firestore.SERVER_TIMESTAMP,
            'source': 'User'
        }
        
        new_alert_ref.set(alert_payload)
        return jsonify({'status': 'success', 'message': 'Alert created!', 'id': new_alert_ref.id}), 201

    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@check_token
def get_notifications():
    """READ: Retrieve all alerts sorted by newest"""
    try:
        alerts_ref = db.collection('alerts')
        docs = alerts_ref.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(50).stream()
        
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

# --- External API Sync: USGS Earthquakes ---

@app.route('/api/sync/usgs', methods=['POST'])
def sync_usgs():
    """FETCH: Pull real-time earthquake data from USGS and save as alerts"""
    # Summary of all M1.0+ earthquakes in the last hour
    url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()

        new_count = 0
        for feature in data.get('features', []):
            eq_id = feature['id']
            props = feature['properties']
            geom = feature['geometry']

            # Filter: only significant earthquakes
            if props['mag'] < 1.0:
                continue

            # Use unique ID to prevent duplicates
            doc_id = f"usgs_{eq_id}"
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                alert_ref.set({
                    'title': f"Earthquake: M{props['mag']}",
                    'message': f"Significant activity recorded at {props['place']}.",
                    'hazardType': 'earthquake',
                    'lat': geom['coordinates'][1], # GeoJSON uses [lng, lat]
                    'lng': geom['coordinates'][0],
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'external_id': eq_id,
                    'source': 'USGS',
                    'url': props['url']
                })
                new_count += 1

        return jsonify({
            'status': 'success',
            'message': f'USGS sync complete. Added {new_count} new alerts.',
            'total_checked': len(data.get('features', []))
        }), 200

    except Exception as e:
        print(f"USGS Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

# --- Mapbox Endpoints & AI Logic (Existing) ---
# ... (rest of the file remains unchanged)
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
        notification=messaging.Notification(title=data["title"], body=data["message"]),
        data={"lat": str(lat), "lng": str(lng), "icon": icon, "color": color},
        token=registration_token,
    )
    try:
        response = messaging.send(message)
        db.collection('alerts').add({
            "user": request.uid, "title": data["title"], "message": data["message"],
            "hazardType": data.get('hazardType', 'general'), "lat": lat, "lng": lng,
            "timestamp": firestore.SERVER_TIMESTAMP, "message_id": response
        })
        return jsonify({"status": "success", "message_id": response}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

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
    url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json'
    params = {'access_token': MAPBOX_ACCESS_TOKEN}
    try:
        response = requests.get(url, params=params, timeout=3)
        if response.status_code == 200:
            features = response.json().get('features', [])
            if features:
                return features[0].get('place_name', f"coordinates {lat}, {lng}")
    except Exception:
        pass
    return f"coordinates {lat}, {lng}"

SUPPORTED_HAZARDS = {
    "flood", "building_fire", "wildfire", "hurricane", 
    "tornado", "active_shooter", "police_activity", 
    "road_closure", "severe_weather", "earthquake", 
    "hazmat_spill", "gas_leak", "volcanic_eruption", "tsunami",
    "power_outage", "icy_roads", "heavy_traffic", 
    "construction_zone", "low_visibility", "wildlife",
    "civil_unrest", "transit_disruption", "extreme_heat", "air_quality",
    "blizzard", "flooded_pathway",
    "suspicious_package", "sinkhole", "downed_power_lines"
}

@cache.memoize(timeout=86400) 
def get_retrieved_context(hazard_key):
    query_text = f"Standard operating procedures and protocols for a {hazard_key} emergency."
    try:
        response = openai_client.embeddings.create(input=query_text, model="text-embedding-3-small")
        query_vector = response.data[0].embedding
        search_results = index.query(vector=query_vector, top_k=1, include_metadata=True, filter={"hazard": {"$eq": hazard_key}})
        matches = search_results.matches
        if not matches: return None
        top_match = matches[0]
        if top_match.score < 0.40: return None
        return top_match.metadata.get('text', '')
    except Exception as e:
        print(f"RAG Retrieval Critical Error: {type(e).__name__} - {str(e)}")
        return None

@cache.memoize(timeout=3600) 
def generate_ai_recommendation(hazard_display, event_description, retrieved_context, location_string):
    system_prompt = """
    You are Guardianly, an advanced safety AI. Your goal is to analyze a specific hazard event and provided safety context to generate a structured alert.
    You must output a VALID JSON object with: "severity", "message", "actions", "source".
    """
    user_message = f"Hazard: {hazard_display}\nDetails: {event_description}\nLocation: {location_string}\nContext: {retrieved_context if retrieved_context else 'None.'}"
    completion = openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
        response_format={"type": "json_object"},
        temperature=0.0
    )
    return AlertRecommendationSchema().load(json.loads(completion.choices[0].message.content))

@app.route('/api/generate_prompt', methods=['POST'])
@check_token
def generate_prompt_endpoint():
    try:
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400
    raw_hazard = data['hazard'].lower()
    hazard_display = raw_hazard.replace("_", " ").title()
    if raw_hazard not in SUPPORTED_HAZARDS:
        return jsonify({"status": "warning", "hazard": hazard_display, "recommendation": {"severity": "Unknown", "message": f"Caution: {hazard_display} reported.", "actions": ["Stay alert"], "source": "Fallback"}}), 200
    try:
        location_string = get_human_readable_location(data['user_lat'], data['user_lng'])
        retrieved_context = get_retrieved_context(raw_hazard)
        final_recommendation = generate_ai_recommendation(hazard_display, data.get('event_description', ''), retrieved_context, location_string)
        return jsonify({"status": "success", "hazard": hazard_display, "recommendation": final_recommendation}), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)
