import 'package:flutter/material.dart';

import '../../core/theme/pro_palette.dart';
import '../providers/dashboard_controller.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ProPalette.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: visual.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            visual.label,
            style: TextStyle(
              color: visual.color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  _StatusVisual _visualFor(ConnectionStatus value) {
    switch (value) {
      case ConnectionStatus.connected:
        return const _StatusVisual('CONNECTED', ProPalette.ok);
      case ConnectionStatus.stale:
        return const _StatusVisual('STALE', ProPalette.warn);
      case ConnectionStatus.offline:
        return const _StatusVisual('OFFLINE', ProPalette.danger);
      case ConnectionStatus.retrying:
        return const _StatusVisual('RETRYING...', ProPalette.danger);
      case ConnectionStatus.waiting:
        return const _StatusVisual('WAITING...', ProPalette.muted);
    }
  }
}

class _StatusVisual {
  const _StatusVisual(this.label, this.color);

  final String label;
  final Color color;
}
