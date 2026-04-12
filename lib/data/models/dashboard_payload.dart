import 'alert.dart';
import 'well_variable.dart';

class DashboardPayload {
  const DashboardPayload({
    required this.well,
    required this.job,
    required this.latestSampleAt,
    required this.staleThresholdSeconds,
    required this.variables,
    required this.alerts,
  });

  final String well;
  final String job;
  final DateTime? latestSampleAt;
  final int staleThresholdSeconds;
  final List<WellVariable> variables;
  final List<AtalayaAlert> alerts;

  factory DashboardPayload.fromJson(Map<String, dynamic> json) {
    final variablesRaw = json['variables'];
    final alertsRaw = json['alerts'];

    return DashboardPayload(
      well: (json['well'] ?? '---').toString(),
      job: (json['job'] ?? '---').toString(),
      latestSampleAt: _asDateTime(json['latestSampleAt'] ?? json['latest_sample_at']),
      staleThresholdSeconds: _asInt(json['staleThresholdSeconds'] ?? json['stale_threshold_seconds']) ?? 10,
      variables: variablesRaw is List
          ? variablesRaw
              .whereType<Map>()
              .map((item) => WellVariable.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <WellVariable>[],
      alerts: alertsRaw is List
          ? alertsRaw
              .whereType<Map>()
              .map((item) => AtalayaAlert.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <AtalayaAlert>[],
    );
  }

  factory DashboardPayload.empty() {
    return const DashboardPayload(
      well: '---',
      job: '---',
      latestSampleAt: null,
      staleThresholdSeconds: 10,
      variables: <WellVariable>[],
      alerts: <AtalayaAlert>[],
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
