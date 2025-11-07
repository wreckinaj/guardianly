from flask import jsonify, request, Flask

notifications = Flask(__name__)

mock_data = {
    "user_id": "123",
    "title": "Test Notification",
    "message": "This is a mock push notification."
}


@notifications.route('/api/push', methods=['POST'])
def push_endpoint():
    data = request.get_json()
    print(data)
    return jsonify({"status": "success", "message": "Notification pushed"}), 200


# Listener
if __name__ == "__main__":

    # Start the app to run on a port of your choosing
    notifications.run(port=5000, debug=True)
