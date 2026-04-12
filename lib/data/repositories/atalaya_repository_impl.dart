import '../../core/constants/trend_range.dart';
import '../../domain/repositories/atalaya_repository.dart';
import '../datasources/atalaya_api_client.dart';
import '../models/attachment.dart';
import '../models/dashboard_payload.dart';
import '../models/trend_point.dart';

class AtalayaRepositoryImpl implements AtalayaRepository {
  const AtalayaRepositoryImpl(this._apiClient);

  final AtalayaApiClient _apiClient;

  @override
  Future<DashboardPayload> getDashboard() {
    return _apiClient.fetchDashboard();
  }

  @override
  Future<List<TrendPoint>> getTrend({
    required String tag,
    required TrendRange range,
  }) {
    return _apiClient.fetchTrend(tag: tag, range: range);
  }

  @override
  Future<List<Attachment>> getAlertAttachments({
    required String alertId,
  }) {
    return _apiClient.fetchAlertAttachments(alertId);
  }
}
