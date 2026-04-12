import '../../core/constants/trend_range.dart';
import '../../data/models/attachment.dart';
import '../../data/models/dashboard_payload.dart';
import '../../data/models/trend_point.dart';

abstract class AtalayaRepository {
  Future<DashboardPayload> getDashboard();

  Future<List<TrendPoint>> getTrend({
    required String tag,
    required TrendRange range,
  });

  Future<List<Attachment>> getAlertAttachments({
    required String alertId,
  });
}
