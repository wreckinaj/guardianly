from flask import jsonify, request, Flask
import requests
import os
import jwt
import datetime
from functools import wraps
from marshmallow import ValidationError
from schemas import GeneratePromptRequestSchema, AlertRecommendationSchema

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
    """User login endpoint - accepts username or email"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username/email and password required'}), 400
    
    username_or_email = data.get('username')
    password = data.get('password')
    
    # Find user by username or email
    found_user = None
    found_username = None
    
    # Check if it's a direct username match
    if username_or_email in mock_users:
        if mock_users[username_or_email]['password'] == password:
            found_user = mock_users[username_or_email]
            found_username = username_or_email
    else:
        # Check if it's an email match
        for uname, user_data in mock_users.items():
            if user_data['email'] == username_or_email and user_data['password'] == password:
                found_user = user_data
                found_username = uname
                break
    
    if found_user:
        # Generate JWT token
        token = jwt.encode({
            'username': found_username,
            'user_id': found_user['user_id'],
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, SECRET_KEY, algorithm="HS256")
        
        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'token': token,
            'user': {
                'username': found_username,
                'user_id': found_user['user_id'],
                'email': found_user['email']
            }
        }), 200
    
    return jsonify({'error': 'Invalid username/email or password'}), 401


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
    """
    Generates a structured safety recommendation using RAG context.
    
    1. Validates input using GeneratePromptRequestSchema.
    2. Retrieves contextual data (RAG).
    3. Mocks/Simulates a structured LLM response.
    4. Serializes the structured output using AlertRecommendationSchema.
    """
    # 1. Input Validation (Using Marshmallow Schema)
    try:
        # Use request.get_json() to load raw data, then validate with the schema
        data = GeneratePromptRequestSchema().load(request.get_json())
    except ValidationError as err:
        return jsonify({"error": "Invalid input data", "messages": err.messages}), 400

    # Extract validated data
    raw_hazard = data['hazard']
    user_lat = data['user_lat']
    user_lng = data['user_lng']

    # 2. Hazard and System Validation
    # HAZARDS dictionary is defined in the original server.py
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

    # 3. RAG Retrieval (Existing Logic)
    # The actual implementation of get_retrieved_context is already present in server.py
    retrieved_context = get_retrieved_context(hazard_key, user_lat, user_lng)

    # 4. Mock LLM Structured Response Generation
    # This block simulates the final output of the LLM based on the RAG context.
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

    # 5. Output Serialization (Using AlertRecommendationSchema)
    try:
        # Serialize the Python dictionary (mock_llm_response) into a clean JSON output
        # This step also validates that the mock data adheres to the AlertRecommendationSchema
        final_recommendation = AlertRecommendationSchema().dump(mock_llm_response)
        
        return jsonify({
            "status": "success",
            "hazard": hazard_display,
            "retrieved_context": retrieved_context,
            "recommendation": final_recommendation
        }), 200

    except ValidationError as err:
        # This catches errors if the mock_llm_response does not match the schema
        return jsonify({"error": "Failed to serialize recommendation (Internal Error)", "messages": err.messages}), 500

# Listener
if __name__ == "__main__":
    # Start the app to run on a port of your choosing
    app.run(port=5000, debug=True)
