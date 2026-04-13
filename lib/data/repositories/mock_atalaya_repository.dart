import 'dart:math';

import '../../core/constants/trend_range.dart';
import '../../domain/repositories/atalaya_repository.dart';
import '../models/alert.dart';
import '../models/attachment.dart';
import '../models/dashboard_payload.dart';
import '../models/trend_point.dart';
import '../models/well_variable.dart';

class MockAtalayaRepository implements AtalayaRepository {
  const MockAtalayaRepository();

  @override
  Future<DashboardPayload> getDashboard() async {
    final now = DateTime.now().toUtc();
    return DashboardPayload(
      well: 'IXACHI-45',
      job: 'Monitoreo de pozo',
      latestSampleAt: now,
      staleThresholdSeconds: 12,
      variables: <WellVariable>[
        _variable(1, 'RPM', 'rpm', 'rpm', 132.4, now),
        _variable(2, 'Torque', 'torque', 'ft-lbf', 95.2, now),
        _variable(3, 'Mud Flow In', 'mud_flow_in', 'gpm', 472.6, now),
        _variable(4, 'Standpipe Pressure', 'standpipe_pressure', 'psi', 2185.0, now),
        _variable(5, 'Weight on Bit', 'weight_on_bit', 'klbf', 21.4, now),
        _variable(6, 'Hook Load', 'hook_load', 'klbf', 192.0, now),
        _variable(7, 'ROP', 'rop', 'ft/hr', 42.5, now),
        _variable(8, 'Pump Pressure', 'pump_pressure', 'psi', 3050.0, now),
      ],
      alerts: <AtalayaAlert>[
        AtalayaAlert(
          id: 'mock-002',
          description: 'KP: standpipe_pressure muestra desviación sobre banda de operación.',
          severity: AlertSeverity.attention,
          createdAt: now.subtract(const Duration(minutes: 2)),
          attachmentsCount: 0,
          attachments: const <Attachment>[],
        ),
        AtalayaAlert(
          id: 'mock-001',
          description: 'KP: torque en tendencia ascendente; ajustar parámetros de control gradualmente.',
          severity: AlertSeverity.ok,
          createdAt: now.subtract(const Duration(minutes: 5)),
          attachmentsCount: 0,
          attachments: const <Attachment>[],
        ),
      ],
    );
  }

  @override
  Future<List<TrendPoint>> getTrend({
    required String tag,
    required TrendRange range,
  }) async {
    final now = DateTime.now().toUtc();
    final pointCount = switch (range) {
      TrendRange.h2 => 30,
      TrendRange.h6 => 45,
      TrendRange.h12 => 60,
      TrendRange.h24 => 80,
    };

    final stepMinutes = switch (range) {
      TrendRange.h2 => 4,
      TrendRange.h6 => 8,
      TrendRange.h12 => 12,
      TrendRange.h24 => 18,
    };

    final baseline = _baselineForTag(tag);
    final rng = Random(tag.hashCode.abs());

    return List<TrendPoint>.generate(pointCount, (index) {
      final offset = pointCount - index;
      final timestamp = now.subtract(Duration(minutes: offset * stepMinutes));
      final wave = sin(index / 3.6) * (baseline * 0.06);
      final noise = (rng.nextDouble() - 0.5) * (baseline * 0.02);
      final drift = (index / pointCount) * (baseline * 0.03);
      final value = (baseline + wave + noise + drift).clamp(0.0, double.infinity);
      return TrendPoint(timestamp: timestamp, value: value);
    }, growable: false);
  }

  @override
  Future<List<Attachment>> getAlertAttachments({
    required String alertId,
  }) async {
    return const <Attachment>[];
  }

  WellVariable _variable(
    int slot,
    String label,
    String tag,
    String rawUnit,
    double value,
    DateTime sampleAt,
  ) {
    return WellVariable(
      slot: slot,
      label: label,
      tag: tag,
      rawUnit: rawUnit,
      value: value,
      rawTextValue: null,
      sampleAt: sampleAt,
      configured: true,
    );
  }

  double _baselineForTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'rpm':
        return 130;
      case 'torque':
        return 95;
      case 'mud_flow_in':
        return 470;
      case 'standpipe_pressure':
        return 2200;
      case 'weight_on_bit':
        return 22;
      case 'hook_load':
        return 192;
      case 'rop':
        return 40;
      case 'pump_pressure':
        return 3000;
      default:
        return 100;
    }
  }
}
