import unittest
from unittest.mock import patch

import psycopg
from sqlalchemy.exc import OperationalError

from backend_fastapi.app import database


def _operational_error(message: str) -> OperationalError:
    return OperationalError('SELECT 1', {}, RuntimeError(message))


def _psycopg_operational_error(message: str) -> psycopg.OperationalError:
    return psycopg.OperationalError(message)


class DatabaseRetryTests(unittest.TestCase):
    def test_transient_operational_error_detection(self) -> None:
        transient = _operational_error('failed to resolve host')
        non_transient = _operational_error('relation "missing_table" does not exist')

        self.assertTrue(database._is_transient_operational_error(transient))
        self.assertFalse(database._is_transient_operational_error(non_transient))

    def test_connect_with_retry_retries_transient_failures(self) -> None:
        calls = {'count': 0}

        def _fake_connect(**kwargs):
            calls['count'] += 1
            if calls['count'] == 1:
                raise _psycopg_operational_error('could not connect')
            return object()

        with patch.object(database.settings, 'db_retry_attempts', 2):
            with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                with patch('backend_fastapi.app.database.sleep', return_value=None):
                    with patch('backend_fastapi.app.database.psycopg.connect', side_effect=_fake_connect):
                        conn = database._connect_with_retry()
        self.assertIsNotNone(conn)
        self.assertEqual(calls['count'], 2)

    def test_connect_with_retry_does_not_retry_non_transient(self) -> None:
        with patch.object(database.settings, 'db_retry_attempts', 3):
            with patch.object(database.settings, 'db_retry_backoff_ms', 0):
                with patch(
                    'backend_fastapi.app.database.psycopg.connect',
                    side_effect=_psycopg_operational_error('syntax error at or near "FROM"'),
                ):
                    with self.assertRaises(psycopg.OperationalError):
                        database._connect_with_retry()


if __name__ == '__main__':
    unittest.main()
