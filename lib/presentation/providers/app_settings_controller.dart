import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_settings.dart';

class AppSettingsController extends Notifier<AppSettings> {
  static const String _storageKey = 'atalaya_app_settings_v1';

  bool _hasLocalMutation = false;

  @override
  AppSettings build() {
    _load();
    return AppSettings.defaults;
  }

  Future<void> setThemePreference(AtalayaThemePreference value) async => _replace(state.copyWith(themePreference: value));
  Future<void> setLanguage(AtalayaLanguage value) async => _replace(state.copyWith(language: value));
  Future<void> setUnitSystem(AtalayaUnitSystem value) async => _replace(state.copyWith(unitSystem: value));

  Future<void> setPollingIntervalSeconds(int value) async {
    final normalized = AppSettings.pollingOptionsSeconds.contains(value) ? value : AppSettings.defaults.pollingIntervalSeconds;
    await _replace(state.copyWith(pollingIntervalSeconds: normalized));
  }

  Future<void> setPushAlertsEnabled(bool value) async => _replace(state.copyWith(pushAlertsEnabled: value));

  Future<void> addOperationalAlarm(OperationalAlarmRule alarm) async {
    await _replace(state.copyWith(operationalAlarms: <OperationalAlarmRule>[...state.operationalAlarms, alarm]));
  }

  Future<void> toggleOperationalAlarm(String id, bool enabled) async {
    final next = state.operationalAlarms.map((alarm) => alarm.id == id ? alarm.copyWith(enabled: enabled) : alarm).toList(growable: false);
    await _replace(state.copyWith(operationalAlarms: next));
  }

  Future<void> removeOperationalAlarm(String id) async {
    final next = state.operationalAlarms.where((alarm) => alarm.id != id).toList(growable: false);
    await _replace(state.copyWith(operationalAlarms: next));
  }

  Future<void> reset() async => _replace(AppSettings.defaults);

  Future<void> _replace(AppSettings settings) async {
    _hasLocalMutation = true;
    state = settings;
    await _save(settings);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty || _hasLocalMutation) return;

    final decoded = jsonDecode(raw);
    if (decoded is! Map || _hasLocalMutation || !ref.mounted) return;

    state = AppSettings.fromJson(decoded.map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<void> _save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
  }
}

final appSettingsControllerProvider = NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);
