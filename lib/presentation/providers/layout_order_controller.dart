import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutOrderController extends Notifier<Map<String, List<int>>> {
  static const String _storageKey = 'layout_orders_v1';

  @override
  Map<String, List<int>> build() {
    _load();
    return const <String, List<int>>{};
  }

  List<int>? getOrder({required String well, required String job}) {
    final key = _contextKey(well: well, job: job);
    return state[key];
  }

  Future<void> setOrder({
    required String well,
    required String job,
    required List<int> slotOrder,
  }) async {
    final key = _contextKey(well: well, job: job);
    final next = Map<String, List<int>>.from(state)..[key] = List<int>.from(slotOrder);
    state = next;
    await _save(next);
  }

  Future<void> resetOrder({required String well, required String job}) async {
    final key = _contextKey(well: well, job: job);
    final next = Map<String, List<int>>.from(state)..remove(key);
    state = next;
    await _save(next);
  }

  String _contextKey({required String well, required String job}) =>
      'layout_order::${well.trim().toUpperCase()}::${job.trim().toUpperCase()}';

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

    final parsed = <String, List<int>>{};
    decoded.forEach((key, value) {
      if (value is! List) {
        return;
      }
      final slots = value.whereType<num>().map((n) => n.toInt()).toList(growable: false);
      parsed[key.toString()] = slots;
    });

    if (!ref.mounted) {
      return;
    }
    state = parsed;
  }

  Future<void> _save(Map<String, List<int>> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(values));
  }
}

final layoutOrderControllerProvider =
    NotifierProvider<LayoutOrderController, Map<String, List<int>>>(
  LayoutOrderController.new,
);
