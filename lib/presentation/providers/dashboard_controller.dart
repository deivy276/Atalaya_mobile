import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/alert.dart';
import '../../data/models/dashboard_payload.dart';
import '../../data/models/app_settings.dart';
import 'alert_settings_controller.dart';
import 'app_settings_controller.dart';
import 'api_client_provider.dart';

enum ConnectionStatus {
  waiting,
  connected,
  stale,
  offline,
  retrying,
}

class DashboardViewState {
  const DashboardViewState({
    required this.payload,
    required this.connectionStatus,
    required this.isRefreshing,
    required this.newAlertIds,
    required this.errorMessage,
    required this.variableHistoryByTag,
    required this.latestIncomingAlert,
  });

  final DashboardPayload payload;
  final ConnectionStatus connectionStatus;
  final bool isRefreshing;
  final Set<String> newAlertIds;
  final String? errorMessage;
  final Map<String, List<double>> variableHistoryByTag;
  final AtalayaAlert? latestIncomingAlert;

  DashboardViewState copyWith({
    DashboardPayload? payload,
    ConnectionStatus? connectionStatus,
    bool? isRefreshing,
    Set<String>? newAlertIds,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<String, List<double>>? variableHistoryByTag,
    AtalayaAlert? latestIncomingAlert,
    bool clearLatestIncomingAlert = false,
  }) {
    return DashboardViewState(
      payload: payload ?? this.payload,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      newAlertIds: newAlertIds ?? this.newAlertIds,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      variableHistoryByTag: variableHistoryByTag ?? this.variableHistoryByTag,
      latestIncomingAlert: clearLatestIncomingAlert ? null : (latestIncomingAlert ?? this.latestIncomingAlert),
    );
  }

  factory DashboardViewState.fromPayload(
    DashboardPayload payload, {
    required ConnectionStatus connectionStatus,
    Set<String> newAlertIds = const <String>{},
    String? errorMessage,
    Map<String, List<double>> variableHistoryByTag = const <String, List<double>>{},
    AtalayaAlert? latestIncomingAlert,
  }) {
    return DashboardViewState(
      payload: payload,
      connectionStatus: connectionStatus,
      isRefreshing: false,
      newAlertIds: newAlertIds,
      errorMessage: errorMessage,
      variableHistoryByTag: variableHistoryByTag,
      latestIncomingAlert: latestIncomingAlert,
    );
  }
}

final dashboardControllerProvider = AsyncNotifierProvider<DashboardController, DashboardViewState>(
  DashboardController.new,
);

final notifiableAlertProvider = Provider<AtalayaAlert?>((ref) {
  final dashboard = ref.watch(dashboardControllerProvider).value;
  final settings = ref.watch(alertSettingsControllerProvider);

  if (dashboard == null || dashboard.newAlertIds.isEmpty) {
    return null;
  }
  if (!settings.enabled || !settings.visual) {
    return null;
  }

  for (final alert in dashboard.payload.alerts) {
    if (!dashboard.newAlertIds.contains(alert.id)) {
      continue;
    }
    if (alert.severity.rank < settings.minSeverity.rank) {
      continue;
    }
    return alert;
  }

  return null;
});

class DashboardController extends AsyncNotifier<DashboardViewState> {
  static const Duration _basePollInterval = Duration(seconds: 4);
  static const Duration _maxPollInterval = Duration(seconds: 15);
  static const int _staleGraceSeconds = 8;
  static const int _maxHistoryPointsPerVariable = 24;

  Timer? _pollTimer;
  bool _refreshInFlight = false;
  int _retryCount = 0;
  int _consecutiveFailures = 0;
  DateTime? _lastAlertSeenAt;
  String? _lastAlertSeenId;

  @override
  Future<DashboardViewState> build() async {
    ref.listen<AppSettings>(appSettingsControllerProvider, (previous, next) {
      if (previous?.pollingIntervalSeconds != next.pollingIntervalSeconds) {
        _scheduleNextPoll(immediate: true);
      }
    });

    final initial = await _fetch(initialLoad: true, silent: true);
    _scheduleNextPoll();
    ref.onDispose(() => _pollTimer?.cancel());
    return initial;
  }

  Future<void> forceRefresh() async {
    await _fetch(initialLoad: false, silent: false);
    _scheduleNextPoll(immediate: false);
  }

  Future<void> retryNow() async {
    await forceRefresh();
  }

  void _scheduleNextPoll({bool immediate = false}) {
    _pollTimer?.cancel();
    final configuredInterval = ref.read(appSettingsControllerProvider).pollingIntervalSeconds;
    final baseInterval = Duration(seconds: configuredInterval <= 0 ? _basePollInterval.inSeconds : configuredInterval);
    final delay = immediate
        ? Duration.zero
        : Duration(
            seconds: (baseInterval.inSeconds + (_consecutiveFailures * 2)).clamp(
              baseInterval.inSeconds,
              _maxPollInterval.inSeconds,
            ),
          );

    _pollTimer = Timer(delay, () async {
      if (!ref.mounted) {
        return;
      }
      await _fetch(initialLoad: false, silent: true);
      _scheduleNextPoll();
    });
  }

  Future<DashboardViewState> _fetch({
    required bool initialLoad,
    required bool silent,
  }) async {
    if (_refreshInFlight) {
      return state.value ??
          DashboardViewState.fromPayload(
            DashboardPayload.empty(),
            connectionStatus: ConnectionStatus.waiting,
          );
    }

    _refreshInFlight = true;
    final previous = state.value;

    if (!initialLoad && !silent && previous != null) {
      state = AsyncData(previous.copyWith(isRefreshing: true, clearErrorMessage: true));
    }

    try {
      final repository = ref.read(atalayaRepositoryProvider);
      final rawPayload = await repository.getDashboard();
      final payload = _applyOperationalAlarms(rawPayload);
      _retryCount = 0;
      _consecutiveFailures = 0;
      final newAlertIds = _collectNewAlertIds(payload.alerts);
      final next = DashboardViewState.fromPayload(
        payload,
        connectionStatus: _deriveStatus(payload, previous: previous),
        newAlertIds: newAlertIds,
        variableHistoryByTag: _mergeVariableHistory(previous?.variableHistoryByTag, payload),
        latestIncomingAlert: _resolveLatestIncomingAlert(payload.alerts, newAlertIds),
      );
      state = AsyncData(next);
      return next;
    } catch (error) {
      _retryCount += 1;
      _consecutiveFailures += 1;
      final friendlyError = _toFriendlyErrorMessage(error);
      if (previous != null) {
        final fallback = previous.copyWith(
          connectionStatus: _retryCount >= 5 ? ConnectionStatus.offline : ConnectionStatus.retrying,
          isRefreshing: false,
          errorMessage: friendlyError,
        );
        state = AsyncData(fallback);
        return fallback;
      }
      final fallback = DashboardViewState.fromPayload(
        DashboardPayload.empty(),
        connectionStatus: ConnectionStatus.offline,
        errorMessage: friendlyError,
      );
      state = AsyncData(fallback);
      return fallback;
    } finally {
      _refreshInFlight = false;
    }
  }

  DashboardPayload _applyOperationalAlarms(DashboardPayload payload) {
    final settings = ref.read(appSettingsControllerProvider);
    if (settings.operationalAlarms.isEmpty || payload.variables.isEmpty) {
      return payload;
    }

    final generated = <AtalayaAlert>[];
    final now = DateTime.now().toUtc();

    for (final alarm in settings.operationalAlarms) {
      if (!alarm.enabled || !alarm.visual) {
        continue;
      }

      for (final variable in payload.variables) {
        final sameTag = variable.tag.trim().toUpperCase() == alarm.variableTag.trim().toUpperCase();
        if (!sameTag || variable.value == null) {
          continue;
        }

        if (!alarm.operator.evaluate(variable.value!, alarm.threshold)) {
          continue;
        }

        generated.add(
          AtalayaAlert(
            id: 'local-alarm-${alarm.id}-${variable.sampleAt?.millisecondsSinceEpoch ?? now.millisecondsSinceEpoch}',
            description:
                'Alarma local: ${alarm.variableLabel} ${alarm.operator.symbol} ${alarm.threshold.toStringAsFixed(alarm.threshold.truncateToDouble() == alarm.threshold ? 0 : 2)}. Valor actual: ${variable.value!.toStringAsFixed(2)} ${variable.rawUnit}',
            severity: AlertSeverity.critical,
            createdAt: now,
            attachmentsCount: 0,
            attachments: const [],
          ),
        );
        break;
      }
    }

    if (generated.isEmpty) {
      return payload;
    }

    return DashboardPayload(
      well: payload.well,
      job: payload.job,
      latestSampleAt: payload.latestSampleAt,
      staleThresholdSeconds: payload.staleThresholdSeconds,
      variables: payload.variables,
      alerts: <AtalayaAlert>[...generated, ...payload.alerts],
    );
  }
  String _toFriendlyErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('503')) {
      return 'El backend respondió con error 503. Verifica que FastAPI tenga acceso a la base de datos y vuelve a intentar.';
    }
    if (raw.contains('No se pudo conectar')) {
      return raw;
    }
    return 'No fue posible actualizar el dashboard en este momento. Reintenta en unos segundos.';
  }

  ConnectionStatus _deriveStatus(
    DashboardPayload payload, {
    DashboardViewState? previous,
  }) {
    final latest = payload.latestSampleAt;
    if (latest == null) {
      return ConnectionStatus.stale;
    }

    final ageSeconds = DateTime.now().toUtc().difference(latest.toUtc()).inSeconds;
    if (ageSeconds <= payload.staleThresholdSeconds) {
      return ConnectionStatus.connected;
    }

    final withinGrace = ageSeconds <= (payload.staleThresholdSeconds + _staleGraceSeconds);
    if (withinGrace && previous?.connectionStatus == ConnectionStatus.connected) {
      return ConnectionStatus.connected;
    }

    return ConnectionStatus.stale;
  }


  Map<String, List<double>> _mergeVariableHistory(
    Map<String, List<double>>? previousHistory,
    DashboardPayload payload,
  ) {
    final merged = <String, List<double>>{};

    if (previousHistory != null) {
      for (final entry in previousHistory.entries) {
        merged[entry.key] = List<double>.from(entry.value);
      }
    }

    for (final variable in payload.variables) {
      final tag = variable.tag.trim();
      if (tag.isEmpty || variable.value == null) {
        continue;
      }
      final history = merged.putIfAbsent(tag, () => <double>[]);
      history.add(variable.value!);
      if (history.length > _maxHistoryPointsPerVariable) {
        final overflow = history.length - _maxHistoryPointsPerVariable;
        history.removeRange(0, overflow);
      }
    }

    return merged;
  }

  AtalayaAlert? _resolveLatestIncomingAlert(List<AtalayaAlert> alerts, Set<String> newAlertIds) {
    for (final alert in alerts) {
      if (newAlertIds.contains(alert.id)) {
        return alert;
      }
    }
    return null;
  }

  Set<String> _collectNewAlertIds(List<AtalayaAlert> alerts) {
    if (alerts.isEmpty) {
      return const <String>{};
    }

    final newest = alerts.first;
    final previousDate = _lastAlertSeenAt;
    final previousId = _lastAlertSeenId;

    _lastAlertSeenAt = newest.createdAt.toUtc();
    _lastAlertSeenId = newest.id;

    if (previousDate == null) {
      return const <String>{};
    }

    final newIds = <String>{};
    for (final alert in alerts) {
      final comparison = _compareAlertMarker(
        alert.createdAt.toUtc(),
        alert.id,
        previousDate,
        previousId ?? '',
      );
      if (comparison > 0) {
        newIds.add(alert.id);
      } else {
        break;
      }
    }
    return newIds;
  }

  int _compareAlertMarker(
    DateTime currentDate,
    String currentId,
    DateTime previousDate,
    String previousId,
  ) {
    final dateComparison = currentDate.compareTo(previousDate);
    if (dateComparison != 0) {
      return dateComparison;
    }

    final currentNumeric = int.tryParse(currentId);
    final previousNumeric = int.tryParse(previousId);
    if (currentNumeric != null && previousNumeric != null) {
      return currentNumeric.compareTo(previousNumeric);
    }
    return currentId.compareTo(previousId);
  }
}

