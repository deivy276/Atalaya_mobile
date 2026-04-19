import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/operational_alarm_events_provider.dart';

class AtalayaAlarmFeedback {
  AtalayaAlarmFeedback._();

  static DateTime? _lastSoundAt;

  static Future<void> playStandardAlarmSound({bool vibrate = true}) async {
    final now = DateTime.now();
    final previous = _lastSoundAt;
    if (previous != null && now.difference(previous).inMilliseconds < 650) {
      return;
    }
    _lastSoundAt = now;

    await SystemSound.play(SystemSoundType.alert);
    if (vibrate) {
      await HapticFeedback.heavyImpact();
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await SystemSound.play(SystemSoundType.alert);
    if (vibrate) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> presentOperationalAlarm(
    BuildContext context,
    OperationalAlarmEvent event, {
    required bool visual,
    required bool sound,
    required bool vibrate,
  }) async {
    if (sound) {
      await playStandardAlarmSound(vibrate: vibrate);
    }

    if (!visual || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
          backgroundColor: const Color(0xFF7F1D1D),
          elevation: 8,
          leading: const Icon(
            Icons.notification_important_rounded,
            color: Colors.white,
            size: 30,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'ALARMA OPERACIONAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.message,
                style: const TextStyle(
                  color: Color(0xFFFFE4E6),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hora: ${_formatTime(event.triggeredAt.toLocal())}',
                style: const TextStyle(color: Color(0xFFFECACA), fontSize: 12),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => ScaffoldMessenger.maybeOf(context)?.hideCurrentMaterialBanner(),
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ],
      ),
    );
  }

  static String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
