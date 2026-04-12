import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/alert.dart';
import '../../data/models/dashboard_payload.dart';
import 'alert_settings_controller.dart';
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
  });

  final DashboardPayload payload;
  final ConnectionStatus connectionStatus;
  final bool isRefreshing;
  final Set<String> newAlertIds;
  final String? errorMessage;

  DashboardViewState copyWith({
    DashboardPayload? payload,
    ConnectionStatus? connectionStatus,
    bool? isRefreshing,
    Set<String>? newAlertIds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DashboardViewState(
      payload: payload ?? this.payload,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      newAlertIds: newAlertIds ?? this.newAlertIds,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory DashboardViewState.fromPayload(
    DashboardPayload payload, {
    required ConnectionStatus connectionStatus,
    Set<String> newAlertIds = const <String>{},
    String? errorMessage,
  }) {
    return DashboardViewState(
      payload: payload,
      connectionStatus: connectionStatus,
      isRefreshing: false,
      newAlertIds: newAlertIds,
      errorMessage: errorMessage,
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
  Timer? _pollTimer;
  bool _pollingStarted = false;
  bool _refreshInFlight = false;
  int _retryCount = 0;
  DateTime? _lastAlertSeenAt;
  String? _lastAlertSeenId;

  @override
  Future<DashboardViewState> build() async {
    _ensurePolling();
    return _fetch(initialLoad: true, silent: true);
  }

  Future<void> forceRefresh() async {
    await _fetch(initialLoad: false, silent: false);
  }

  Future<void> retryNow() async {
    await forceRefresh();
  }

  void _ensurePolling() {
    if (_pollingStarted) {
      return;
    }
    _pollingStarted = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_fetch(initialLoad: false, silent: true));
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
    });
  }

  Future<DashboardViewState> _fetch({
    required bool initialLoad,
    required bool silent,
  }) async {
    if (_refreshInFlight) {
      return state.value ?? DashboardViewState.fromPayload(
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
      final payload = await repository.getDashboard();
      _retryCount = 0;
      final next = DashboardViewState.fromPayload(
        payload,
        connectionStatus: _deriveStatus(payload),
        newAlertIds: _collectNewAlertIds(payload.alerts),
      );
      state = AsyncData(next);
      return next;
    } catch (error, stackTrace) {
      _retryCount += 1;
      if (previous != null) {
        final fallback = previous.copyWith(
          connectionStatus: _retryCount >= 5
              ? ConnectionStatus.offline
              : ConnectionStatus.retrying,
          isRefreshing: false,
          errorMessage: error.toString(),
        );
        state = AsyncData(fallback);
        return fallback;
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      _refreshInFlight = false;
    }
  }

  ConnectionStatus _deriveStatus(DashboardPayload payload) {
    final latest = payload.latestSampleAt;
    if (latest == null) {
      return ConnectionStatus.stale;
    }

    final ageSeconds = DateTime.now().toUtc().difference(latest.toUtc()).inSeconds;
    if (ageSeconds > payload.staleThresholdSeconds) {
      return ConnectionStatus.stale;
    }
    return ConnectionStatus.connected;
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
