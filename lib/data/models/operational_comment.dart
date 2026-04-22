class OperationalComment {
  const OperationalComment({
    required this.id,
    this.well,
    this.job,
    this.runId,
    this.source,
    this.author,
    required this.body,
    this.tags = const <String>[],
    this.pinned = false,
    this.createdAt,
    this.updatedAt,
    this.attachmentsCount = 0,
  });

  final String id;
  final String? well;
  final String? job;
  final String? runId;
  final String? source;
  final String? author;
  final String body;
  final List<String> tags;
  final bool pinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int attachmentsCount;

  factory OperationalComment.fromJson(Map<String, dynamic> json) {
    return OperationalComment(
      id: _asString(json['id']) ?? '',
      well: _asString(json['well']),
      job: _asString(json['job']),
      runId: _asString(json['runId'] ?? json['run_id']),
      source: _asString(json['source']),
      author: _asString(json['author']),
      body: _asString(json['body'] ?? json['message'] ?? json['text']) ?? '',
      tags: _asStringList(json['tags']),
      pinned: _asBool(json['pinned']),
      createdAt: _asDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _asDate(json['updatedAt'] ?? json['updated_at']),
      attachmentsCount: _asInt(json['attachmentsCount'] ?? json['attachments_count']),
    );
  }

  static String? _asString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y' || text == 'on';
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return const <String>[];

    return text
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
