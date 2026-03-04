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
from firebase_admin import credentials, auth, messaging, firestore # <-- Added firestore
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
    db = firestore.client() # <-- Initialize Firestore
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
            request.uid = decoded_token['uid'] # Attach the secure UID to the request
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
            return jsonify({
                'status': 'success',
                'profile': user_doc.to_dict()
            }), 200
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
        
        return jsonify({
            'status': 'success', 
            'message': 'Alert saved to Firestore!',
            'id': new_alert_ref.id
        }), 201
        
    except Exception as e:
        print(f"Error saving alert: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@check_token
def get_notifications():
    try:
        user_uid = request.uid
        print(f"Securely fetching alerts for user: {user_uid}")
        
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
    """Send a real Push Notification via Firebase Cloud Messaging"""
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
        print(f"[Notification] Sent to {request.uid}: {response}")
        
        # Also save this push notification to Firestore
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

        return jsonify({
            "status": "success", 
            "message_id": response
        }), 201

    except Exception as e:
        print(f"[Notification Error] {str(e)}")
        return jsonify({"error": str(e)}), 500

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

@cache.memoize(timeout=86400) 
def get_retrieved_context(hazard_key, user_lat_rounded, user_lng_rounded):
    query_text = f"Procedures for {hazard_key} hazard near {user_lat_rounded}, {user_lng_rounded}"
    
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

@cache.memoize(timeout=3600) 
def generate_ai_recommendation(hazard_display, retrieved_context, lat_rounded, lng_rounded):
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

    user_message = f"""
    Hazard Type: {hazard_display}
    User Location: {lat_rounded}, {lng_rounded}

    Context from Playbooks:
    {retrieved_context}

    Generate the safety recommendation now.
    """
    
    completion = openai_client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        response_format={"type": "json_object"},
        temperature=0.3
    )

    llm_response_text = completion.choices[0].message.content
    generated_data = json.loads(llm_response_text)
    return AlertRecommendationSchema().load(generated_data)

@app.route('/api/generate_prompt', methods=['POST'])
@check_token
def generate_prompt_endpoint():
    try:
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400

    raw_hazard = data['hazard']
    user_lat = data['user_lat']
    user_lng = data['user_lng']
    
    lat_rounded = round(float(user_lat), 2)
    lng_rounded = round(float(user_lng), 2)
    
    hazard_display = raw_hazard.replace("_", " ").title()
    
    try:
        retrieved_context = get_retrieved_context(raw_hazard, lat_rounded, lng_rounded)

        final_recommendation = generate_ai_recommendation(
            hazard_display, 
            retrieved_context, 
            lat_rounded, 
            lng_rounded
        )
        
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