import 'package:dio/dio.dart';

import '../../core/constants/trend_range.dart';
import '../models/attachment.dart';
import '../models/dashboard_payload.dart';
import '../models/trend_point.dart';

class AtalayaApiClient {
  const AtalayaApiClient(this._dio);

  final Dio _dio;

  Future<DashboardPayload> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/dashboard');
    return DashboardPayload.fromJson(_asMap(response.data));
  }

  Future<List<TrendPoint>> fetchTrend({
    required String tag,
    required TrendRange range,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/trends',
      queryParameters: <String, dynamic>{
        'tag': tag,
        'range': range.label,
      },
    );

    final data = _asMap(response.data);
    final pointsRaw = data['points'];
    if (pointsRaw is! List) {
      return const <TrendPoint>[];
    }

    return pointsRaw
        .whereType<Map>()
        .map((item) => TrendPoint.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<Attachment>> fetchAlertAttachments(String alertId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/alerts/$alertId/attachments');
    final data = _asMap(response.data);
    final attachmentsRaw = data['attachments'];
    if (attachmentsRaw is! List) {
      return const <Attachment>[];
    }

    return attachmentsRaw
        .whereType<Map>()
        .map((item) => Attachment.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Map<String, dynamic>? raw) {
    return raw ?? <String, dynamic>{};
  }
}
