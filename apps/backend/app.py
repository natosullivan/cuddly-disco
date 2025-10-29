import random
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

MESSAGES = [
    "Your pipeline is green",
    "Your tests are well-written and stable",
    "Your friends and family understand what you do",
    "Your friends and family appreciate your humerous work stories",
    "That joke you told in your meeting was funny. If your coworkers weren't on mute, you would have heard them laughing"
]


@app.route('/api/message', methods=['GET'])
def get_message():
    """Return a random encouraging message."""
    message = random.choice(MESSAGES)
    return jsonify({'message': message})


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
