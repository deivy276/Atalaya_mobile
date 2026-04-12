class WellVariable {
  const WellVariable({
    required this.slot,
    required this.label,
    required this.tag,
    required this.rawUnit,
    required this.value,
    required this.rawTextValue,
    required this.sampleAt,
    required this.configured,
  });

  final int slot;
  final String label;
  final String tag;
  final String rawUnit;
  final double? value;
  final String? rawTextValue;
  final DateTime? sampleAt;
  final bool configured;

  factory WellVariable.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    final numericValue = _asDouble(rawValue);

    return WellVariable(
      slot: _asInt(json['slot']) ?? 0,
      label: (json['label'] ?? '').toString(),
      tag: (json['tag'] ?? '').toString(),
      rawUnit: (json['rawUnit'] ?? json['raw_unit'] ?? '').toString(),
      value: numericValue,
      rawTextValue: numericValue == null && rawValue != null ? rawValue.toString() : null,
      sampleAt: _asDateTime(json['sampleAt'] ?? json['sample_at']),
      configured: json['configured'] is bool ? json['configured'] as bool : true,
    );
  }

  factory WellVariable.empty(int slot) {
    return WellVariable(
      slot: slot,
      label: 'VAR $slot',
      tag: '',
      rawUnit: '',
      value: null,
      rawTextValue: null,
      sampleAt: null,
      configured: false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'slot': slot,
      'label': label,
      'tag': tag,
      'rawUnit': rawUnit,
      'value': value ?? rawTextValue,
      'sampleAt': sampleAt?.toUtc().toIso8601String(),
      'configured': configured,
    };
  }

  static int? _asInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  static double? _asDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static DateTime? _asDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
