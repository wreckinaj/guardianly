from flask import jsonify, request, Flask
from flask_cors import CORS
from flask_caching import Cache
import requests
import os
import datetime
import json
import csv
import io
from functools import wraps
from marshmallow import ValidationError
import firebase_admin
from firebase_admin import credentials, auth, messaging, firestore
from schemas import GeneratePromptRequestSchema, AlertRecommendationSchema
from pinecone import Pinecone
from openai import OpenAI
from dotenv import load_dotenv

# Load .env file
load_dotenv()

app = Flask(__name__)

# --- Debug: Print found keys (Masked for safety) ---
firms_key = os.environ.get('NASA_FIRMS_KEY')
if firms_key:
    print(f"✅ NASA_FIRMS_KEY found: {firms_key[:4]}...{firms_key[-4:]}")
else:
    print("❌ NASA_FIRMS_KEY NOT FOUND in environment.")

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
            'sync_nws': '/api/sync/nws (POST)',
            'sync_gdacs': '/api/sync/gdacs (POST)',
            'sync_eonet': '/api/sync/eonet (POST)',
            'sync_firms': '/api/sync/firms (POST)',
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

# --- External API Sync Endpoints ---

@app.route('/api/sync/usgs', methods=['POST'])
def sync_usgs():
    """FETCH: Pull real-time earthquake data from USGS and save as alerts"""
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

            if props['mag'] < 1.0:
                continue

            doc_id = f"usgs_{eq_id}"
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                alert_ref.set({
                    'title': f"Earthquake: M{props['mag']}",
                    'message': f"Significant activity recorded at {props['place']}.",
                    'hazardType': 'earthquake',
                    'lat': geom['coordinates'][1],
                    'lng': geom['coordinates'][0],
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'external_id': eq_id,
                    'source': 'USGS',
                    'url': props['url']
                })
                new_count += 1

        return jsonify({'status': 'success', 'message': f'USGS sync complete. Added {new_count} new alerts.'}), 200

    except Exception as e:
        print(f"USGS Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sync/nws', methods=['POST'])
def sync_nws():
    """FETCH: Pull active weather alerts from National Weather Service (US Only)"""
    url = "https://api.weather.gov/alerts/active?status=actual&message_type=alert"
    headers = {"User-Agent": "(guardianly.app, contact@guardianly.app)"}

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()

        new_count = 0
        for feature in data.get('features', []):
            props = feature['properties']
            alert_id = props['id']

            severity = props.get('severity', 'Unknown')
            if severity not in ['Extreme', 'Severe']:
                continue

            doc_id = f"nws_{alert_id}"
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                geom = feature.get('geometry')
                lat, lng = 0.0, 0.0

                if geom:
                    if geom['type'] == 'Point':
                        lng, lat = geom['coordinates']
                    elif geom['type'] in ['Polygon', 'MultiPolygon']:
                        coords = geom['coordinates'][0]
                        while isinstance(coords[0], list):
                            coords = coords[0]
                        lng, lat = coords

                alert_ref.set({
                    'title': props.get('event', 'Weather Alert'),
                    'message': props.get('headline', 'Severe weather warning issued.'),
                    'hazardType': 'severe_weather',
                    'lat': lat,
                    'lng': lng,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'external_id': alert_id,
                    'source': 'NWS',
                    'severity': severity
                })
                new_count += 1

        return jsonify({'status': 'success', 'message': f'NWS sync complete. Added {new_count} severe weather alerts.'}), 200

    except Exception as e:
        print(f"NWS Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sync/eonet', methods=['POST'])
def sync_eonet():
    """FETCH: Pull natural events from NASA EONET v3 (Limited to last 7 days)"""
    # Added ?days=7 to reduce the amount of data processed
    url = "https://eonet.gsfc.nasa.gov/api/v3/events?days=7&status=open"

    try:
        print(f"Connecting to NASA EONET...")
        response = requests.get(url, timeout=25)
        response.raise_for_status()
        data = response.json()

        category_mapping = {
            'wildfires': 'wildfire',
            'volcanoes': 'volcanic_eruption',
            'severeStorms': 'severe_weather',
            'floods': 'flood',
            'tempExtremes': 'extreme_heat'
        }

        new_count = 0
        events = data.get('events', [])
        print(f"Processing {len(events)} NASA EONET events...")

        for event in events:
            event_id = event['id']
            title = event['title']
            categories = event.get('categories', [])
            if not categories: continue

            eonet_cat = categories[0]['id']
            internal_type = category_mapping.get(eonet_cat)
            if not internal_type: continue

            doc_id = f"eonet_{event_id}"
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                geoms = event.get('geometries', [])
                if not geoms: continue
                lng, lat = geoms[0]['coordinates']

                alert_ref.set({
                    'title': title,
                    'message': f"Global event reported: {title}",
                    'hazardType': internal_type,
                    'lat': lat,
                    'lng': lng,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'external_id': event_id,
                    'source': 'NASA EONET'
                })
                new_count += 1

        return jsonify({'status': 'success', 'message': f'NASA EONET synced {new_count} events.'}), 200
    except Exception as e:
        print(f"NASA EONET Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sync/gdacs', methods=['POST'])
def sync_gdacs():
    """FETCH: Pull global disaster alerts from GDACS robustly"""
    url = "https://www.gdacs.org/xml/gdacs.geojson"

    try:
        print(f"Connecting to GDACS...")
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        data = json.loads(response.content)

        type_mapping = {
            'TC': 'hurricane',
            'EQ': 'earthquake',
            'FL': 'flood',
            'VO': 'volcanic_eruption',
            'WF': 'wildfire',
            'DR': 'extreme_heat'
        }

        new_count = 0
        features = data.get('features', [] )
        print(f"Processing {len(features)} GDACS features...")

        for feature in features:
            props = feature['properties']
            event_id = props.get('eventid')
            event_type = props.get('eventtype')

            alert_level = props.get('alertlevel', 'Green')
            if alert_level not in ['Orange', 'Red']:
                continue

            internal_type = type_mapping.get(event_type, 'general')
            doc_id = f"gdacs_{event_type}_{event_id}"
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                geom = feature.get('geometry')
                if geom and geom['type'] == 'Point':
                    lng, lat = geom['coordinates']

                    alert_ref.set({
                        'title': f"{alert_level} Alert: {props.get('eventname', 'Global Disaster')}",
                        'message': props.get('description', 'High-impact disaster event reported.'),
                        'hazardType': internal_type,
                        'lat': lat,
                        'lng': lng,
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'external_id': str(event_id),
                        'source': 'GDACS',
                        'alertlevel': alert_level
                    })
                    new_count += 1

        return jsonify({'status': 'success', 'message': f'GDACS sync complete. Added {new_count} alerts.'}), 200
    except Exception as e:
        print(f"GDACS Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sync/firms', methods=['POST'])
def sync_firms():
    """FETCH: Pull fire hotspot data from NASA FIRMS (Global)"""
    map_key = os.environ.get('NASA_FIRMS_KEY')
    if not map_key:
        return jsonify({'status': 'error', 'message': 'NASA_FIRMS_KEY missing from .env'}), 400

    url = f"https://firms.modaps.eosdis.nasa.gov/api/area/csv/{map_key}/VIIRS_SNPP_NRT/-125,32,-114,49/1"

    try:
        print(f"Connecting to NASA FIRMS...")
        response = requests.get(url, timeout=15)
        if response.status_code != 200:
            return jsonify({'status': 'error', 'message': 'Failed to fetch NASA FIRMS data.'}), response.status_code

        new_count = 0
        f = io.StringIO(response.text)
        reader = csv.DictReader(f)
        for row in reader:
            lat = float(row['latitude'])
            lng = float(row['longitude'])
            acq_date = row['acq_date']
            confidence = row.get('confidence', 'n/a')

            doc_id = f"firms_{lat}_{lng}_{acq_date}".replace('.', '_')
            alert_ref = db.collection('alerts').document(doc_id)

            if not alert_ref.get().exists:
                alert_ref.set({
                    'title': "Active Fire Hotspot",
                    'message': f"Satellite detected thermal anomaly with {confidence} confidence.",
                    'hazardType': 'wildfire',
                    'lat': lat,
                    'lng': lng,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'source': 'NASA FIRMS',
                    'acq_date': acq_date
                })
                new_count += 1

        return jsonify({'status': 'success', 'message': f'NASA FIRMS synced {new_count} hotspots.'}), 200
    except Exception as e:
        print(f"NASA FIRMS Sync Error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

# --- Mapbox Endpoints & AI Logic ---

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
