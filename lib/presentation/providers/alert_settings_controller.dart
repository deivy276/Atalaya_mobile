import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/alert.dart';
import '../../data/models/alert_settings.dart';

class AlertSettingsController extends Notifier<AlertSettings> {
  static const String _storageKey = 'notif_settings';

  @override
  AlertSettings build() {
    _load();
    return AlertSettings.defaults;
  }

  Future<void> replace(AlertSettings settings) async {
    state = settings;
    await _save(settings);
  }

  Future<void> setEnabled(bool value) async {
    await replace(state.copyWith(enabled: value));
  }

  Future<void> setVisual(bool value) async {
    await replace(state.copyWith(visual: value));
  }

  Future<void> setSound(bool value) async {
    await replace(state.copyWith(sound: value));
  }

  Future<void> setVibrate(bool value) async {
    await replace(state.copyWith(vibrate: value));
  }

  Future<void> setMinSeverity(Object? value) async {
    final severity = value is AlertSeverity
        ? value
        : AlertSeverity.fromRaw(value?.toString());
    await replace(state.copyWith(minSeverity: severity));
  }

  Future<void> setQuietHours(bool enabled) async {
    await replace(state.copyWith(quietHours: enabled));
  }

  Future<void> setQuietStart(String value) async {
    await replace(state.copyWith(quietStart: value));
  }

  Future<void> setQuietEnd(String value) async {
    await replace(state.copyWith(quietEnd: value));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }

    state = AlertSettings.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _save(AlertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
  }
}

final alertSettingsControllerProvider =
    NotifierProvider<AlertSettingsController, AlertSettings>(
  AlertSettingsController.new,
);
