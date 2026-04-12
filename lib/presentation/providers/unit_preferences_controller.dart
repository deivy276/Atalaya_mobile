import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitPreferencesController extends Notifier<Map<String, String>> {
  static const String _storageKey = 'unit_prefs';

  @override
  Map<String, String> build() {
    _load();
    return const <String, String>{};
  }

  Future<void> setPreference(String key, String value) async {
    final next = Map<String, String>.from(state);
    if (value.trim().toUpperCase() == 'RAW') {
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = next;
    await _save(next);
  }

  Future<void> clearPreference(String key) async {
    final next = Map<String, String>.from(state)..remove(key);
    state = next;
    await _save(next);
  }

  Future<void> clearAll() async {
    state = const <String, String>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
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

    if (!ref.mounted) {
      return;
    }

    state = decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<void> _save(Map<String, String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(values));
  }
}

final unitPreferencesControllerProvider =
    NotifierProvider<UnitPreferencesController, Map<String, String>>(
  UnitPreferencesController.new,
);
