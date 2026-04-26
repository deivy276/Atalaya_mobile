class PredictorModeSummary {
  const PredictorModeSummary({
    required this.mode,
    required this.label,
    required this.labelEn,
    required this.labelEs,
    required this.variablesCount,
    required this.specialChartsCount,
  });

  final String mode;
  final String label;
  final String labelEn;
  final String labelEs;
  final int variablesCount;
  final int specialChartsCount;

  factory PredictorModeSummary.fromJson(Map<String, dynamic> json) {
    return PredictorModeSummary(
      mode: _asString(json['mode'] ?? json['operationMode']) ?? 'drilling',
      label: _asString(json['label']) ?? _asString(json['labelEs']) ?? _asString(json['labelEn']) ?? 'Drilling',
      labelEn: _asString(json['labelEn'] ?? json['label_en']) ?? 'Drilling',
      labelEs: _asString(json['labelEs'] ?? json['label_es']) ?? 'Perforación',
      variablesCount: _asInt(json['variablesCount'] ?? json['variables_count']) ?? 0,
      specialChartsCount: _asInt(json['specialChartsCount'] ?? json['special_charts_count']) ?? 0,
    );
  }
}

class PredictorVariableConfig {
  const PredictorVariableConfig({
    required this.slot,
    required this.key,
    required this.label,
    required this.labelEn,
    required this.labelEs,
    required this.mnemonic,
    required this.mnemonics,
    required this.fallbackMnemonics,
    required this.rawUnit,
    required this.displayUnit,
    required this.unitFamily,
    required this.enabled,
    required this.configured,
  });

  final int slot;
  final String key;
  final String label;
  final String labelEn;
  final String labelEs;
  final String mnemonic;
  final List<String> mnemonics;
  final List<String> fallbackMnemonics;
  final String rawUnit;
  final String displayUnit;
  final String unitFamily;
  final bool enabled;
  final bool configured;

  factory PredictorVariableConfig.fromJson(Map<String, dynamic> json) {
    final primary = _asString(json['mnemonic'] ?? json['tag']) ?? '';
    final allMnemonics = _asStringList(json['mnemonics']);
    final normalizedAll = <String>[
      if (primary.trim().isNotEmpty) primary.trim(),
      ...allMnemonics,
    ].map(_normalizeTag).where((item) => item.isNotEmpty).toSet().toList(growable: false);

    final fallbacks = _asStringList(json['fallbackMnemonics'] ?? json['fallback_mnemonics'])
        .map(_normalizeTag)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return PredictorVariableConfig(
      slot: _asInt(json['slot']) ?? 0,
      key: _asString(json['key']) ?? '',
      label: _asString(json['label']) ?? primary,
      labelEn: _asString(json['labelEn'] ?? json['label_en']) ?? _asString(json['label']) ?? primary,
      labelEs: _asString(json['labelEs'] ?? json['label_es']) ?? _asString(json['label']) ?? primary,
      mnemonic: _normalizeTag(primary),
      mnemonics: normalizedAll.isEmpty ? fallbacks : normalizedAll,
      fallbackMnemonics: fallbacks,
      rawUnit: _asString(json['rawUnit'] ?? json['raw_unit']) ?? '',
      displayUnit: _asString(json['displayUnit'] ?? json['display_unit']) ?? _asString(json['rawUnit'] ?? json['raw_unit']) ?? '',
      unitFamily: _asString(json['unitFamily'] ?? json['unit_family']) ?? '',
      enabled: _asBool(json['enabled'], defaultValue: true),
      configured: _asBool(json['configured'], defaultValue: true),
    );
  }
}

class PredictorChartConfig {
  const PredictorChartConfig({
    required this.type,
    required this.label,
    required this.labelEn,
    required this.labelEs,
    required this.unit,
    required this.enabled,
  });

  final String type;
  final String label;
  final String labelEn;
  final String labelEs;
  final String unit;
  final bool enabled;

  factory PredictorChartConfig.fromJson(Map<String, dynamic> json) {
    final type = _asString(json['type'] ?? json['id'] ?? json['apiValue'] ?? json['api_value']) ?? '';
    return PredictorChartConfig(
      type: type,
      label: _asString(json['label']) ?? _asString(json['title']) ?? type,
      labelEn: _asString(json['labelEn'] ?? json['label_en']) ?? _asString(json['label']) ?? type,
      labelEs: _asString(json['labelEs'] ?? json['label_es']) ?? _asString(json['label']) ?? type,
      unit: _asString(json['unit'] ?? json['displayUnit'] ?? json['display_unit']) ?? '',
      enabled: _asBool(json['enabled'], defaultValue: true),
    );
  }
}

class PredictorModeConfig {
  const PredictorModeConfig({
    required this.operationMode,
    required this.label,
    required this.labelEn,
    required this.labelEs,
    required this.variables,
    required this.specialCharts,
  });

  final String operationMode;
  final String label;
  final String labelEn;
  final String labelEs;
  final List<PredictorVariableConfig> variables;
  final List<PredictorChartConfig> specialCharts;

  factory PredictorModeConfig.fromJson(Map<String, dynamic> json) {
    final variablesRaw = json['variables'];
    final chartsRaw = json['specialCharts'] ?? json['special_charts'] ?? json['charts'];

    return PredictorModeConfig(
      operationMode: _asString(json['operationMode'] ?? json['operation_mode'] ?? json['mode']) ?? 'drilling',
      label: _asString(json['label']) ?? 'Drilling',
      labelEn: _asString(json['labelEn'] ?? json['label_en']) ?? _asString(json['label']) ?? 'Drilling',
      labelEs: _asString(json['labelEs'] ?? json['label_es']) ?? _asString(json['label']) ?? 'Perforación',
      variables: variablesRaw is List
          ? variablesRaw
              .whereType<Map>()
              .map((item) => PredictorVariableConfig.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <PredictorVariableConfig>[],
      specialCharts: chartsRaw is List
          ? chartsRaw
              .whereType<Map>()
              .map((item) => PredictorChartConfig.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.enabled)
              .toList(growable: false)
          : const <PredictorChartConfig>[],
    );
  }
}

String? _asString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _asBool(Object? value, {required bool defaultValue}) {
  if (value is bool) return value;
  if (value == null) return defaultValue;
  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) return defaultValue;
  return text == '1' || text == 'true' || text == 'yes' || text == 'y' || text == 'on' || text == 'si' || text == 'sí';
}

List<String> _asStringList(Object? value) {
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

String _normalizeTag(String raw) {
  var text = raw.trim().toUpperCase();
  while (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
