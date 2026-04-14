import unittest
from unittest.mock import patch

from sqlalchemy.exc import OperationalError

from backend_fastapi.app import database


def _operational_error(message: str) -> OperationalError:
    return OperationalError('SELECT 1', {}, RuntimeError(message))


class _FakeDialect:
    class dbapi:
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
                raise RuntimeError('could not connect')
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
        dialect.dbapi.connect = lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError('syntax error at or near "FROM"'))
        with patch.object(database.settings, 'db_retry_attempts', 3):
            with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                with self.assertRaises(RuntimeError):
                    database._connect_with_retry(dialect, (), {})

    def test_merge_connect_options_preserves_existing_flags(self) -> None:
        merged = database._merge_connect_options('-c application_name=atalaya')
        self.assertIn('application_name=atalaya', merged)
        self.assertIn('statement_timeout=', merged)


if __name__ == '__main__':
    unittest.main()
