import requests

# This script tests the USGS Earthquake synchronization endpoint.
# Make sure your server.py is running (python server.py) before executing this.

URL = "http://127.0.0.1:5000/api/sync/usgs"

try:
    print(f"Triggering USGS Sync at {URL}...")
    response = requests.post(URL)

    if response.status_code == 200:
        data = response.json()
        print("\n✅ Sync Successful!")
        print(f"Message: {data.get('message')}")
        print(f"Total checked in feed: {data.get('total_checked')}")
        print(f"New alerts added to Firestore: {data.get('synced_count', 'N/A')}")
    else:
        print(f"\n❌ Sync Failed with status code: {response.status_code}")
        print(f"Error: {response.text}")

except requests.exceptions.ConnectionError:
    print("\n❌ Error: Could not connect to the server.")
    print("Make sure server.py is running locally on port 5000.")
except Exception as e:
    print(f"\n❌ An unexpected error occurred: {e}")
