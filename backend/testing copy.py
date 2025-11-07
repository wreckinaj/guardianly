import requests
from notifications import mock_data  # import mock data

# Make sure your Flask app is running at this URL
url = "http://127.0.0.1:5000/api/push"

response = requests.post(url, json=mock_data)
print("Response from endpoint:", response.json())
