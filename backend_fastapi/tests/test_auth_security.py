import os
import unittest
from unittest.mock import MagicMock

from fastapi import HTTPException

from backend_fastapi.app import auth
from backend_fastapi.app.auth import _totp_now, _verify_totp, validate_auth_runtime_security


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

    def test_rbac_and_phase3_schema_seed_is_executed(self) -> None:
        db = MagicMock()
        auth.init_auth_db(db)
        self.assertTrue(db.execute.called)
        self.assertTrue(db.commit.called)
        execute_calls = str(db.execute.call_args_list)
        self.assertIn('predictor:write', execute_calls)
        self.assertIn('operations:execute', execute_calls)

    def test_totp_generation_and_verification(self) -> None:
        secret = auth._base32_secret()
        otp = _totp_now(secret)
        self.assertTrue(_verify_totp(secret, otp))


if __name__ == '__main__':
    unittest.main()
