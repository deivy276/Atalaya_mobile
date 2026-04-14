import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/layout_tokens.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/well_variable.dart';
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
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: LayoutTokens.textPrimary))),
            data: (viewState) {
              final payload = viewState.payload;
              final variables = payload.variables.take(6).toList(growable: false);
              final crossAxisCount = _resolveCrossAxisCount(MediaQuery.of(context).size.width);

              return Stack(
                children: <Widget>[
                  CustomScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: WellOverviewCard(
                          well: payload.well,
                          job: payload.job,
                          isActive: viewState.connectionStatus == ConnectionStatus.connected,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final variable = variables[index];
                            final model = _mapVariable(variable, payload.well, payload.job, unitPrefs, viewState);
                            return KpiTileV2(
                              label: model.label,
                              value: model.valueText,
                              unit: model.unitText,
                              delta: model.deltaText,
                              sparkline: model.trendSeries,
                              selected: _selectedVariableTag == variable.tag,
                              accentColor: model.accentColor,
                              onTap: () {
                                setState(() => _selectedVariableTag = variable.tag);
                                _openVariableDetail(context, variable, payload.well, payload.job, unitPrefs);
                              },
                            );
                          },
                          childCount: variables.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.18,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PredictorAlertsDock(alerts: payload.alerts),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  int _resolveCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  _VariableTileUiModel _mapVariable(
    WellVariable variable,
    String well,
    String job,
    Map<String, String> unitPreferences,
    DashboardViewState state,
  ) {
    final displayUnit = UnitConverter.resolveDisplayUnit(
      slotIndex: variable.slot - 1,
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      well: well,
      job: job,
      preferences: unitPreferences,
    );

    final converted = variable.value == null ? null : UnitConverter.convertValue(variable.value!, variable.rawUnit, displayUnit);
    final sparkline = state.variableHistoryByTag[variable.tag] ?? const <double>[];
    final delta = sparkline.length >= 2 ? ((sparkline.last - sparkline.first) / (sparkline.first == 0 ? 1 : sparkline.first)) * 100 : 0.0;
    final deltaPrefix = delta >= 0 ? '↗' : '↘';

    return _VariableTileUiModel(
      id: variable.tag,
      label: variable.label,
      valueText: converted == null ? '---' : UnitConverter.formatNumber(converted),
      unitText: displayUnit,
      trendSeries: sparkline,
      deltaText: '$deltaPrefix ${delta.toStringAsFixed(1)}%',
      accentColor: delta >= 0 ? LayoutTokens.accentGreen : LayoutTokens.accentOrange,
    );
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
                    child: Container(width: 48, height: 4, decoration: BoxDecoration(color: LayoutTokens.textMuted, borderRadius: BorderRadius.circular(999))),
                  ),
                  const SizedBox(height: 12),
                  Text(variable.label, style: const TextStyle(color: LayoutTokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                  Text('Updated ${DateFormat('HH:mm').format(DateTime.now())}', style: const TextStyle(color: LayoutTokens.textSecondary)),
                  const SizedBox(height: 12),
                  TrendRangeSelector(
                    selected: selected,
                    onChanged: (range) => setModalState(() => selected = range),
                  ),
                  const SizedBox(height: 10),
                  trendAsync.when(
                    loading: () => const SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
                    error: (error, _) => SizedBox(height: 180, child: Center(child: Text('$error', style: const TextStyle(color: LayoutTokens.textSecondary)))),
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

class _VariableTileUiModel {
  const _VariableTileUiModel({
    required this.id,
    required this.label,
    required this.valueText,
    required this.unitText,
    required this.trendSeries,
    required this.deltaText,
    required this.accentColor,
  });

  final String id;
  final String label;
  final String valueText;
  final String unitText;
  final List<double> trendSeries;
  final String deltaText;
  final Color accentColor;
}
