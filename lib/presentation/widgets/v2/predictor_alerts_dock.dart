import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/layout_tokens.dart';
import '../../../data/models/alert.dart';

class PredictorAlertsDock extends StatefulWidget {
  const PredictorAlertsDock({
    super.key,
    required this.alerts,
    this.embedded = false,
  });

  final List<AtalayaAlert> alerts;
  final bool embedded;

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
    final alerts = widget.alerts;
    final visibleAlerts = alerts.take(_expanded ? 5 : 1).toList(growable: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: widget.embedded ? const Color(0xEE0A162A) : const Color(0xEE081427),
        borderRadius: widget.embedded
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Predictor KPIs & Alerts',
                  style: TextStyle(
                    color: LayoutTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text('${alerts.length}', style: const TextStyle(color: LayoutTokens.textSecondary)),
              if (alerts.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    color: LayoutTokens.textSecondary,
                  ),
                ),
            ],
          ),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No hay alertas activas',
                style: TextStyle(color: LayoutTokens.textMuted),
              ),
            ),
          for (final alert in visibleAlerts)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LayoutTokens.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _severityColor(alert.severity).withValues(alpha: 0.7)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Predictor · ${DateFormat('HH:mm').format(alert.createdAt.toLocal())}',
                          style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LayoutTokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: () {}, child: const Text('VER')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return LayoutTokens.accentRed;
      case AlertSeverity.attention:
        return LayoutTokens.accentOrange;
      case AlertSeverity.ok:
        return LayoutTokens.accentBlue;
    }
  }
}
