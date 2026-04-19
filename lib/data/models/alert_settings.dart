import 'alert.dart';

class AlertSettings {
  const AlertSettings({
    required this.enabled,
    required this.visual,
    required this.sound,
    required this.vibrate,
    required this.minSeverity,
    required this.quietHours,
    required this.quietStart,
    required this.quietEnd,
  });

  static const AlertSettings defaults = AlertSettings(
    enabled: true,
    visual: true,
    sound: true,
    vibrate: true,
    minSeverity: AlertSeverity.attention,
    quietHours: false,
    quietStart: '22:00',
    quietEnd: '06:00',
  );

  final bool enabled;
  final bool visual;
  final bool sound;
  final bool vibrate;
  final AlertSeverity minSeverity;
  final bool quietHours;
  final String quietStart;
  final String quietEnd;

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : defaults.enabled,
      visual: json['visual'] is bool ? json['visual'] as bool : defaults.visual,
      sound: json['sound'] is bool ? json['sound'] as bool : defaults.sound,
      vibrate: json['vibrate'] is bool ? json['vibrate'] as bool : defaults.vibrate,
      minSeverity: AlertSeverity.fromRaw(json['minSeverity']?.toString() ?? json['min_severity']?.toString()),
      quietHours: json['quietHours'] is bool ? json['quietHours'] as bool : defaults.quietHours,
      quietStart: (json['quietStart'] ?? defaults.quietStart).toString(),
      quietEnd: (json['quietEnd'] ?? defaults.quietEnd).toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'visual': visual,
      'sound': sound,
      'vibrate': vibrate,
      'minSeverity': minSeverity.wireValue,
      'quietHours': quietHours,
      'quietStart': quietStart,
      'quietEnd': quietEnd,
    };
  }

  AlertSettings copyWith({
    bool? enabled,
    bool? visual,
    bool? sound,
    bool? vibrate,
    AlertSeverity? minSeverity,
    bool? quietHours,
    String? quietStart,
    String? quietEnd,
  }) {
    return AlertSettings(
      enabled: enabled ?? this.enabled,
      visual: visual ?? this.visual,
      sound: sound ?? this.sound,
      vibrate: vibrate ?? this.vibrate,
      minSeverity: minSeverity ?? this.minSeverity,
      quietHours: quietHours ?? this.quietHours,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  bool shouldNotify({
    required AlertSeverity severity,
    required DateTime localNow,
  }) {
    if (!enabled) {
      return false;
    }
    if (severity.rank < minSeverity.rank) {
      return false;
    }
    if (quietHours && isInQuietHours(localNow)) {
      return false;
    }
    return true;
  }

  bool isInQuietHours(DateTime localNow) {
    if (!quietHours) {
      return false;
    }

    final start = _parseHhMm(quietStart);
    final end = _parseHhMm(quietEnd);
    if (start == null || end == null) {
      return false;
    }

    final nowMinutes = localNow.hour * 60 + localNow.minute;
    final startMinutes = start.$1 * 60 + start.$2;
    final endMinutes = end.$1 * 60 + end.$2;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  (int, int)? _parseHhMm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) {
      return null;
    }
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
      return null;
    }
    return (hh, mm);
  }
}
