import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/operational_comment.dart';

/// Read-only client for Sprint 1 operational comments.
///
/// The backend endpoint is served by Atalaya Mobile API standalone, not by Dash:
///   GET /api/v1/comments
class CommentsApiService {
  CommentsApiService({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  Uri _uri(String path, Map<String, String?> query) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanQuery = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) {
        cleanQuery[entry.key] = value;
      }
    }
    return Uri.parse('$root$path').replace(queryParameters: cleanQuery);
  }

  /// Fetch recent comments.
  ///
  /// During Sprint 1B, Predictor may still publish comments using a Spanish job
  /// label such as "Monitoreo de pozo", while the mobile smoke test uses
  /// job="Drilling". For that reason, [job] is optional. Pass null to show all
  /// comments for the well, independent of job.
  Future<List<OperationalComment>> fetchComments({
    String well = 'IXACHI-45',
    String? job,
    int limit = 50,
  }) async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('No mobile auth token available. Login before fetching comments.');
    }

    final response = await _client.get(
      _uri('/api/v1/comments', <String, String?>{
        'well': well,
        'job': job,
        'limit': limit.toString(),
      }),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw StateError('Unauthorized loading operational comments. Refresh login.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Comments request failed: HTTP ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid comments payload: expected JSON object.');
    }
    if (decoded['ok'] == false) {
      throw StateError('Comments endpoint returned ok=false: ${decoded['error'] ?? decoded['warning'] ?? decoded}');
    }

    final items = decoded['items'];
    if (items is! List) return const <OperationalComment>[];

    return items
        .whereType<Map>()
        .map((item) => OperationalComment.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.body.trim().isNotEmpty)
        .toList(growable: false);
  }
}
