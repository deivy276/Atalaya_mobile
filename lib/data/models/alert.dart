import 'attachment.dart';

enum AlertSeverity {
  ok,
  attention,
  critical;

  static AlertSeverity fromRaw(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'CRITICAL':
        return AlertSeverity.critical;
      case 'ATTENTION':
        return AlertSeverity.attention;
      case 'OK':
      default:
        return AlertSeverity.ok;
    }
  }

  String get wireValue {
    switch (this) {
      case AlertSeverity.ok:
        return 'OK';
      case AlertSeverity.attention:
        return 'ATTENTION';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }

  String get compactLabel {
    switch (this) {
      case AlertSeverity.ok:
        return 'OK';
      case AlertSeverity.attention:
        return 'ATTN';
      case AlertSeverity.critical:
        return 'CRIT';
    }
  }

  int get rank {
    switch (this) {
      case AlertSeverity.ok:
        return 0;
      case AlertSeverity.attention:
        return 1;
      case AlertSeverity.critical:
        return 2;
    }
  }
}

class AtalayaAlert {
  const AtalayaAlert({
    required this.id,
    required this.description,
    required this.severity,
    required this.createdAt,
    required this.attachmentsCount,
    required this.attachments,
  });

  final String id;
  final String description;
  final AlertSeverity severity;
  final DateTime createdAt;
  final int attachmentsCount;
  final List<Attachment> attachments;

  factory AtalayaAlert.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    final attachments = attachmentsRaw is List
        ? attachmentsRaw
            .whereType<Map>()
            .map((item) => Attachment.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <Attachment>[];

    return AtalayaAlert(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      severity: AlertSeverity.fromRaw(json['severity']?.toString()),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attachmentsCount: _asInt(json['attachmentsCount'] ?? json['attachments_count']) ?? attachments.length,
      attachments: attachments,
    );
  }

  AtalayaAlert copyWith({
    String? id,
    String? description,
    AlertSeverity? severity,
    DateTime? createdAt,
    int? attachmentsCount,
    List<Attachment>? attachments,
  }) {
    return AtalayaAlert(
      id: id ?? this.id,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      attachmentsCount: attachmentsCount ?? this.attachmentsCount,
      attachments: attachments ?? this.attachments,
    );
  }

  static int? _asInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  static DateTime? _asDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
