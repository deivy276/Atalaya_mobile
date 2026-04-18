import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/trend_range.dart';
import '../models/attachment.dart';
import '../models/dashboard_payload.dart';
import '../models/trend_point.dart';

class AtalayaApiClient {
  const AtalayaApiClient(this._dio);

  final Dio _dio;

  Future<DashboardPayload> fetchDashboard() async {
    final response = await _dio.get<dynamic>('/api/v1/dashboard');
    final data = _asMap(response.data);
    return DashboardPayload.fromJson(_unwrapPayload(data));
  }

  Future<List<TrendPoint>> fetchTrend({
    required String tag,
    required TrendRange range,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/trends',
      queryParameters: <String, dynamic>{
        'tag': tag,
        'range': range.label,
      },
    );

    final data = _unwrapPayload(_asMap(response.data));
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
    final response = await _dio.get<dynamic>('/api/v1/alerts/$alertId/attachments');
    final data = _unwrapPayload(_asMap(response.data));
    final attachmentsRaw = data['attachments'];
    if (attachmentsRaw is! List) {
      return const <Attachment>[];
    }

    return attachmentsRaw
        .whereType<Map>()
        .map((item) => Attachment.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> raw) {
    for (final key in const <String>['data', 'payload', 'result']) {
      final nested = raw[key];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }
    return raw;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw == null) {
      return <String, dynamic>{};
    }

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return raw.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html')) {
        throw StateError(
          'El backend respondió HTML en lugar de JSON. Verifica ATALAYA_API_BASE_URL y que la ruta API exista.',
        );
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map((key, dynamic value) => MapEntry(key.toString(), value));
      }
    }

    throw StateError('Respuesta API inválida: se esperaba un objeto JSON.');
  }
}
