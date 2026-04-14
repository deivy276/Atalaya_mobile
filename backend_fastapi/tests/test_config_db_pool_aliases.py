import os
import unittest

from backend_fastapi.app.config import Settings


class ConfigDbPoolAliasesTests(unittest.TestCase):
    def setUp(self) -> None:
        self._snapshot = dict(os.environ)

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self._snapshot)

    def test_pool_short_aliases_are_applied(self) -> None:
        os.environ['POOL_SIZE'] = '4'
        os.environ['MAX_OVERFLOW'] = '2'
        os.environ['POOL_TIMEOUT'] = '9'
        os.environ['POOL_RECYCLE'] = '45'
        settings = Settings()
        self.assertEqual(settings.pool_size, 4)
        self.assertEqual(settings.max_overflow, 2)
        self.assertEqual(settings.pool_timeout_seconds, 9)
        self.assertEqual(settings.pool_recycle_seconds, 45)

    def test_legacy_db_pool_aliases_are_applied(self) -> None:
        os.environ['DB_POOL_SIZE'] = '6'
        os.environ['DB_MAX_OVERFLOW'] = '1'
        os.environ['DB_POOL_TIMEOUT_SECONDS'] = '12'
        os.environ['DB_POOL_RECYCLE_SECONDS'] = '120'
        settings = Settings()
        self.assertEqual(settings.pool_size, 6)
        self.assertEqual(settings.max_overflow, 1)
        self.assertEqual(settings.pool_timeout_seconds, 12)
        self.assertEqual(settings.pool_recycle_seconds, 120)


if __name__ == '__main__':
    unittest.main()
