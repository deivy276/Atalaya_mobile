import unittest
from unittest.mock import patch

from sqlalchemy.exc import OperationalError

from backend_fastapi.app import database


def _operational_error(message: str) -> OperationalError:
    return OperationalError('SELECT 1', {}, RuntimeError(message))


class _FakeDialect:
    class dbapi:
        class OperationalError(Exception):
            pass

        connect = None


class DatabaseRetryTests(unittest.TestCase):
    def test_transient_operational_error_detection(self) -> None:
        transient = _operational_error('failed to resolve host')
        non_transient = _operational_error('relation "missing_table" does not exist')

        self.assertTrue(database._is_transient_operational_error(transient))
        self.assertFalse(database._is_transient_operational_error(non_transient))

    def test_connect_with_retry_retries_transient_failures(self) -> None:
        calls = {'count': 0}

        def _fake_connect(*args, **kwargs):
            calls['count'] += 1
            if calls['count'] == 1:
                raise _FakeDialect.dbapi.OperationalError('could not connect')
            return object()

        dialect = _FakeDialect()
        dialect.dbapi.connect = _fake_connect
        with patch.object(database.settings, 'db_retry_attempts', 2):
            with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                with patch('backend_fastapi.app.database.sleep', return_value=None):
                    conn = database._connect_with_retry(dialect, (), {})
        self.assertIsNotNone(conn)
        self.assertEqual(calls['count'], 2)

    def test_connect_with_retry_does_not_retry_non_transient(self) -> None:
        dialect = _FakeDialect()
        dialect.dbapi.connect = lambda *args, **kwargs: (_ for _ in ()).throw(
            _FakeDialect.dbapi.OperationalError('syntax error at or near "FROM"')
        )
        with patch.object(database.settings, 'db_retry_attempts', 3):
            with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                with self.assertRaises(_FakeDialect.dbapi.OperationalError):
                    database._connect_with_retry(dialect, (), {})

    def test_merge_connect_options_preserves_existing_flags(self) -> None:
        merged = database._merge_connect_options('-c application_name=atalaya')
        self.assertIn('application_name=atalaya', merged)
        self.assertIn('statement_timeout=', merged)
        self.assertIn('idle_in_transaction_session_timeout=', merged)

    def test_merge_connect_options_is_idempotent_for_timeout_flags(self) -> None:
        existing = (
            '-c statement_timeout=7777 '
            '-c idle_in_transaction_session_timeout=22222 '
            '-c application_name=atalaya'
        )
        merged = database._merge_connect_options(existing)
        self.assertEqual(merged.count('statement_timeout='), 1)
        self.assertEqual(merged.count('idle_in_transaction_session_timeout='), 1)

    def test_connect_with_retry_does_not_swallow_non_operational_exception(self) -> None:
        dialect = _FakeDialect()
        dialect.dbapi.connect = lambda *args, **kwargs: (_ for _ in ()).throw(ValueError('bad params'))
        with self.assertRaises(ValueError):
            database._connect_with_retry(dialect, (), {})


if __name__ == '__main__':
    unittest.main()
