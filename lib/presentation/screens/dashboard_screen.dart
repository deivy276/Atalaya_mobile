import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/pro_palette.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/alert.dart';
import '../../data/models/attachment.dart';
import '../../data/models/dashboard_payload.dart';
import '../../data/models/well_variable.dart';
import '../providers/alert_attachments_provider.dart';
import '../providers/alert_settings_controller.dart';
import '../providers/dashboard_controller.dart';
import '../providers/layout_order_controller.dart';
import '../providers/trend_controller.dart';
import '../providers/unit_preferences_controller.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/trend_chart_widget.dart';
import '../widgets/variable_tile.dart';

final selectedTrendRangeProvider =
    StateProvider.autoDispose.family<TrendRange, String>((ref, tag) => TrendRange.h2);
final editLayoutModeProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _acknowledgedAlertIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);
    final editLayoutMode = ref.watch(editLayoutModeProvider);
    final layoutOrders = ref.watch(layoutOrderControllerProvider);
    final currentPayload = dashboardAsync.asData?.value.payload;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const _AtalayaBrand(),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Helpers',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
            icon: dashboardAsync.asData?.value.isRefreshing == true
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _HelpersDrawer(
        well: currentPayload?.well,
        job: currentPayload?.job,
      ),
      bottomNavigationBar: _PredictorAlertBar(dashboardAsync: dashboardAsync),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DashboardErrorState(
          message: error.toString(),
          onRetry: () => ref.read(dashboardControllerProvider.notifier).retryNow(),
        ),
        data: (viewState) {
          final payload = viewState.payload;
          final baseVariables = _normalizeTo12Slots(payload.variables);
          final layoutOrder = _resolveLayoutOrder(layoutOrders, payload.well, payload.job);
          final variables = _applyLayoutOrder(baseVariables, layoutOrder);
          final activeDragVariable = _findSpecialVariable(
            variables: variables,
            includesAny: const <String>['active drag', 'activedrag', 'drag'],
          );
          final tensionVariable = _findSpecialVariable(
            variables: variables,
            includesAny: const <String>['tension', 'hook load', 'hookload'],
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 700;
              final crossAxisCount = editLayoutMode ? 1 : (constraints.maxWidth < 1280 ? 2 : 3);
              final canReorder = editLayoutMode && crossAxisCount == 1;
              final visibleAlerts = payload.alerts
                  .where((alert) => !_acknowledgedAlertIds.contains(alert.id))
                  .toList(growable: false);

              return RefreshIndicator(
            color: ProPalette.accent,
            onRefresh: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
                child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: _HeaderCard(viewState: viewState),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'LIVE VARIABLES (tap for trend)',
                            style: TextStyle(
                              color: ProPalette.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (editLayoutMode)
                          Text(
                            canReorder ? 'Modo editar (drag activo)' : 'Modo editar (usa ancho móvil)',
                            style: const TextStyle(
                              color: ProPalette.warn,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                if (canReorder)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverToBoxAdapter(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: variables.length,
                        onReorder: (oldIndex, newIndex) async {
                          final mutable = List<WellVariable>.from(variables);
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = mutable.removeAt(oldIndex);
                          mutable.insert(newIndex, item);
                          final slotOrder = mutable.map((it) => it.slot).toList(growable: false);
                          await ref.read(layoutOrderControllerProvider.notifier).setOrder(
                                well: payload.well,
                                job: payload.job,
                                slotOrder: slotOrder,
                              );
                        },
                        itemBuilder: (context, index) {
                          final variable = variables[index];
                          return Padding(
                            key: ValueKey<int>(variable.slot),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Stack(
                              children: <Widget>[
                                VariableTile(
                                  variable: variable,
                                  well: payload.well,
                                  job: payload.job,
                                  unitPreferences: unitPrefs,
                                  health: _variableHealth(variable, payload),
                                  sparklinePoints: viewState.variableHistoryByTag[variable.tag] ?? const <double>[],
                                  kpSeverity: _kpSeverityForVariable(variable, payload.alerts),
                                  onTap: () {},
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: ProPalette.bg.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.drag_indicator_rounded, size: 16, color: ProPalette.muted),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final variable = variables[index];
                          return VariableTile(
                            variable: variable,
                            well: payload.well,
                            job: payload.job,
                            unitPreferences: unitPrefs,
                            health: _variableHealth(variable, payload),
                            sparklinePoints: viewState.variableHistoryByTag[variable.tag] ?? const <double>[],
                            kpSeverity: _kpSeverityForVariable(variable, payload.alerts),
                            onTap: () => _openTrendBottomSheet(
                              context: context,
                              ref: ref,
                              payload: payload,
                              variable: variable,
                            ),
                          );
                        },
                        childCount: variables.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isCompact ? 2.2 : 1.15,
                      ),
                    ),
                  ),
                if (activeDragVariable != null || tensionVariable != null) ...<Widget>[
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'ACTIVE DRAG & TENSION',
                        style: TextStyle(
                          color: ProPalette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: ProPalette.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ProPalette.stroke),
                        ),
                        child: ExpansionTile(
                          title: const Text(
                            'Mostrar gráficas especiales',
                            style: TextStyle(color: ProPalette.text, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Active Drag / Tension',
                            style: TextStyle(color: ProPalette.muted, fontSize: 11),
                          ),
                          collapsedIconColor: ProPalette.muted,
                          iconColor: ProPalette.accent,
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: <Widget>[
                            if (activeDragVariable != null)
                              _SpecialTrendCard(
                                title: 'Active Drag',
                                variable: activeDragVariable,
                                points: viewState.variableHistoryByTag[activeDragVariable.tag] ?? const <double>[],
                              ),
                            if (activeDragVariable != null && tensionVariable != null) const SizedBox(height: 10),
                            if (tensionVariable != null)
                              _SpecialTrendCard(
                                title: 'Tension',
                                variable: tensionVariable,
                                points: viewState.variableHistoryByTag[tensionVariable.tag] ?? const <double>[],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'ALERTS & COMMENTS',
                      style: TextStyle(
                        color: ProPalette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  sliver: SliverToBoxAdapter(
                    child: visibleAlerts.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                            decoration: BoxDecoration(
                              color: ProPalette.panel,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: ProPalette.stroke),
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.check_circle_outline, color: ProPalette.ok, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Sin alertas recientes.',
                                  style: TextStyle(
                                    color: ProPalette.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ProPalette.panel,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: ProPalette.stroke),
                            ),
                            child: Column(
                              children: visibleAlerts
                                  .map(
                                    (alert) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Dismissible(
                                        key: ValueKey<String>('alert-${alert.id}'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          decoration: BoxDecoration(
                                            color: ProPalette.ok.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: const Icon(Icons.done_all_rounded, color: ProPalette.ok),
                                        ),
                                        onDismissed: (_) => setState(() {
                                          _acknowledgedAlertIds.add(alert.id);
                                        }),
                                        child: AlertCard(
                                          alert: alert,
                                          isNew: viewState.newAlertIds.contains(alert.id),
                                          onTap: () => _openAlertBottomSheet(
                                            context: context,
                                            alert: alert,
                                          ),
                                          onAttachmentTap: alert.attachmentsCount > 0
                                              ? () => _openAttachmentPreviewModal(
                                                    context: context,
                                                    alert: alert,
                                                  )
                                              : null,
                                          onAcknowledgeTap: () => setState(() {
                                            _acknowledgedAlertIds.add(alert.id);
                                          }),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                  ),
                ),
              ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  AlertSeverity? _kpSeverityForVariable(WellVariable variable, List<AtalayaAlert> alerts) {
    final tag = variable.tag.trim().toLowerCase();
    final label = variable.label.trim().toLowerCase();
    if (tag.isEmpty && label.isEmpty) {
      return null;
    }

    AlertSeverity? match;
    for (final alert in alerts) {
      final description = alert.description.toLowerCase();
      if ((tag.isNotEmpty && description.contains(tag)) ||
          (label.isNotEmpty && description.contains(label))) {
        if (match == null || alert.severity.rank > match.rank) {
          match = alert.severity;
        }
      }
    }
    return match;
  }

  VariableHealth _variableHealth(WellVariable variable, DashboardPayload payload) {
    if (!variable.configured || variable.sampleAt == null) {
      return VariableHealth.critical;
    }

    final age = DateTime.now().toUtc().difference(variable.sampleAt!.toUtc()).inSeconds;
    if (age <= payload.staleThresholdSeconds) {
      return VariableHealth.normal;
    }
    if (age <= payload.staleThresholdSeconds * 2) {
      return VariableHealth.warning;
    }
    return VariableHealth.critical;
  }

  List<WellVariable> _normalizeTo12Slots(List<WellVariable> variables) {
    final bySlot = <int, WellVariable>{
      for (final variable in variables) variable.slot: variable,
    };
    return List<WellVariable>.generate(
      12,
      (index) => bySlot[index + 1] ?? WellVariable.empty(index + 1),
      growable: false,
    );
  }

  List<int> _resolveLayoutOrder(Map<String, List<int>> store, String well, String job) {
    final key = 'layout_order::${well.trim().toUpperCase()}::${job.trim().toUpperCase()}';
    final raw = store[key];
    if (raw == null || raw.isEmpty) {
      return List<int>.generate(12, (index) => index + 1, growable: false);
    }
    final orderedUnique = raw.toSet().where((slot) => slot >= 1 && slot <= 12).toList(growable: false);
    final missing = <int>[
      for (var i = 1; i <= 12; i++)
        if (!orderedUnique.contains(i)) i,
    ];
    return <int>[...orderedUnique, ...missing];
  }

  List<WellVariable> _applyLayoutOrder(List<WellVariable> variables, List<int> slotOrder) {
    final bySlot = <int, WellVariable>{for (final variable in variables) variable.slot: variable};
    return slotOrder.map((slot) => bySlot[slot] ?? WellVariable.empty(slot)).toList(growable: false);
  }

  WellVariable? _findSpecialVariable({
    required List<WellVariable> variables,
    required List<String> includesAny,
  }) {
    for (final variable in variables) {
      final text = '${variable.label} ${variable.tag}'.toLowerCase();
      final match = includesAny.any((needle) => text.contains(needle));
      if (match && variable.configured) {
        return variable;
      }
    }
    return null;
  }

  Future<void> _openTrendBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required DashboardPayload payload,
    required WellVariable variable,
  }) async {
    if (!variable.configured || variable.tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta variable no está configurada.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrendBottomSheet(
        payload: payload,
        variable: variable,
      ),
    );
  }

  Future<void> _openAlertBottomSheet({
    required BuildContext context,
    required AtalayaAlert alert,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlertDetailBottomSheet(alert: alert),
    );
  }

  Future<void> _openAttachmentPreviewModal({
    required BuildContext context,
    required AtalayaAlert alert,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: ProPalette.card,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 520,
          height: 620,
          child: _AttachmentPreviewPanel(alert: alert),
        ),
      ),
    );
  }
}

class _SpecialTrendCard extends StatelessWidget {
  const _SpecialTrendCard({
    required this.title,
    required this.variable,
    required this.points,
  });

  final String title;
  final WellVariable variable;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final hasData = points.length >= 3;
    final lastValue = points.isNotEmpty ? points.last : variable.value;
    final unitText = variable.rawUnit.isEmpty ? '' : variable.rawUnit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProPalette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$title • ${variable.label}',
            style: const TextStyle(
              color: ProPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${UnitConverter.formatNumber(lastValue)} $unitText',
            style: const TextStyle(
              color: ProPalette.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: hasData
                ? _SparklineMini(points: points)
                : const Center(
                    child: Text(
                      'Sin historial suficiente',
                      style: TextStyle(color: ProPalette.muted, fontSize: 11),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SparklineMini extends StatelessWidget {
  const _SparklineMini({required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), (points[i] - min) / span),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: points.length > 1 ? (points.length - 1).toDouble() : 1,
        minY: 0,
        maxY: 1,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ProPalette.accent,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: ProPalette.accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtalayaBrand extends StatelessWidget {
  const _AtalayaBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Atalaya Mobile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PredictorAlertBar extends StatefulWidget {
  const _PredictorAlertBar({required this.dashboardAsync});

  final AsyncValue<DashboardViewState> dashboardAsync;

  @override
  State<_PredictorAlertBar> createState() => _PredictorAlertBarState();
}

class _PredictorAlertBarState extends State<_PredictorAlertBar> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _PredictorAlertBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latestIncoming = widget.dashboardAsync.asData?.value.latestIncomingAlert;
    if (latestIncoming != null && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = widget.dashboardAsync.asData?.value;
    final latestIncoming = viewState?.latestIncomingAlert;
    final alerts = viewState?.payload.alerts ?? const <AtalayaAlert>[];

    final message = latestIncoming?.description ?? (alerts.isEmpty ? 'Sin alertas recientes' : alerts.first.description);
    final severity = latestIncoming?.severity ?? (alerts.isEmpty ? AlertSeverity.ok : alerts.first.severity);

    final borderColor = switch (severity) {
      AlertSeverity.critical => ProPalette.danger,
      AlertSeverity.attention => ProPalette.warn,
      AlertSeverity.ok => ProPalette.ok,
    };

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: _expanded ? 12 : 10),
          decoration: BoxDecoration(
            color: ProPalette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.85)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.notifications_active_outlined, color: borderColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alerts.isEmpty ? 'Sin alertas recientes' : 'Alertas del Predictor',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_more : Icons.expand_less, color: ProPalette.muted),
                ],
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: ProPalette.text, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (severity != AlertSeverity.ok) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    severity == AlertSeverity.critical
                        ? 'Recomendación: reducir carga de operación y validar parámetros críticos.'
                        : 'Recomendación: revisar tendencia y ajustar gradualmente parámetros de control.',
                    style: const TextStyle(color: ProPalette.muted, fontSize: 11),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpersDrawer extends ConsumerWidget {
  const _HelpersDrawer({this.well, this.job});

  final String? well;
  final String? job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertSettings = ref.watch(alertSettingsControllerProvider);
    final editMode = ref.watch(editLayoutModeProvider);

    return Drawer(
      backgroundColor: ProPalette.card,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          children: <Widget>[
            const Text(
              'Helpers & Settings',
              style: TextStyle(
                color: ProPalette.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: alertSettings.enabled,
              onChanged: (value) => ref.read(alertSettingsControllerProvider.notifier).setEnabled(value),
              title: const Text('Notificaciones activas'),
              subtitle: const Text('Habilita monitoreo de KP en pantalla.'),
            ),
            SwitchListTile.adaptive(
              value: alertSettings.visual,
              onChanged: (value) => ref.read(alertSettingsControllerProvider.notifier).setVisual(value),
              title: const Text('Indicadores visuales'),
              subtitle: const Text('Muestra resaltado para alertas nuevas.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Severidad mínima'),
              subtitle: Text(alertSettings.minSeverity.compactLabel),
              trailing: DropdownButton<AlertSeverity>(
                value: alertSettings.minSeverity,
                items: AlertSeverity.values
                    .map(
                      (value) => DropdownMenuItem<AlertSeverity>(
                        value: value,
                        child: Text(value.compactLabel),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => ref.read(alertSettingsControllerProvider.notifier).setMinSeverity(value),
              ),
            ),
            const Divider(color: ProPalette.stroke),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restablecer unidades'),
              subtitle: const Text('Elimina conversiones guardadas por variable.'),
              trailing: IconButton(
                onPressed: () => ref.read(unitPreferencesControllerProvider.notifier).clearAll(),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ),
            const Divider(color: ProPalette.stroke),
            SwitchListTile.adaptive(
              value: editMode,
              onChanged: (value) => ref.read(editLayoutModeProvider.notifier).state = value,
              title: const Text('Modo editar layout'),
              subtitle: const Text('Permite arrastrar tarjetas en vista móvil (1 columna).'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restablecer layout'),
              subtitle: Text(
                (well == null || job == null)
                    ? 'Disponible cuando haya contexto de pozo/job.'
                    : 'Vuelve al orden por defecto para $well / $job.',
              ),
              trailing: IconButton(
                onPressed: (well == null || job == null)
                    ? null
                    : () async {
                        await ref.read(layoutOrderControllerProvider.notifier).resetOrder(
                              well: well!,
                              job: job!,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Layout restablecido.')),
                          );
                        }
                      },
                icon: const Icon(Icons.view_stream_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.viewState});

  final DashboardViewState viewState;

  @override
  Widget build(BuildContext context) {
    final latest = viewState.payload.latestSampleAt;
    final lastDataText = latest == null
        ? '---'
        : '${DateFormat('yyyy-MM-dd HH:mm:ss').format(latest.toLocal())} • '
            '${DateTime.now().toUtc().difference(latest.toUtc()).inSeconds}s';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProPalette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.oil_barrel_rounded,
                  color: ProPalette.bg,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _HeaderInfoRow(label: 'Well:', value: viewState.payload.well, accent: true),
                    _HeaderInfoRow(label: 'Job:', value: viewState.payload.job),
                    _HeaderInfoRow(label: 'Last:', value: lastDataText, small: true),
                  ],
                ),
              ),
              StatusChip(status: viewState.connectionStatus),
            ],
          ),
          if (viewState.errorMessage != null && viewState.errorMessage!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ProPalette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ProPalette.stroke),
              ),
              child: Text(
                viewState.errorMessage!,
                style: const TextStyle(
                  color: ProPalette.warn,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({
    required this.label,
    required this.value,
    this.small = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool small;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: ProPalette.muted,
              fontSize: small ? 10 : 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? ProPalette.accent : ProPalette.text,
                fontSize: small ? 10 : 12,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBottomSheet extends ConsumerWidget {
  const _TrendBottomSheet({required this.payload, required this.variable});

  final DashboardPayload payload;
  final WellVariable variable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedTrendRangeProvider(variable.tag));
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);
    final displayUnit = UnitConverter.resolveDisplayUnit(
      slotIndex: variable.slot - 1,
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      well: payload.well,
      job: payload.job,
      preferences: unitPrefs,
    );
    final unitOptions = UnitConverter.getUnitOptions(variable.rawUnit);
    final preferenceKey = UnitConverter.makePrefKey(
      slotIndex: variable.slot - 1,
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      well: payload.well,
      job: payload.job,
    );
    final selectedPreference = (unitPrefs[preferenceKey] ?? 'RAW').toUpperCase() == 'RAW'
        ? 'RAW'
        : UnitConverter.normUnit(unitPrefs[preferenceKey]);

    final trendRequest = TrendRequest(
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      displayUnit: displayUnit,
      range: selectedRange,
    );
    final trendAsync = ref.watch(trendSeriesProvider(trendRequest));

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: ProPalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProPalette.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TREND ${selectedRange.label}',
                          style: const TextStyle(
                            color: ProPalette.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${variable.label}${displayUnit.isEmpty ? '' : ' ($displayUnit)'} • Tag: ${variable.tag}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text(
                    'Units:',
                    style: TextStyle(
                      color: ProPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: unitOptions.contains(selectedPreference)
                          ? selectedPreference
                          : (unitOptions.isEmpty ? null : unitOptions.first),
                      items: unitOptions
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit == 'RAW' ? 'RAW (${variable.rawUnit})' : unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: unitOptions.isEmpty
                          ? null
                          : (selection) {
                              if (selection == null) return;
                              ref.read(unitPreferencesControllerProvider.notifier).setPreference(preferenceKey, selection);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TrendRangeSelector(
                selected: selectedRange,
                onChanged: (range) => ref.read(selectedTrendRangeProvider(variable.tag).notifier).state = range,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 14,
                runSpacing: 8,
                children: <Widget>[
                  _LegendItem(color: ProPalette.accent, label: 'Signal'),
                  _LegendItem(color: ProPalette.warn, label: 'Avg (last 30m)'),
                  _LegendItem(color: ProPalette.ok, label: 'Last'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: trendAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Error cargando tendencia: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ProPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  data: (series) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TrendChartWidget(series: series),
                        const SizedBox(height: 12),
                        TrendStatsWrap(series: series),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertDetailBottomSheet extends ConsumerWidget {
  const _AlertDetailBottomSheet({required this.alert});

  final AtalayaAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(alertAttachmentsProvider(alert.id));
    final severity = _severityVisual(alert.severity);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: ProPalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProPalette.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'ALERT',
                      style: TextStyle(
                        color: ProPalette.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Text(
                    'Time:',
                    style: TextStyle(color: ProPalette.muted, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.createdAt.toLocal()),
                      style: const TextStyle(color: ProPalette.muted, fontSize: 11),
                    ),
                  ),
                  _SeverityChip(label: severity.label, color: severity.color),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  color: ProPalette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProPalette.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ProPalette.stroke),
                ),
                child: SelectableText(
                  alert.description,
                  style: const TextStyle(color: ProPalette.text, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Attachments (${alert.attachmentsCount})',
                style: const TextStyle(
                  color: ProPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ProPalette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ProPalette.stroke),
                  ),
                  child: attachmentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(
                        'Error cargando adjuntos: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ProPalette.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    data: (attachments) {
                      if (attachments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay adjuntos disponibles para esta alerta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ProPalette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _AttachmentTile(attachment: attachments[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
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

class _AttachmentPreviewPanel extends ConsumerWidget {
  const _AttachmentPreviewPanel({required this.alert});

  final AtalayaAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(alertAttachmentsProvider(alert.id));

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Adjuntos • KP ${alert.id}',
                  style: const TextStyle(
                    color: ProPalette.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: attachmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error cargando adjuntos: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ProPalette.warn),
                ),
              ),
              data: (attachments) {
                if (attachments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay adjuntos para previsualizar.',
                      style: TextStyle(color: ProPalette.muted),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    final isImage = attachment.mimeType.toLowerCase().contains('image') ||
                        attachment.url.toLowerCase().contains('.png') ||
                        attachment.url.toLowerCase().contains('.jpg') ||
                        attachment.url.toLowerCase().contains('.jpeg');

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ProPalette.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ProPalette.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            attachment.name,
                            style: const TextStyle(
                              color: ProPalette.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isImage && attachment.url.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 3,
                                child: Image.network(
                                  attachment.url,
                                  height: 170,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 120,
                                    child: Center(child: Text('No fue posible renderizar imagen.')),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Archivo no previsualizable. Usa Descargar URL.',
                              style: TextStyle(color: ProPalette.muted, fontSize: 11),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  attachment.mimeType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: ProPalette.muted, fontSize: 11),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: attachment.url.isEmpty
                                    ? null
                                    : () async {
                                        await Clipboard.setData(ClipboardData(text: attachment.url));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('URL copiada al portapapeles.')),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Descargar URL'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final sizeText = _formatBytes(attachment.sizeBytes);
    final createdText = attachment.createdAt == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(attachment.createdAt!.toLocal());
    final meta = <String>[
      if (attachment.mimeType.trim().isNotEmpty) attachment.mimeType,
      if (sizeText.isNotEmpty) sizeText,
      if (createdText.isNotEmpty) createdText,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ProPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ProPalette.muted, fontSize: 10),
            ),
          ],
          if (attachment.url.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            SelectableText(
              attachment.url,
              maxLines: 2,
              style: TextStyle(
                color: attachment.hasSecureUrl ? ProPalette.accent : ProPalette.warn,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int? value) {
    if (value == null || value <= 0) return '';
    if (value >= 1024 * 1024) return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '$value B';
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.label, required this.color});

  final String label;
  final Color color;

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
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: ProPalette.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.wifi_off_rounded, color: ProPalette.danger, size: 44),
            const SizedBox(height: 12),
            const Text(
              'No fue posible cargar el dashboard.',
              style: TextStyle(
                color: ProPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ProPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
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
