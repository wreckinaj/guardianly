================================================================================
GUARDIANLY BACKEND API - SETUP AND RUNNING INSTRUCTIONS
================================================================================

PREREQUISITES
-------------
- Python 3.7 or higher installed
- pip (Python package installer)
- Internet connection for package installation

SETUP INSTRUCTIONS
------------------

1. INSTALL REQUIRED PACKAGES
   Open PowerShell in the backend directory and run:
   
   pip install flask requests PyJWT

   Or if you have a requirements.txt:
   
   pip install -r requirements.txt


2. CONFIGURE ENVIRONMENT VARIABLES
   Set your Mapbox access token and secret key:
   
   $env:MAPBOX_ACCESS_TOKEN="pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A"
   $env:SECRET_KEY="your_secret_key_here"

   Or create a .env file (copy from .env.example):
   
   MAPBOX_ACCESS_TOKEN="your_mapbox_token_here"
   SECRET_KEY="your_secret_key_here"


RUNNING THE SERVER
------------------

1. Navigate to the backend directory:
   
   cd C:\Users\15172\Documents\Guardianly\guardianly\backend

2. Run the server:
   
   python server.py or python3 server.py

3. The server will start on http://localhost:5000
   You should see output like:
   * Running on http://127.0.0.1:5000
   * Debug mode: on


TESTING THE API
---------------

METHOD 1: BROWSER (GET requests only)
--------------------------------------
Open your browser and visit:

- Home page (list all endpoints):
  http://localhost:5000/

- Geocoding:
  http://localhost:5000/geocode?place=Portland OR

- Reverse Geocoding:
  http://localhost:5000/reverse?lng=-122.6765&lat=45.5231

- Directions:
  http://localhost:5000/directions?start=Portland,OR&end=Seattle,WA


METHOD 2: POWERSHELL / CURL (all endpoints)
------------------------------------

1. TEST REGISTRATION:
   Invoke-WebRequest -Uri http://localhost:5000/api/register -Method POST -ContentType "application/json" -Body '{"username":"newuser","password":"pass123","email":"user@test.com"}'

2. TEST LOGIN:
   $response = Invoke-WebRequest -Uri http://localhost:5000/api/login -Method POST -ContentType "application/json" -Body '{"username":"testuser","password":"testpass123"}'
   $token = ($response.Content | ConvertFrom-Json).token

   Default test users:
   - Username: testuser, Password: testpass123
   - Username: guardian, Password: guardian123

3. TEST PUSH NOTIFICATION (requires authentication):
(Option way) Invoke-WebRequest -Uri http://localhost:5000/api/push -Method POST -Headers @{Authorization="Bearer $token"} -ContentType "application/json" -Body '{"user_id":"123","title":"Alert","message":"Test notification"}'

   a) Send a push notification:
      
      curl -X POST http://127.0.0.1:5000/api/push \
           -H "Content-Type: application/json" \
           -H "Authorization: Bearer $token" \
           -d '{"user_id":"123","title":"Alert","message":"Test notification"}'
   
      Response example:
      {
        "message": "Notification stored successfully",
        "notification": {
          "message": "Test notification",
          "timestamp": "2025-11-08T01:37:25.905071",
          "title": "Alert",
          "user": "testuser"
        },
        "status": "success"
      }
   
      b) Get current notification settings for the user:
   
      curl -X GET http://127.0.0.1:5000/api/notifications/settings \
           -H "Authorization: Bearer $token"
   
      Response example:
      {
        "settings": {
          "enabled_types": []
        },
        "status": "success",
        "user": "testuser"
      }
   
      c) Update notification settings:
   
      curl -X PUT http://127.0.0.1:5000/api/notifications/settings \
           -H "Content-Type: application/json" \
           -H "Authorization: Bearer $token" \
           -d '{"enabled_types":["alerts","reminders"]}'
   
      Response example:
      {
        "message": "Notification settings updated",
        "settings": {
          "enabled_types": ["alerts","reminders"]
        },
        "status": "success",
        "user": "testuser"
      }


4. TEST MAPBOX ENDPOINTS:
   
   Geocoding:
   Invoke-WebRequest -Uri "http://localhost:5000/geocode?place=New York"
   
   Reverse Geocoding:
   Invoke-WebRequest -Uri "http://localhost:5000/reverse?lng=-74.006&lat=40.7128"
   
   Directions:
   Invoke-WebRequest -Uri "http://localhost:5000/directions?start=Boston,MA&end=New York,NY&profile=driving"


API ENDPOINTS
-------------

PUBLIC ENDPOINTS (no authentication required):
- GET  /                   - API home page with endpoint list
- GET  /geocode            - Convert place name to coordinates
- GET  /reverse            - Convert coordinates to place name
- GET  /directions         - Get directions between two points

AUTHENTICATION ENDPOINTS:
- POST /api/register       - Register new user
- POST /api/login          - Login and get JWT token

PROTECTED ENDPOINTS (requires JWT token):
- POST /api/push           - Send push notification
- GET  /api/notifications/settings - Get user's notification settings
- PUT  /api/notifications/settings - Update user's notification settings


TROUBLESHOOTING
---------------

1. "Module not found" error:
   Make sure you installed all packages:
   pip install flask requests PyJWT

2. "Token has expired" error:
   Login again to get a fresh token (tokens expire after 24 hours)

3. "Invalid token" error:
   Make sure you're using "Bearer " prefix in Authorization header

4. Mapbox API errors:
   Verify your MAPBOX_ACCESS_TOKEN is set correctly

5. Port already in use:
   Change the port in server.py or kill the process using port 5000


NOTES
-----
- This is a development server. Do NOT use in production.
- Passwords are stored in plain text (mock database). In production, use proper password hashing (bcrypt).
- The SECRET_KEY should be a strong random string in production.
- For production deployment, use a production WSGI server like Gunicorn or uWSGI.


CONTACT
-------
For questions or issues, contact the Guardianly development team.
================================================================================
