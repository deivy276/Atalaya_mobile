import os
import unittest
from datetime import datetime, timezone

try:
    from fastapi.testclient import TestClient
except RuntimeError:
    TestClient = None

os.environ['AUTH_SKIP_DB_INIT'] = 'true'
os.environ['AUTH_ENABLED'] = 'false'
os.environ['AUTH_SECRET_KEY'] = 'DevStrongSecret#12345'

from backend_fastapi.app.database import get_db  # noqa: E402
from backend_fastapi.app.main import app, get_repository, settings  # noqa: E402
from backend_fastapi.app.schemas import DashboardCoreOut, DashboardOut, WellVariableOut  # noqa: E402


class _FakeRepository:
    def __init__(self) -> None:
        self.last_dashboard_cache_status = 'MISS'
        self.last_kp_cache_status = 'MISS'
        self.last_samples_source = 'BASE_TABLE_NORM'
        self.last_samples_missing_tags = 1
        self.last_samples_missing_ratio = 0.125
        self.last_samples_resolution_ms = 4.2
        self.last_samples_fallback_used = False
        self.last_alerts_cache_status = 'HIT'
        self.last_alerts_source = 'SUMMARY'
        self.last_alerts_text_repairs = 0

    def fetch_dashboard(self, *, fresh: bool = False) -> DashboardCoreOut:
        _ = fresh
        return DashboardCoreOut(
            well='WELL-1',
            job='JOB-1',
            latestSampleAt=datetime.now(timezone.utc),
            latestSampleAgeSeconds=3,
            staleThresholdSeconds=settings.stale_threshold_seconds,
            variables=[
                WellVariableOut(slot=1, label='SPP', tag='SPP', rawUnit='psi', value=120.0, configured=True),
            ],
        )

    def fetch_dashboard_full(self, *, fresh: bool = False, alerts_fresh: bool = False) -> DashboardOut:
        _ = fresh, alerts_fresh
        return DashboardOut(
            well='WELL-1',
            job='JOB-1',
            latestSampleAt=datetime.now(timezone.utc),
            latestSampleAgeSeconds=3,
            staleThresholdSeconds=settings.stale_threshold_seconds,
            variables=[
                WellVariableOut(slot=1, label='SPP', tag='SPP', rawUnit='psi', value=120.0, configured=True),
            ],
            alerts=[],
        )


def _fake_db():
    yield None


@unittest.skipIf(TestClient is None, 'fastapi.testclient requires httpx dependency')
class DashboardObservabilityHeaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self._original_auth_skip_db_init = settings.auth_skip_db_init
        self._original_auth_enabled = settings.auth_enabled
        self._original_auth_secret_key = settings.auth_secret_key
        settings.auth_skip_db_init = True
        settings.auth_enabled = False
        settings.auth_secret_key = 'DevStrongSecret#12345'
        app.dependency_overrides[get_db] = _fake_db
        app.dependency_overrides[get_repository] = lambda: _FakeRepository()

    def tearDown(self) -> None:
        settings.auth_skip_db_init = self._original_auth_skip_db_init
        settings.auth_enabled = self._original_auth_enabled
        settings.auth_secret_key = self._original_auth_secret_key
        app.dependency_overrides.clear()

    def test_dashboard_includes_samples_observability_headers(self) -> None:
        with TestClient(app) as client:
            response = client.get(f'{settings.api_prefix}/dashboard')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers.get('X-Samples-Source'), 'BASE_TABLE_NORM')
        self.assertEqual(response.headers.get('X-Samples-Missing-Tags'), '1')
        self.assertEqual(response.headers.get('X-Samples-Missing-Ratio'), '0.125')
        self.assertEqual(response.headers.get('X-Samples-Resolution-Ms'), '4.2')
        self.assertEqual(response.headers.get('X-Samples-Fallback-Used'), 'false')

    def test_dashboard_full_includes_samples_observability_headers(self) -> None:
        with TestClient(app) as client:
            response = client.get(f'{settings.api_prefix}/dashboard/full')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers.get('X-Samples-Source'), 'BASE_TABLE_NORM')
        self.assertEqual(response.headers.get('X-Samples-Missing-Tags'), '1')
        self.assertEqual(response.headers.get('X-Samples-Missing-Ratio'), '0.125')
        self.assertEqual(response.headers.get('X-Samples-Resolution-Ms'), '4.2')
        self.assertEqual(response.headers.get('X-Samples-Fallback-Used'), 'false')


if __name__ == '__main__':
    unittest.main()
