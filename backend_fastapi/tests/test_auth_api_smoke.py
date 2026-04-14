import os
import unittest
from unittest.mock import MagicMock, patch

try:
    from fastapi.testclient import TestClient
except RuntimeError:
    TestClient = None

os.environ['AUTH_SKIP_DB_INIT'] = 'true'
os.environ['AUTH_ENABLED'] = 'false'

from backend_fastapi.app.database import get_db  # noqa: E402
from backend_fastapi.app.main import app, settings  # noqa: E402


def _fake_db():
    yield MagicMock()


@unittest.skipIf(TestClient is None, 'fastapi.testclient requires httpx dependency')
class AuthApiSmokeTests(unittest.TestCase):
    def setUp(self) -> None:
        app.dependency_overrides[get_db] = _fake_db

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_security_headers_are_present(self) -> None:
        with TestClient(app) as client:
            response = client.get('/health')
        self.assertEqual(response.status_code, 200)
        self.assertIn('Strict-Transport-Security', response.headers)
        self.assertIn('X-Content-Type-Options', response.headers)
        self.assertIn('X-Frame-Options', response.headers)

    def test_login_rate_limit_returns_429(self) -> None:
        settings.rate_limit_auth_max_requests = 2
        settings.rate_limit_auth_window_seconds = 60
        with patch('backend_fastapi.app.main.authenticate_user', return_value=None):
            with TestClient(app) as client:
                first = client.post('/auth/login', json={'username': 'u', 'password': 'p'})
                second = client.post('/auth/login', json={'username': 'u', 'password': 'p'})
                third = client.post('/auth/login', json={'username': 'u', 'password': 'p'})

        self.assertEqual(first.status_code, 401)
        self.assertEqual(second.status_code, 401)
        self.assertEqual(third.status_code, 429)

    def test_payload_limit_returns_413(self) -> None:
        settings.max_request_size_bytes = 10
        with TestClient(app) as client:
            response = client.post('/auth/login', content='x' * 200)
        self.assertEqual(response.status_code, 413)


if __name__ == '__main__':
    unittest.main()
