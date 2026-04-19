import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/well_variable.dart';
import 'alert_settings_controller.dart';
import 'app_settings_controller.dart';
import 'dashboard_controller.dart';

class OperationalAlarmEvent {
  const OperationalAlarmEvent({
    required this.rule,
    required this.variable,
    required this.value,
    required this.triggeredAt,
  });

  final OperationalAlarmRule rule;
  final WellVariable variable;
  final double value;
  final DateTime triggeredAt;

  String get ruleId => rule.id;

  String get valueText {
    final decimals = value.abs() >= 100 ? 1 : 2;
    return value.toStringAsFixed(decimals);
  }

  String get thresholdText {
    final threshold = rule.threshold;
    final decimals = threshold.abs() >= 100 ? 1 : 2;
    return threshold.toStringAsFixed(decimals);
  }

  String get message {
    final unit = variable.rawUnit.trim();
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    return '${rule.variableLabel}: $valueText$unitSuffix ${rule.operator.symbol} $thresholdText$unitSuffix';
  }
}

final operationalAlarmEventsProvider = Provider<List<OperationalAlarmEvent>>((ref) {
  final dashboard = ref.watch(dashboardControllerProvider).value;
  final appSettings = ref.watch(appSettingsControllerProvider);
  final alertSettings = ref.watch(alertSettingsControllerProvider);

  if (dashboard == null || dashboard.payload.variables.isEmpty) {
    return const <OperationalAlarmEvent>[];
  }
  if (!appSettings.pushAlertsEnabled || !alertSettings.enabled) {
    return const <OperationalAlarmEvent>[];
  }
  if (appSettings.operationalAlarms.isEmpty) {
    return const <OperationalAlarmEvent>[];
  }

  final variablesByTag = <String, WellVariable>{};
  for (final variable in dashboard.payload.variables) {
    final key = variable.tag.trim().toUpperCase();
    if (key.isNotEmpty) {
      variablesByTag[key] = variable;
    }
  }

  final triggered = <OperationalAlarmEvent>[];
  final now = DateTime.now().toUtc();

  for (final rule in appSettings.operationalAlarms) {
    if (!rule.enabled) {
      continue;
    }

    final variable = variablesByTag[rule.variableTag.trim().toUpperCase()];
    final currentValue = variable?.value;
    if (variable == null || currentValue == null) {
      continue;
    }

    if (!rule.operator.evaluate(currentValue, rule.threshold)) {
      continue;
    }

    triggered.add(
      OperationalAlarmEvent(
        rule: rule,
        variable: variable,
        value: currentValue,
        triggeredAt: variable.sampleAt?.toUtc() ?? dashboard.payload.latestSampleAt?.toUtc() ?? now,
      ),
    );
  }

  return triggered;
});
