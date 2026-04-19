import 'package:flutter/material.dart';

/// High-level UI/theme preference persisted locally on the device.
enum AtalayaThemePreference {
  system(
    'Sistema',
    'Sigue automáticamente el tema del dispositivo.',
    Icons.phone_android_rounded,
  ),
  dark(
    'Oscuro',
    'Azules medianoche para reducir fatiga visual en campo.',
    Icons.dark_mode_rounded,
  ),
  light(
    'Claro',
    'Grises neutros de alto contraste para ambientes iluminados.',
    Icons.light_mode_rounded,
  );

  const AtalayaThemePreference(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  ThemeMode get themeMode {
    switch (this) {
      case AtalayaThemePreference.system:
        return ThemeMode.system;
      case AtalayaThemePreference.dark:
        return ThemeMode.dark;
      case AtalayaThemePreference.light:
        return ThemeMode.light;
    }
  }

  static AtalayaThemePreference fromRaw(String? raw) {
    for (final value in AtalayaThemePreference.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return AtalayaThemePreference.dark;
  }
}

enum AtalayaLanguage {
  es('Español'),
  en('English');

  const AtalayaLanguage(this.label);

  final String label;

  static AtalayaLanguage fromRaw(String? raw) {
    for (final value in AtalayaLanguage.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return AtalayaLanguage.es;
  }
}

enum AtalayaUnitSystem {
  field('Campo', 'Unidades de origen'),
  english('Inglés', 'psi · lbf · gpm · ft'),
  metric('Métrico', 'bar · kgf · lpm · m');

  const AtalayaUnitSystem(this.label, this.description);

  final String label;
  final String description;

  static AtalayaUnitSystem fromRaw(String? raw) {
    for (final value in AtalayaUnitSystem.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return AtalayaUnitSystem.field;
  }
}

enum AtalayaAlarmOperator {
  greaterOrEqual('≥'),
  lessOrEqual('≤');

  const AtalayaAlarmOperator(this.symbol);

  final String symbol;

  bool evaluate(double current, double threshold) {
    switch (this) {
      case AtalayaAlarmOperator.greaterOrEqual:
        return current >= threshold;
      case AtalayaAlarmOperator.lessOrEqual:
        return current <= threshold;
    }
  }

  static AtalayaAlarmOperator fromRaw(String? raw) {
    for (final value in AtalayaAlarmOperator.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return AtalayaAlarmOperator.greaterOrEqual;
  }
}

class OperationalAlarmRule {
  const OperationalAlarmRule({
    required this.id,
    required this.variableTag,
    required this.variableLabel,
    required this.operator,
    required this.threshold,
    required this.enabled,
    required this.visual,
    required this.sound,
  });

  final String id;
  final String variableTag;
  final String variableLabel;
  final AtalayaAlarmOperator operator;
  final double threshold;
  final bool enabled;
  final bool visual;
  final bool sound;

  factory OperationalAlarmRule.fromJson(Map<String, dynamic> json) {
    return OperationalAlarmRule(
      id: (json['id'] ?? '').toString(),
      variableTag: (json['variableTag'] ?? json['variable_tag'] ?? '').toString(),
      variableLabel: (json['variableLabel'] ?? json['variable_label'] ?? '').toString(),
      operator: AtalayaAlarmOperator.fromRaw(json['operator']?.toString()),
      threshold: _asDouble(json['threshold']) ?? 0,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      visual: json['visual'] is bool ? json['visual'] as bool : true,
      sound: json['sound'] is bool ? json['sound'] as bool : false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'variableTag': variableTag,
      'variableLabel': variableLabel,
      'operator': operator.name,
      'threshold': threshold,
      'enabled': enabled,
      'visual': visual,
      'sound': sound,
    };
  }

  OperationalAlarmRule copyWith({
    String? id,
    String? variableTag,
    String? variableLabel,
    AtalayaAlarmOperator? operator,
    double? threshold,
    bool? enabled,
    bool? visual,
    bool? sound,
  }) {
    return OperationalAlarmRule(
      id: id ?? this.id,
      variableTag: variableTag ?? this.variableTag,
      variableLabel: variableLabel ?? this.variableLabel,
      operator: operator ?? this.operator,
      threshold: threshold ?? this.threshold,
      enabled: enabled ?? this.enabled,
      visual: visual ?? this.visual,
      sound: sound ?? this.sound,
    );
  }

  static double? _asDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '.'));
  }
}

class AppSettings {
  const AppSettings({
    required this.themePreference,
    required this.language,
    required this.unitSystem,
    required this.pollingIntervalSeconds,
    required this.pushAlertsEnabled,
    required this.operationalAlarms,
  });

  static const List<int> pollingOptionsSeconds = <int>[1, 5, 10];

  static const AppSettings defaults = AppSettings(
    themePreference: AtalayaThemePreference.dark,
    language: AtalayaLanguage.es,
    unitSystem: AtalayaUnitSystem.field,
    pollingIntervalSeconds: 5,
    pushAlertsEnabled: true,
    operationalAlarms: <OperationalAlarmRule>[],
  );

  final AtalayaThemePreference themePreference;
  final AtalayaLanguage language;
  final AtalayaUnitSystem unitSystem;
  final int pollingIntervalSeconds;
  final bool pushAlertsEnabled;
  final List<OperationalAlarmRule> operationalAlarms;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final alarmsRaw = json['operationalAlarms'] ?? json['operational_alarms'];
    final alarms = alarmsRaw is List
        ? alarmsRaw
            .whereType<Map>()
            .map((item) => OperationalAlarmRule.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : defaults.operationalAlarms;

    final polling = _asInt(json['pollingIntervalSeconds'] ?? json['polling_interval_seconds']) ??
        defaults.pollingIntervalSeconds;

    return AppSettings(
      themePreference: AtalayaThemePreference.fromRaw(json['themePreference']?.toString()),
      language: AtalayaLanguage.fromRaw(json['language']?.toString()),
      unitSystem: AtalayaUnitSystem.fromRaw(json['unitSystem']?.toString()),
      pollingIntervalSeconds: polling <= 0 ? defaults.pollingIntervalSeconds : polling,
      pushAlertsEnabled: json['pushAlertsEnabled'] is bool
          ? json['pushAlertsEnabled'] as bool
          : defaults.pushAlertsEnabled,
      operationalAlarms: alarms,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themePreference': themePreference.name,
      'language': language.name,
      'unitSystem': unitSystem.name,
      'pollingIntervalSeconds': pollingIntervalSeconds,
      'pushAlertsEnabled': pushAlertsEnabled,
      'operationalAlarms': operationalAlarms.map((alarm) => alarm.toJson()).toList(growable: false),
    };
  }

  AppSettings copyWith({
    AtalayaThemePreference? themePreference,
    AtalayaLanguage? language,
    AtalayaUnitSystem? unitSystem,
    int? pollingIntervalSeconds,
    bool? pushAlertsEnabled,
    List<OperationalAlarmRule>? operationalAlarms,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      language: language ?? this.language,
      unitSystem: unitSystem ?? this.unitSystem,
      pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
      pushAlertsEnabled: pushAlertsEnabled ?? this.pushAlertsEnabled,
      operationalAlarms: operationalAlarms ?? this.operationalAlarms,
    );
  }

  static int? _asInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }
}
