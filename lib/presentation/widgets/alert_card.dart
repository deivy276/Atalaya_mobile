import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/pro_palette.dart';
import '../../data/models/alert.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.isNew,
    this.onTap,
    this.onAttachmentTap,
    this.onAcknowledgeTap,
  });

  final AtalayaAlert alert;
  final bool isNew;
  final VoidCallback? onTap;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onAcknowledgeTap;

  @override
  Widget build(BuildContext context) {
    final visual = _severityVisual(alert.severity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: ProPalette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isNew ? ProPalette.accent : ProPalette.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 34,
                      decoration: BoxDecoration(
                        color: visual.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'KP ${alert.id}',
                        style: const TextStyle(
                          color: ProPalette.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.createdAt.toLocal()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                    if (onAcknowledgeTap != null) ...<Widget>[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Acknowledge',
                        onPressed: onAcknowledgeTap,
                        icon: const Icon(Icons.done_all_rounded, color: ProPalette.accent, size: 18),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  alert.description,
                  style: const TextStyle(
                    color: ProPalette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (isNew) ...<Widget>[
                      _Chip(
                        label: 'NEW',
                        textColor: ProPalette.accent,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (alert.attachmentsCount > 0) ...<Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onAttachmentTap,
                        child: _Chip(
                          label: '📎 ${alert.attachmentsCount}',
                          textColor: ProPalette.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _Chip(
                      label: visual.label,
                      textColor: visual.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _AlertVisual _severityVisual(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const _AlertVisual(ProPalette.danger, 'CRIT');
      case AlertSeverity.attention:
        return const _AlertVisual(ProPalette.warn, 'ATTN');
      case AlertSeverity.ok:
        return const _AlertVisual(ProPalette.ok, 'OK');
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.textColor,
  });

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ProPalette.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AlertVisual {
  const _AlertVisual(this.color, this.label);

  final Color color;
  final String label;
}
