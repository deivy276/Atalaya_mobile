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
    this.onRefresh,
  });

  final List<AtalayaAlert> alerts;
  final bool embedded;
  final ValueChanged<AtalayaAlert>? onOpenAlert;

  /// Optional external refresh hook. Wire this from the dashboard to
  /// dashboardControllerProvider.notifier.forceRefresh() or provider invalidation.
  final VoidCallback? onRefresh;

  @override
  State<PredictorAlertsDock> createState() => _PredictorAlertsDockState();
}

class _PredictorAlertsDockState extends State<PredictorAlertsDock> {
  static const double _mobileExpandedMaxHeight = 520;

  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.embedded;
  }

  @override
  void didUpdateWidget(covariant PredictorAlertsDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alerts.length < oldWidget.alerts.length && widget.alerts.isEmpty) {
      _expanded = widget.embedded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final alerts = widget.alerts;
    final visibleAlerts = _expanded ? alerts : alerts.take(1).toList(growable: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: colors.isDark ? 0.96 : 0.98),
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
      child: widget.embedded
          ? Column(
              children: <Widget>[
                _AlertsHeader(
                  count: alerts.length,
                  expanded: _expanded,
                  onToggleExpanded: alerts.isEmpty ? null : _toggleExpanded,
                  onOpenAll: alerts.isEmpty ? null : () => _openAllAlertsSheet(context),
                  onRefresh: widget.onRefresh,
                ),
                if (alerts.isEmpty)
                  const Expanded(child: _EmptyAlertsState())
                else
                  Expanded(
                    child: _AlertsList(
                      alerts: visibleAlerts,
                      onOpenAlert: _openAlertFromList,
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _AlertsHeader(
                  count: alerts.length,
                  expanded: _expanded,
                  onToggleExpanded: alerts.isEmpty ? null : _toggleExpanded,
                  onOpenAll: alerts.isEmpty ? null : () => _openAllAlertsSheet(context),
                  onRefresh: widget.onRefresh,
                ),
                if (alerts.isEmpty)
                  const _EmptyAlertsState()
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _expanded ? _mobileExpandedMaxHeight : 116,
                    ),
                    child: _AlertsList(
                      alerts: visibleAlerts,
                      onOpenAlert: _openAlertFromList,
                    ),
                  ),
                if (alerts.length > 1) ...<Widget>[
                  const SizedBox(height: 10),
                  _OpenAllAlertsButton(
                    count: alerts.length,
                    onPressed: () => _openAllAlertsSheet(context),
                  ),
                ],
              ],
            ),
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  void _openAlertFromList(AtalayaAlert alert) {
    widget.onOpenAlert?.call(alert);
  }

  Future<void> _openAllAlertsSheet(BuildContext context) async {
    final colors = context.atalayaColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.card,
      barrierColor: Colors.black.withValues(alpha: colors.isDark ? 0.42 : 0.22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _AllAlertsSheet(
            alerts: widget.alerts,
            onOpenAlert: (alert) {
              Navigator.of(sheetContext).pop();
              Future<void>.microtask(() => widget.onOpenAlert?.call(alert));
            },
          ),
        );
      },
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({
    required this.count,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenAll,
    this.onRefresh,
  });

  final int count;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onOpenAll;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Predictor KPIs & Alerts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Actualizar alertas',
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ),
        Semantics(
          label: '$count alertas activas',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (count > 0)
          IconButton(
            tooltip: expanded ? 'Mostrar menos' : 'Mostrar más',
            onPressed: onToggleExpanded,
            icon: Icon(
              expanded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              color: colors.textSecondary,
            ),
          ),
        if (count > 1)
          IconButton(
            tooltip: 'Ver todas las alertas',
            onPressed: onOpenAll,
            icon: Icon(
              Icons.open_in_full_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ),
      ],
    );
  }
}

class _OpenAllAlertsButton extends StatelessWidget {
  const _OpenAllAlertsButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.list_alt_rounded, size: 18),
        label: Text('Ver las $count alertas'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({
    required this.alerts,
    required this.onOpenAlert,
  });

  final List<AtalayaAlert> alerts;
  final ValueChanged<AtalayaAlert> onOpenAlert;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _AlertCard(
        alert: alerts[index],
        onOpen: () => onOpenAlert(alerts[index]),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onOpen,
    this.compact = false,
  });

  final AtalayaAlert alert;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final color = _severityColor(alert.severity, colors);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: colors.cardAlt.withValues(alpha: colors.isDark ? 0.72 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: colors.isDark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.75)),
                      ),
                      child: Text(
                        alert.severity.compactLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Predictor · ${DateFormat('dd/MM HH:mm').format(alert.createdAt.toLocal())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  alert.description,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                if (alert.attachmentsCount > 0) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${alert.attachmentsCount} adjunto${alert.attachmentsCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onOpen,
            child: const Text('VER'),
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

class _AllAlertsSheet extends StatelessWidget {
  const _AllAlertsSheet({
    required this.alerts,
    required this.onOpenAlert,
  });

  final List<AtalayaAlert> alerts;
  final ValueChanged<AtalayaAlert> onOpenAlert;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Container(
      decoration: BoxDecoration(gradient: colors.pageGradient),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Alertas del Predictor (${alerts.length})',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Listado completo de alarmas y notas generadas. Desplázate para revisar todas.',
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: alerts.isEmpty
                  ? const _EmptyAlertsState()
                  : ListView.separated(
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _AlertCard(
                          alert: alert,
                          compact: false,
                          onOpen: () => onOpenAlert(alert),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlertsState extends StatelessWidget {
  const _EmptyAlertsState();

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Center(
        child: Text(
          'No hay alertas activas',
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}
