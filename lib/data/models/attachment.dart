class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String url;
  final String mimeType;
  final int? sizeBytes;
  final DateTime? createdAt;

  bool get hasSecureUrl => url.trim().toLowerCase().startsWith('https://');

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Attachment').toString(),
      url: (json['url'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? json['mime_type'] ?? '').toString(),
      sizeBytes: _asInt(json['sizeBytes'] ?? json['size_bytes']),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt?.toUtc().toIso8601String(),
    };
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
