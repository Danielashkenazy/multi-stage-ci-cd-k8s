import json
from main import app


def test_healthcheck_status_code():
    client = app.test_client()
    response = client.get('/health')
    assert response.status_code == 200


def test_healthcheck_response_body():
    client = app.test_client()
    response = client.get('/health')
    data = json.loads(response.data.decode())
    assert data == {"status": "ok"}
