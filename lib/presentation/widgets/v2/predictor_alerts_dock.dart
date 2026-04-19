import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/atalaya_theme.dart';
import '../../../data/models/alert.dart';

class PredictorAlertsDock extends StatefulWidget {
  const PredictorAlertsDock({
    super.key,
    required this.alerts,
    this.embedded = false,
    this.onOpenAlert,
  });

  final List<AtalayaAlert> alerts;
  final bool embedded;
  final ValueChanged<AtalayaAlert>? onOpenAlert;

  @override
  State<PredictorAlertsDock> createState() => _PredictorAlertsDockState();
}

class _PredictorAlertsDockState extends State<PredictorAlertsDock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.embedded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final alerts = widget.alerts;
    final visibleAlerts = alerts.take(_expanded ? 5 : 1).toList(growable: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: widget.embedded ? 0.98 : 0.94),
        borderRadius: widget.embedded
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Predictor KPIs & Alerts',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text('${alerts.length}', style: TextStyle(color: colors.textSecondary)),
              if (alerts.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay alertas activas',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          for (final alert in visibleAlerts)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.plot,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _severityColor(alert.severity, colors).withValues(alpha: 0.72)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Predictor · ${DateFormat('HH:mm').format(alert.createdAt.toLocal())}',
                          style: TextStyle(color: colors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => widget.onOpenAlert?.call(alert),
                    child: const Text('VER'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity severity, AtalayaThemeColors colors) {
    switch (severity) {
      case AlertSeverity.critical:
        return colors.danger;
      case AlertSeverity.attention:
        return colors.warning;
      case AlertSeverity.ok:
        return colors.primary;
    }
  }
}
