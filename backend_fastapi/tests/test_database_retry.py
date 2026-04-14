import unittest
from unittest.mock import patch

from sqlalchemy.exc import OperationalError

from backend_fastapi.app import database


class _FakeSession:
    def __init__(self, failures: list[Exception] | None = None) -> None:
        self._failures = failures or []
        self.closed = False

    def connection(self):
        if self._failures:
            raise self._failures.pop(0)
        return object()

    def close(self) -> None:
        self.closed = True


def _operational_error(message: str) -> OperationalError:
    return OperationalError('SELECT 1', {}, RuntimeError(message))


class DatabaseRetryTests(unittest.TestCase):
    def test_transient_operational_error_detection(self) -> None:
        transient = _operational_error('failed to resolve host')
        non_transient = _operational_error('relation "missing_table" does not exist')

        self.assertTrue(database._is_transient_operational_error(transient))
        self.assertFalse(database._is_transient_operational_error(non_transient))

    def test_get_db_retries_transient_failures(self) -> None:
        sessions = [
            _FakeSession([_operational_error('could not connect')]),
            _FakeSession(),
        ]

        def _factory():
            return sessions.pop(0)

        with patch('backend_fastapi.app.database._ensure_session_factory', return_value=_factory):
            with patch.object(database.settings, 'db_retry_attempts', 2):
                with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                    with patch('backend_fastapi.app.database.sleep', return_value=None):
                        generator = database.get_db()
                        db = next(generator)
                        self.assertIsInstance(db, _FakeSession)
                        generator.close()

    def test_get_db_does_not_retry_non_transient(self) -> None:
        failing_session = _FakeSession([_operational_error('syntax error at or near "FROM"')])

        def _factory():
            return failing_session

        with patch('backend_fastapi.app.database._ensure_session_factory', return_value=_factory):
            with patch.object(database.settings, 'db_retry_attempts', 3):
                with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                    with self.assertRaises(OperationalError):
                        next(database.get_db())


if __name__ == '__main__':
    unittest.main()
