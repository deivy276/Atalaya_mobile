class TrendPoint {
  const TrendPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final double value;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      timestamp: _asDateTime(json['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      value: _asDouble(json['value']) ?? 0,
    );
  }

  TrendPoint copyWith({
    DateTime? timestamp,
    double? value,
  }) {
    return TrendPoint(
      timestamp: timestamp ?? this.timestamp,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'value': value,
    };
  }

  static DateTime? _asDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  static double? _asDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }
}
