import unittest
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from backend_fastapi.app.repositories.atalaya_repository import AtalayaDataRepository
from backend_fastapi.app.schemas import DashboardCoreOut, WellVariableOut


class DashboardCacheObservabilityTests(unittest.TestCase):
    def test_cache_hit_resets_samples_observability_fields(self) -> None:
        repo = AtalayaDataRepository(MagicMock())
        cached_payload = DashboardCoreOut(
            well='WELL-1',
            job='JOB-1',
            latestSampleAt=datetime.now(timezone.utc),
            latestSampleAgeSeconds=2,
            staleThresholdSeconds=10,
            variables=[
                WellVariableOut(slot=1, label='SPP', tag='SPP', rawUnit='psi', value=120.0, configured=True),
            ],
        )

        repo.last_samples_missing_tags = 99
        repo.last_samples_missing_ratio = 0.99
        repo.last_samples_resolution_ms = 999.9
        repo.last_samples_fallback_used = True

        with patch('backend_fastapi.app.repositories.atalaya_repository.settings.dashboard_cache_ttl_seconds', 60):
            with patch.object(AtalayaDataRepository, '_dashboard_cache_value', cached_payload):
                with patch.object(AtalayaDataRepository, '_dashboard_cache_expires_at', 10_000_000_000.0):
                    result = repo.fetch_dashboard(fresh=False)

        self.assertEqual(result.well, 'WELL-1')
        self.assertEqual(repo.last_dashboard_cache_status, 'HIT')
        self.assertEqual(repo.last_kp_cache_status, 'SKIP')
        self.assertEqual(repo.last_samples_source, 'CACHE')
        self.assertEqual(repo.last_samples_missing_tags, 0)
        self.assertEqual(repo.last_samples_missing_ratio, 0.0)
        self.assertEqual(repo.last_samples_resolution_ms, 0.0)
        self.assertFalse(repo.last_samples_fallback_used)


if __name__ == '__main__':
    unittest.main()
