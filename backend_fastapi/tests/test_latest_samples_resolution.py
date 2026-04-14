import unittest
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from backend_fastapi.app.repositories.atalaya_repository import AtalayaDataRepository, SampleTableMeta


class LatestSamplesResolutionTests(unittest.TestCase):
    def _repo(self) -> AtalayaDataRepository:
        return AtalayaDataRepository(MagicMock())

    def test_skips_heavy_fallback_when_missing_exceeds_threshold(self) -> None:
        repo = self._repo()
        now = datetime.now(timezone.utc)
        sample_meta = SampleTableMeta(schema='public', table='atalaya_samples', tag_col='tag', value_col='value', created_at_col='created_at', id_col='id')

        with patch('backend_fastapi.app.repositories.atalaya_repository.settings.latest_samples_fallback_max_missing_tags', 0):
            with patch('backend_fastapi.app.repositories.atalaya_repository.settings.latest_samples_fallback_max_missing_ratio', 0.0):
                with patch.object(repo, '_sample_table_meta', return_value=sample_meta):
                    with patch.object(repo, '_fetch_latest_samples_from_summary', return_value=[]):
                        with patch.object(
                            repo,
                            '_fetch_latest_samples_by_tag_exact',
                            return_value=[{'tag_norm': 'spp', 'actual_tag': 'SPP', 'value': 10.0, 'created_at': now}],
                        ):
                            with patch.object(repo, '_fetch_latest_samples_by_tag_normalized', return_value=[]):
                                with patch.object(repo, '_fetch_latest_samples_by_tag_fallback') as fallback:
                                    result = repo._fetch_latest_samples_by_tag(['SPP', 'RPM'])
                                    self.assertIn('spp', result)
                                    self.assertNotIn('rpm', result)
                                    self.assertEqual(repo.last_samples_source, 'BASE_TABLE_EXACT_PARTIAL')
                                    fallback.assert_not_called()

    def test_uses_normalized_path_before_fallback(self) -> None:
        repo = self._repo()
        now = datetime.now(timezone.utc)
        sample_meta = SampleTableMeta(schema='public', table='atalaya_samples', tag_col='tag', value_col='value', created_at_col='created_at', id_col='id')

        with patch.object(repo, '_sample_table_meta', return_value=sample_meta):
            with patch.object(repo, '_fetch_latest_samples_from_summary', return_value=[]):
                with patch.object(repo, '_fetch_latest_samples_by_tag_exact', return_value=[]):
                    with patch.object(
                        repo,
                        '_fetch_latest_samples_by_tag_normalized',
                        return_value=[{'tag_norm': 'rpm', 'actual_tag': 'RPM.', 'value': 120.0, 'created_at': now}],
                    ):
                        with patch.object(repo, '_fetch_latest_samples_by_tag_fallback') as fallback:
                            result = repo._fetch_latest_samples_by_tag(['RPM'])
                            self.assertIn('rpm', result)
                            self.assertEqual(repo.last_samples_source, 'BASE_TABLE_NORM')
                            fallback.assert_not_called()


if __name__ == '__main__':
    unittest.main()
