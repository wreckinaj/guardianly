from flask import jsonify, request, Flask
import requests
import os
import jwt
import datetime
from functools import wraps

app = Flask(__name__)

# Configuration
MAPBOX_ACCESS_TOKEN = os.environ.get('MAPBOX_ACCESS_TOKEN', 'your_mapbox_token_here')
SECRET_KEY = os.environ.get('SECRET_KEY', 'your_secret_key_here_change_in_production')

# Mock user database (replace with real database in production)
mock_users = {
    "testuser": {
        "password": "testpass123",
        "user_id": "123",
        "email": "test@guardianly.com"
    },
    "guardian": {
        "password": "guardian123",
        "user_id": "456",
        "email": "guardian@guardianly.com"
    }
}

mock_data = {
    "user_id": "123",
    "title": "Test Notification",
    "message": "This is a mock push notification."
}

mock_notification_settings = {
    "123": {"enabled_types": ["alerts", "reminders", "promotions"]},
    "456": {"enabled_types": ["alerts", "reminders"]}
}

# Token verification decorator
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
            
            data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            current_user = data['username']
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated


@app.route('/')
def home():
    return jsonify({
        'message': 'Guardianly Backend API',
        'endpoints': {
            'login': '/api/login (POST)',
            'register': '/api/register (POST)',
            'push_notification': '/api/push (POST, requires auth)',
            'get_notifications': '/api/notifications (GET, requires auth)',
            'get_notification_settings': '/api/notifications/settings (GET, requires auth)',
            'update_notification_settings': '/api/notifications/settings (PUT, requires auth)',
            'geocoding': '/geocode?place=Corvallis OR',
            'reverse_geocoding': '/reverse?lng=-123.262&lat=44.565',
            'directions': '/directions?start=Corvallis,OR&end=Albany,OR'
        }
    })


@app.route('/api/login', methods=['POST'])
def login():
    """User login endpoint"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password required'}), 400
    
    username = data.get('username')
    password = data.get('password')
    
    # Check if user exists and password matches
    if username in mock_users and mock_users[username]['password'] == password:
        # Generate JWT token
        token = jwt.encode({
            'username': username,
            'user_id': mock_users[username]['user_id'],
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, SECRET_KEY, algorithm="HS256")
        
        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'token': token,
            'user': {
                'username': username,
                'user_id': mock_users[username]['user_id'],
                'email': mock_users[username]['email']
            }
        }), 200
    
    return jsonify({'error': 'Invalid username or password'}), 401


@app.route('/api/register', methods=['POST'])
def register():
    """User registration endpoint"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password') or not data.get('email'):
        return jsonify({'error': 'Username, password, and email required'}), 400
    
    username = data.get('username')
    password = data.get('password')
    email = data.get('email')
    
    # Check if user already exists
    if username in mock_users:
        return jsonify({'error': 'Username already exists'}), 409
    
    # Create new user (in production, hash the password!)
    user_id = str(len(mock_users) + 1000)
    mock_users[username] = {
        'password': password,  # In production: use bcrypt or similar
        'user_id': user_id,
        'email': email
    }
    
    return jsonify({
        'status': 'success',
        'message': 'User registered successfully',
        'user': {
            'username': username,
            'user_id': user_id,
            'email': email
        }
    }), 201


# Store notifications in memory (mock database)
notifications = []

# Sends a notification
@app.route('/api/push', methods=['POST'])
@token_required
def push_endpoint(current_user):
    """Send push notification (requires authentication)"""
    data = request.get_json()
    if not data or not data.get("title") or not data.get("message"):
        return jsonify({"error": "Title and message are required"}), 400

    note = {
        "user": current_user,
        "title": data["title"],
        "message": data["message"],
        "timestamp": datetime.datetime.utcnow().isoformat()
    }
    notifications.append(note)
    print(f"[Notification] From {current_user}: {note}")

    return jsonify({
        "status": "success",
        "message": "Notification stored successfully",
        "notification": note
    }), 201

# Retrieve all notifications
@app.route('/api/notifications', methods=['GET'])
@token_required
def get_notifications(current_user):
    """Retrieve all notifications for the authenticated user"""
    user_notes = [n for n in notifications if n["user"] == current_user]
    return jsonify({
        "status": "success",
        "count": len(user_notes),
        "notifications": user_notes
    }), 200

# Get notification settings
@app.route('/api/notifications/settings', methods=['GET'])
@token_required
def get_notification_settings(current_user):
    settings = mock_notification_settings.get(current_user, {"enabled_types": []})
    return jsonify({
        "status": "success",
        "user": current_user,
        "settings": settings
    }), 200

# Update notification settings
@app.route('/api/notifications/settings', methods=['PUT'])
@token_required
def update_notification_settings(current_user):
    data = request.get_json()
    enabled_types = data.get("enabled_types", [])
    
    # Save or update settings
    mock_notification_settings[current_user] = {"enabled_types": enabled_types}
    
    return jsonify({
        "status": "success",
        "message": "Notification settings updated",
        "user": current_user,
        "settings": mock_notification_settings[current_user]
    }), 200


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
        # Handle exceptions from the requests library, such as:
        # - Connection errors (network issues)
        # - Timeouts (API not responding)
        # - HTTP errors (401 unauthorized, 404 not found, etc.)
        # - Invalid responses from the Mapbox geocoding API
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
        # Handle exceptions from the requests library, such as:
        # - Connection errors (network issues)
        # - Timeouts (API not responding)
        # - HTTP errors (401 unauthorized, 404 not found, etc.)
        # - Invalid responses from the Mapbox geocoding API
        return jsonify({'error': str(e)}), 500


def is_place_name(location):
    """Helper function to determine if a string is a place name or coordinates.
    Returns True if location is a place name (e.g., 'Portland,OR'),
    False if it's coordinates (e.g., '-122.6765,45.5231')
    """
    if ',' not in location:
        return True
    
    # Remove special characters used in coordinates
    cleaned = location.replace(',', '').replace('.', '').replace('-', '')
    # If all remaining characters are digits, it's likely coordinates
    return not cleaned.isdigit()


@app.route('/directions')
def directions():
    """Get directions between two points"""
    start = request.args.get('start', 'Corvallis,OR')
    end = request.args.get('end', 'Albany,OR')
    profile = request.args.get('profile', 'driving')  # driving, walking, cycling
    
    try:
        # Geocode start location if it's a place name (not coordinates)
        if is_place_name(start):
            geocode_url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{start}.json'
            geocode_params = {'access_token': MAPBOX_ACCESS_TOKEN, 'limit': 1}
            start_response = requests.get(geocode_url, params=geocode_params)
            start_response.raise_for_status()
            start_coords = start_response.json()['features'][0]['geometry']['coordinates']
            start_coords_str = f"{start_coords[0]},{start_coords[1]}"
        else:
            start_coords_str = start
        
        # Geocode end location if it's a place name (not coordinates)
        if is_place_name(end):
            geocode_url = f'https://api.mapbox.com/geocoding/v5/mapbox.places/{end}.json'
            geocode_params = {'access_token': MAPBOX_ACCESS_TOKEN, 'limit': 1}
            end_response = requests.get(geocode_url, params=geocode_params)
            end_response.raise_for_status()
            end_coords = end_response.json()['features'][0]['geometry']['coordinates']
            end_coords_str = f"{end_coords[0]},{end_coords[1]}"
        else:
            end_coords_str = end
        
        # Get directions
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
        # Handle exceptions from the requests library, such as:
        # - Connection errors (network issues)
        # - Timeouts (API not responding)
        # - HTTP errors (401 unauthorized, 404 not found, etc.)
        # - Invalid responses from the Mapbox directions API
        # - Invalid location parameters (geocoding failures)
        return jsonify({'error': str(e)}), 500
    
# Canonical hazard registry (internal keys → human labels)
HAZARDS = {
    "road_closure": "Road Closure",
    "severe_weather_rain": "Severe Weather (Heavy Rain)",
}

def get_retrieved_context(hazard_key, user_lat, user_lng):
    if hazard_key == "road_closure":
        playbook_text = (
            "Playbook: Check Mapbox for 'road-closure' impact. "
            "Suggest detour route. Find nearest police station."
        )
        geospatial_data = (
            f"Mapbox Context: Safer route found avoiding hazard "
            f"(start={user_lat},{user_lng}, end=Albany,OR)"
        )
        return f"{playbook_text} | {geospatial_data}"

    elif hazard_key == "severe_weather_rain":
        playbook_text = (
            "Playbook: Suggest rescheduling trip or safe parking spot. "
            "Find nearest covered shelter."
        )
        geospatial_data = (
            "Mapbox Context: No safe route detour possible. "
            "Nearest shelter is 0.5 miles away."
        )
        return f"{playbook_text} | {geospatial_data}"

    return "Default Context: Advise caution."

@app.route('/api/generate_prompt', methods=['POST'])
@token_required
def generate_prompt_endpoint(current_user):
    """Generates an LLM prompt for a safety alert using RAG context."""
    data = request.get_json()

    # Normalize hazard type
    raw_hazard = data.get('hazard', '')
    hazard_key = raw_hazard.strip().lower().replace(" ", "_")

    if hazard_key not in HAZARDS:
        return jsonify({
            "error": "Invalid hazard type",
            "allowed": list(HAZARDS.values())
        }), 400

    user_lat = data.get('user_lat')
    user_lng = data.get('user_lng')

    if user_lat is None or user_lng is None:
        return jsonify({"error": "user_lat and user_lng are required"}), 400

    try:
        user_lat = float(user_lat)
        user_lng = float(user_lng)
    except (TypeError, ValueError):
        return jsonify({"error": "user_lat and user_lng must be valid numbers"}), 400

    if not (-90 <= user_lat <= 90):
        return jsonify({"error": "user_lat must be between -90 and 90"}), 400

    if not (-180 <= user_lng <= 180):
        return jsonify({"error": "user_lng must be between -180 and 180"}), 400

    # --- RAG Retrieval ---
    retrieved_context = get_retrieved_context(hazard_key, user_lat, user_lng)

    # --- Prompt Generation ---
    hazard_display = HAZARDS[hazard_key]

    metaprompt = (
        "You are the Guardianly AI Agent. Your goal is to give safety-focused, actionable recommendations. "
        "Generate a 3-part response: 1. Primary Recommendation, 2. Action Steps, 3. Nearby Resource. "
        "Base your response ONLY on the provided Safety Context. Be concise."
    )

    user_query = (
        f"The user is at {user_lat}, {user_lng} and "
        f"received a '{hazard_display}' alert."
    )

    final_prompt = (
        f"METAPROMPT: {metaprompt}\n"
        f"SAFETY CONTEXT: {retrieved_context}\n"
        f"USER QUERY: {user_query}"
    )

    return jsonify({
        "status": "prototype_success",
        "hazard": hazard_display,
        "retrieved_context": retrieved_context,
        "final_prompt_to_llm": final_prompt
    }), 200

# Listener
if __name__ == "__main__":
    # Start the app to run on a port of your choosing
    app.run(port=5000, debug=True)
