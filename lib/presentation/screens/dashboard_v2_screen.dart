import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/layout_tokens.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/alert.dart';
import '../../data/models/well_variable.dart';
import '../models/dashboard_ui_model.dart';
import '../providers/dashboard_controller.dart';
import '../providers/trend_controller.dart';
import '../providers/unit_preferences_controller.dart';
import '../widgets/trend_chart_widget.dart';
import '../widgets/v2/brand_top_bar.dart';
import '../widgets/v2/kpi_tile_v2.dart';
import '../widgets/v2/predictor_alerts_dock.dart';
import '../widgets/v2/well_overview_card.dart';

class DashboardV2Screen extends ConsumerStatefulWidget {
  const DashboardV2Screen({super.key});

  @override
  ConsumerState<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends ConsumerState<DashboardV2Screen> {
  String? _selectedVariableTag;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);

    return Scaffold(
      extendBody: true,
      appBar: BrandTopBar(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
        onOpenMenu: () {},
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[LayoutTokens.bgPrimary, LayoutTokens.bgSecondary],
          ),
        ),
        child: SafeArea(
          child: dashboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: LayoutTokens.textPrimary),
              ),
            ),
            data: (viewState) {
              final payload = viewState.payload;
              final uiModel = _buildUiModel(viewState, unitPrefs);
              final width = MediaQuery.of(context).size.width;
              final isWideLayout = width >= 1100;

              return isWideLayout
                  ? _buildWideLayout(context, viewState, uiModel, payload.well, payload.job, unitPrefs)
                  : _buildMobileLayout(context, viewState, uiModel, payload.well, payload.job, unitPrefs);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    DashboardViewState viewState,
    DashboardUiModel uiModel,
    String well,
    String job,
    Map<String, String> unitPrefs,
  ) {
    return Stack(
      children: <Widget>[
        CustomScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _DashboardHeading(
                title: uiModel.appTitle,
                status: uiModel.wellStatus,
                selectedVariableId: uiModel.selectedVariableId,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: WellOverviewCard(
                well: uiModel.activeWell,
                job: job,
                isActive: viewState.connectionStatus == ConnectionStatus.connected,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            _buildTilesGrid(viewState, uiModel, well, job, unitPrefs),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PredictorAlertsDock(alerts: viewState.payload.alerts),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    DashboardViewState viewState,
    DashboardUiModel uiModel,
    String well,
    String job,
    Map<String, String> unitPrefs,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _DashboardHeading(
                  title: uiModel.appTitle,
                  status: uiModel.wellStatus,
                  selectedVariableId: uiModel.selectedVariableId,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: WellOverviewCard(
                  well: uiModel.activeWell,
                  job: job,
                  isActive: viewState.connectionStatus == ConnectionStatus.connected,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildTilesGrid(viewState, uiModel, well, job, unitPrefs),
            ],
          ),
        ),
        SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 20, 20),
            child: PredictorAlertsDock(alerts: viewState.payload.alerts, embedded: true),
          ),
        ),
      ],
    );
  }

  SliverGrid _buildTilesGrid(
    DashboardViewState viewState,
    DashboardUiModel uiModel,
    String well,
    String job,
    Map<String, String> unitPrefs,
  ) {
    final crossAxisCount = _resolveCrossAxisCount(MediaQuery.of(context).size.width);

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final model = uiModel.tiles[index];
          final variable = viewState.payload.variables.firstWhere((item) => item.tag == model.id);
          return KpiTileV2(
            label: model.label,
            value: model.valueText,
            unit: model.unitText,
            delta: model.deltaText,
            sparkline: model.trendSeries,
            selected: model.isSelected,
            accentColor: model.accentColor,
            onTap: () {
              setState(() => _selectedVariableTag = model.id);
              _openVariableDetail(context, variable, well, job, unitPrefs);
            },
          );
        },
        childCount: uiModel.tiles.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
    );
  }

  int _resolveCrossAxisCount(double width) {
    if (width >= 1400) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  DashboardUiModel _buildUiModel(
    DashboardViewState state,
    Map<String, String> unitPreferences,
  ) {
    final payload = state.payload;
    final tiles = payload.variables.take(6).map((variable) {
      final displayUnit = UnitConverter.resolveDisplayUnit(
        slotIndex: variable.slot - 1,
        tag: variable.tag,
        rawUnit: variable.rawUnit,
        well: payload.well,
        job: payload.job,
        preferences: unitPreferences,
      );

      final converted =
          variable.value == null ? null : UnitConverter.convertValue(variable.value!, variable.rawUnit, displayUnit);
      final sparkline = state.variableHistoryByTag[variable.tag] ?? const <double>[];
      final delta = sparkline.length >= 2
          ? ((sparkline.last - sparkline.first) / (sparkline.first == 0 ? 1 : sparkline.first)) * 100
          : 0.0;
      final deltaPrefix = delta >= 0 ? '↗' : '↘';
      final status = _resolveTileStatus(state.connectionStatus, sparkline);

      return VariableTileUiModel(
        id: variable.tag,
        label: variable.label,
        valueText: converted == null ? '---' : UnitConverter.formatNumber(converted),
        unitText: displayUnit,
        trendSeries: sparkline,
        deltaText: '$deltaPrefix ${delta.toStringAsFixed(1)}%',
        deltaDirection: delta >= 0 ? TrendDirection.up : TrendDirection.down,
        visualStatus: status,
        accentColor: status == TileVisualStatus.warning ? LayoutTokens.accentOrange : LayoutTokens.accentGreen,
        isSelected: _selectedVariableTag == variable.tag,
        isTappable: true,
      );
    }).toList(growable: false);

    final alerts = payload.alerts.map(_mapAlert).toList(growable: false);

    return DashboardUiModel(
      appTitle: 'Operación en tiempo real',
      activeWell: payload.well,
      wellStatus: state.connectionStatus == ConnectionStatus.connected ? 'En línea' : 'Datos desactualizados',
      tiles: tiles,
      predictorAlerts: alerts,
      selectedVariableId: _selectedVariableTag,
    );
  }

  PredictorAlertUiModel _mapAlert(AtalayaAlert alert) {
    return PredictorAlertUiModel(
      id: alert.id,
      severity: switch (alert.severity) {
        AlertSeverity.critical => AlertUiSeverity.critical,
        AlertSeverity.attention => AlertUiSeverity.warning,
        AlertSeverity.ok => AlertUiSeverity.info,
      },
      source: 'Predictor',
      timestampText: DateFormat('HH:mm').format(alert.createdAt.toLocal()),
      title: alert.severity.compactLabel,
      body: alert.description,
    );
  }

  TileVisualStatus _resolveTileStatus(ConnectionStatus connectionStatus, List<double> sparkline) {
    if (connectionStatus != ConnectionStatus.connected) {
      return TileVisualStatus.stale;
    }
    if (sparkline.isEmpty) {
      return TileVisualStatus.loading;
    }
    if (sparkline.length >= 2) {
      final variance = (sparkline.last - sparkline.first).abs();
      if (variance > 25) {
        return TileVisualStatus.warning;
      }
    }
    return TileVisualStatus.normal;
  }

  Future<void> _openVariableDetail(
    BuildContext context,
    WellVariable variable,
    String well,
    String job,
    Map<String, String> unitPreferences,
  ) async {
    TrendRange selected = TrendRange.h2;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final trendAsync = ref.watch(trendControllerProvider(TrendRequest(
              tag: variable.tag,
              range: selected,
              well: well,
              job: job,
              displayUnitPreferences: unitPreferences,
            )));

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: LayoutTokens.textMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    variable.label,
                    style: const TextStyle(
                      color: LayoutTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Updated ${DateFormat('HH:mm').format(DateTime.now())}',
                    style: const TextStyle(color: LayoutTokens.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TrendRangeSelector(
                    selected: selected,
                    onChanged: (range) => setModalState(() => selected = range),
                  ),
                  const SizedBox(height: 10),
                  trendAsync.when(
                    loading: () => const SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
                    error: (error, _) => SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          '$error',
                          style: const TextStyle(color: LayoutTokens.textSecondary),
                        ),
                      ),
                    ),
                    data: (series) => Column(
                      children: <Widget>[
                        TrendChartWidget(series: series),
                        const SizedBox(height: 10),
                        _StatsRow(series: series),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({
    required this.title,
    required this.status,
    required this.selectedVariableId,
  });

  final String title;
  final String status;
  final String? selectedVariableId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: LayoutTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: const TextStyle(color: LayoutTokens.textSecondary),
              ),
            ],
          ),
        ),
        if (selectedVariableId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LayoutTokens.surfaceCard,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: LayoutTokens.dividerSubtle),
            ),
            child: Text(
              'Tag: $selectedVariableId',
              style: const TextStyle(
                color: LayoutTokens.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.series});

  final TrendSeriesState series;

  @override
  Widget build(BuildContext context) {
    final items = <String, String>{
      'Min': UnitConverter.formatNumber(series.yMin),
      'Avg': UnitConverter.formatNumber(series.yAvgAll),
      'Max': UnitConverter.formatNumber(series.yMax),
      'N': '${series.points.length}',
    };

    return Row(
      children: items.entries
          .map(
            (entry) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: LayoutTokens.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LayoutTokens.dividerSubtle),
                ),
                child: Column(
                  children: <Widget>[
                    Text(entry.key, style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(entry.value, style: const TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
