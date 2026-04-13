import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

from backend_fastapi.app import auth
from backend_fastapi.app.auth import AuthUser, UserCreateRequest, validate_auth_runtime_security


def _set_env(temp_db: Path) -> None:
    os.environ['AUTH_SQLITE_PATH'] = str(temp_db)
    os.environ['AUTH_ENABLED'] = 'true'
    os.environ['APP_ENV'] = 'dev'
    os.environ['AUTH_SECRET_KEY'] = 'DevStrongSecret#12345'
    os.environ['AUTH_COOKIE_SECURE'] = 'false'
    os.environ['AUTH_PASSWORD_MIN_LENGTH'] = '12'
    os.environ['AUTH_LOGIN_MAX_ATTEMPTS'] = '5'
    os.environ['AUTH_LOGIN_LOCKOUT_MINUTES'] = '15'
    os.environ['BOOTSTRAP_ADMIN_USERNAME'] = 'admin'
    os.environ['BOOTSTRAP_ADMIN_PASSWORD'] = 'Str0ng!AdminPass'


class AuthSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / 'auth_test.db'
        _set_env(self.db_path)
        auth.get_settings.cache_clear()
        auth.init_auth_db()

    def tearDown(self) -> None:
        auth.get_settings.cache_clear()
        self.temp_dir.cleanup()

    def test_password_policy_rejects_weak_and_accepts_strong(self) -> None:
        with self.assertRaises(Exception):
            auth.validate_password_policy('password')
        auth.validate_password_policy('C0mpl3x!Passw0rd')

    def test_lockout_after_failed_attempts(self) -> None:
        for _ in range(5):
            self.assertIsNone(auth.authenticate_user('admin', 'wrong-pass'))
        self.assertIsNone(auth.authenticate_user('admin', 'Str0ng!AdminPass'))

    def test_admin_user_management_and_audit_events(self) -> None:
        actor = AuthUser(username='admin', role='admin')
        created = auth.create_user(actor, UserCreateRequest(username='operator1', password='An0ther!StrongPwd', role='operator'))
        self.assertEqual(created.username, 'operator1')

        updated_role = auth.set_user_role(actor, 'operator1', 'admin')
        self.assertEqual(updated_role.role, 'admin')

        updated_activation = auth.set_user_activation(actor, 'operator1', False)
        self.assertFalse(updated_activation.is_active)

        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute('SELECT event_type FROM auth_audit_log ORDER BY id ASC').fetchall()
        events = [row[0] for row in rows]
        self.assertIn('user_created', events)
        self.assertIn('user_role_changed', events)
        self.assertIn('user_deactivated', events)

    def test_runtime_security_validation_in_prod_requires_secure_cookie(self) -> None:
        os.environ['APP_ENV'] = 'prod'
        os.environ['AUTH_COOKIE_SECURE'] = 'false'
        os.environ['AUTH_SECRET_KEY_PROD'] = 'ProdVeryStrongSecret#123'
        auth.get_settings.cache_clear()

        with self.assertRaises(RuntimeError):
            validate_auth_runtime_security()


if __name__ == '__main__':
    unittest.main()
