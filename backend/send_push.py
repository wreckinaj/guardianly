import firebase_admin
from firebase_admin import credentials, messaging

# 1. Initialize the Firebase Admin SDK
# Ensure this script is in the same folder as your admin_key.json
cred = credentials.Certificate("admin_key.json")
firebase_admin.initialize_app(cred)

# 2. Paste the token you copied from your Flutter debug console (make sure to replace you run!)
DEVICE_TOKEN = "PASTE_YOUR_FCM_TOKEN_HERE"

def send_test_notification():
    # 3. Construct the push notification
    message = messaging.Message(
        notification=messaging.Notification(
            title="Guardianly Test Alert! 🚨",
            body="If you are reading this, your push notifications are working perfectly.",
        ),
        data={
            "hazardType": "wildfire",
            "lat": "44.567",
            "lng": "-123.278"
        },
        token=DEVICE_TOKEN,
    )

    try:
        # 4. Send the message
        response = messaging.send(message)
        print(f"✅ Successfully sent message! Firebase Message ID: {response}")
    except Exception as e:
        print(f"❌ Error sending message: {e}")

if __name__ == "__main__":
    print("Attempting to send test notification...")
    send_test_notification()