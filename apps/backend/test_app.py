import pytest
from app import app, MESSAGES


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test the health check endpoint."""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'


def test_message_endpoint_returns_200(client):
    """Test that the message endpoint returns a 200 status code."""
    response = client.get('/api/message')
    assert response.status_code == 200


def test_message_endpoint_returns_json(client):
    """Test that the message endpoint returns JSON with a message field."""
    response = client.get('/api/message')
    data = response.get_json()
    assert 'message' in data
    assert isinstance(data['message'], str)


def test_message_endpoint_returns_valid_message(client):
    """Test that the message endpoint returns one of the expected messages."""
    response = client.get('/api/message')
    data = response.get_json()
    assert data['message'] in MESSAGES


def test_message_endpoint_randomness(client):
    """Test that multiple calls can return different messages (probabilistic)."""
    messages = set()
    # Make multiple requests to check for variability
    for _ in range(50):
        response = client.get('/api/message')
        data = response.get_json()
        messages.add(data['message'])

    # With 50 requests and 5 possible messages, we should get at least 2 different ones
    # This test has a very low probability of false failure
    assert len(messages) >= 2
