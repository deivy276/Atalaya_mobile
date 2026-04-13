import os
import unittest
from unittest.mock import MagicMock

from fastapi import HTTPException

from backend_fastapi.app import auth
from backend_fastapi.app.auth import validate_auth_runtime_security


class AuthSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        os.environ['APP_ENV'] = 'dev'
        os.environ['AUTH_SECRET_KEY'] = 'DevStrongSecret#12345'
        os.environ['AUTH_COOKIE_SECURE'] = 'false'
        os.environ['AUTH_PASSWORD_MIN_LENGTH'] = '12'
        os.environ['AUTH_BANNED_PASSWORDS'] = 'password,admin,123456'
        auth.get_settings.cache_clear()

    def tearDown(self) -> None:
        auth.get_settings.cache_clear()

    def test_password_policy_rejects_weak_and_accepts_strong(self) -> None:
        with self.assertRaises(HTTPException):
            auth.validate_password_policy('password')
        with self.assertRaises(HTTPException):
            auth.validate_password_policy('weakpass1234')
        auth.validate_password_policy('C0mpl3x!Passw0rd')

    def test_runtime_security_validation_in_prod_requires_secure_cookie(self) -> None:
        os.environ['APP_ENV'] = 'prod'
        os.environ['AUTH_COOKIE_SECURE'] = 'false'
        os.environ['AUTH_SECRET_KEY_PROD'] = 'ProdVeryStrongSecret#123'
        auth.get_settings.cache_clear()
        with self.assertRaises(RuntimeError):
            validate_auth_runtime_security()

    def test_rbac_seed_is_executed(self) -> None:
        db = MagicMock()
        auth.init_auth_db(db)
        self.assertTrue(db.execute.called)
        self.assertTrue(db.commit.called)


if __name__ == '__main__':
    unittest.main()
