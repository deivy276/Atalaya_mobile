import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../widgets/v2/layout_summary_chips.dart';
import '../widgets/v2/predictor_alerts_dock.dart';
import '../widgets/v2/well_overview_card.dart';

class DashboardV2Screen extends ConsumerStatefulWidget {
  const DashboardV2Screen({super.key});

  @override
  ConsumerState<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends ConsumerState<DashboardV2Screen> {
  static const String _densityPrefKey = 'dashboard_v2_density_mode';
  static const String _layoutPrefKey = 'dashboard_v2_tile_layout_mode';

  String? _selectedVariableTag;
  _DensityMode _densityMode = _DensityMode.comfortable;
  _TileLayoutMode _tileLayoutMode = _TileLayoutMode.grid;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);

    return Scaffold(
      extendBody: true,
      appBar: BrandTopBar(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
        onOpenMenu: _openLayoutControls,
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
    final selectedTile = _findSelectedTile(uiModel);

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
                densityMode: _densityMode,
                onDensityChanged: _setDensityMode,
                layoutMode: _tileLayoutMode,
                onLayoutChanged: _setTileLayoutMode,
                onOpenControls: () => _openLayoutControls(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 12),
                child: LayoutSummaryChips(
                  tileCount: uiModel.tiles.length,
                  densityLabel: _densityMode == _DensityMode.compact ? 'Compacto' : 'Cómodo',
                  layoutLabel: _tileLayoutMode == _TileLayoutMode.grid ? 'Grilla' : 'Lista',
                  onTapDensity: () => _openLayoutControls(),
                  onTapLayout: () => _openLayoutControls(),
                ),
              ),
            ),
            if (selectedTile != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SelectedVariableBanner(
                    tile: selectedTile,
                  ),
                ),
              ),
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
          child: PredictorAlertsDock(
            alerts: viewState.payload.alerts,
            onOpenAlert: _openAlertDetail,
          ),
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
    final selectedTile = _findSelectedTile(uiModel);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Row(
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
                      densityMode: _densityMode,
                      onDensityChanged: _setDensityMode,
                      layoutMode: _tileLayoutMode,
                      onLayoutChanged: _setTileLayoutMode,
                      onOpenControls: () => _openLayoutControls(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 12),
                      child: LayoutSummaryChips(
                        tileCount: uiModel.tiles.length,
                        densityLabel: _densityMode == _DensityMode.compact ? 'Compacto' : 'Cómodo',
                        layoutLabel: _tileLayoutMode == _TileLayoutMode.grid ? 'Grilla' : 'Lista',
                        onTapDensity: () => _openLayoutControls(),
                        onTapLayout: () => _openLayoutControls(),
                      ),
                    ),
                  ),
                  if (selectedTile != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SelectedVariableBanner(
                          tile: selectedTile,
                        ),
                      ),
                    ),
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
                child: PredictorAlertsDock(
                  alerts: viewState.payload.alerts,
                  embedded: true,
                  onOpenAlert: _openAlertDetail,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTilesGrid(
    DashboardViewState viewState,
    DashboardUiModel uiModel,
    String well,
    String job,
    Map<String, String> unitPrefs,
  ) {
    if (uiModel.tiles.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyKpiState(),
      );
    }

    final itemBuilder = (BuildContext context, int index) {
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
    };

    if (_tileLayoutMode == _TileLayoutMode.list) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(bottom: index == uiModel.tiles.length - 1 ? 0 : 12),
            child: SizedBox(
              height: 170,
              child: itemBuilder(context, index),
            ),
          ),
          childCount: uiModel.tiles.length,
        ),
      );
    }

    final crossAxisCount = _resolveCrossAxisCount(MediaQuery.of(context).size.width);

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: uiModel.tiles.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: _densityMode == _DensityMode.compact ? 1.28 : 1.12,
      ),
    );
  }

  int _resolveCrossAxisCount(double width) {
    if (width >= 1400) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  VariableTileUiModel? _findSelectedTile(DashboardUiModel uiModel) {
    if (_selectedVariableTag == null) return null;
    for (final tile in uiModel.tiles) {
      if (tile.id == _selectedVariableTag) return tile;
    }
    return null;
  }

  Future<void> _loadLayoutPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final densityRaw = prefs.getString(_densityPrefKey);
    final layoutRaw = prefs.getString(_layoutPrefKey);
    setState(() {
      _densityMode = _DensityMode.values.firstWhere(
        (value) => value.name == densityRaw,
        orElse: () => _DensityMode.comfortable,
      );
      _tileLayoutMode = _TileLayoutMode.values.firstWhere(
        (value) => value.name == layoutRaw,
        orElse: () => _TileLayoutMode.grid,
      );
    });
  }

  void _setDensityMode(_DensityMode mode) {
    setState(() => _densityMode = mode);
    _persistDensityMode(mode);
  }

  void _setTileLayoutMode(_TileLayoutMode mode) {
    setState(() => _tileLayoutMode = mode);
    _persistTileLayoutMode(mode);
  }

  Future<void> _persistDensityMode(_DensityMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_densityPrefKey, mode.name);
  }

  Future<void> _persistTileLayoutMode(_TileLayoutMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutPrefKey, mode.name);
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


  Future<void> _openAlertDetail(AtalayaAlert alert) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final severityColor = switch (alert.severity) {
          AlertSeverity.critical => LayoutTokens.accentRed,
          AlertSeverity.attention => LayoutTokens.accentOrange,
          AlertSeverity.ok => LayoutTokens.accentBlue,
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
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
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: severityColor),
                    ),
                    child: Text(
                      alert.severity.compactLabel,
                      style: TextStyle(color: severityColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM HH:mm').format(alert.createdAt.toLocal()),
                    style: const TextStyle(color: LayoutTokens.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.description,
                style: const TextStyle(
                  color: LayoutTokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Adjuntos: ${alert.attachmentsCount}',
                style: const TextStyle(color: LayoutTokens.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLayoutControls() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Opciones de layout',
                      style: TextStyle(
                        color: LayoutTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Densidad',
                      style: TextStyle(color: LayoutTokens.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_DensityMode>(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(LayoutTokens.textSecondary),
                        backgroundColor: WidgetStateProperty.all(LayoutTokens.surfaceCard),
                      ),
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<_DensityMode>>[
                        ButtonSegment<_DensityMode>(
                          value: _DensityMode.compact,
                          label: Text('Compacto'),
                        ),
                        ButtonSegment<_DensityMode>(
                          value: _DensityMode.comfortable,
                          label: Text('Cómodo'),
                        ),
                      ],
                      selected: <_DensityMode>{_densityMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          _setDensityMode(selection.first);
                          setSheetState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vista de tiles',
                      style: TextStyle(color: LayoutTokens.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_TileLayoutMode>(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(LayoutTokens.textSecondary),
                        backgroundColor: WidgetStateProperty.all(LayoutTokens.surfaceCard),
                      ),
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<_TileLayoutMode>>[
                        ButtonSegment<_TileLayoutMode>(
                          value: _TileLayoutMode.grid,
                          icon: Icon(Icons.grid_view_rounded, size: 18),
                        ),
                        ButtonSegment<_TileLayoutMode>(
                          value: _TileLayoutMode.list,
                          icon: Icon(Icons.view_agenda_rounded, size: 18),
                        ),
                      ],
                      selected: <_TileLayoutMode>{_tileLayoutMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          _setTileLayoutMode(selection.first);
                          setSheetState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    required this.densityMode,
    required this.onDensityChanged,
    required this.layoutMode,
    required this.onLayoutChanged,
    required this.onOpenControls,
  });

  final String title;
  final String status;
  final String? selectedVariableId;
  final _DensityMode densityMode;
  final ValueChanged<_DensityMode> onDensityChanged;
  final _TileLayoutMode layoutMode;
  final ValueChanged<_TileLayoutMode> onLayoutChanged;
  final VoidCallback onOpenControls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showInlineControls = constraints.maxWidth >= 760;

        return Column(
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
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
                if (!showInlineControls)
                  _CompactControlsHint(onTap: onOpenControls)
                else ...<Widget>[
                  SegmentedButton<_DensityMode>(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(LayoutTokens.textSecondary),
                      backgroundColor: WidgetStateProperty.all(LayoutTokens.surfaceCard),
                    ),
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<_DensityMode>>[
                      ButtonSegment<_DensityMode>(
                        value: _DensityMode.compact,
                        label: Text('Compacto'),
                      ),
                      ButtonSegment<_DensityMode>(
                        value: _DensityMode.comfortable,
                        label: Text('Cómodo'),
                      ),
                    ],
                    selected: <_DensityMode>{densityMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        onDensityChanged(selection.first);
                      }
                    },
                  ),
                  SegmentedButton<_TileLayoutMode>(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(LayoutTokens.textSecondary),
                      backgroundColor: WidgetStateProperty.all(LayoutTokens.surfaceCard),
                    ),
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<_TileLayoutMode>>[
                      ButtonSegment<_TileLayoutMode>(
                        value: _TileLayoutMode.grid,
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                      ),
                      ButtonSegment<_TileLayoutMode>(
                        value: _TileLayoutMode.list,
                        icon: Icon(Icons.view_agenda_rounded, size: 18),
                      ),
                    ],
                    selected: <_TileLayoutMode>{layoutMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        onLayoutChanged(selection.first);
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CompactControlsHint extends StatelessWidget {
  const _CompactControlsHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: LayoutTokens.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: LayoutTokens.dividerSubtle),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.tune_rounded, size: 14, color: LayoutTokens.textSecondary),
              SizedBox(width: 6),
              Text(
                'Más opciones en menú',
                style: TextStyle(
                  color: LayoutTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedVariableBanner extends StatelessWidget {
  const _SelectedVariableBanner({required this.tile});

  final VariableTileUiModel tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.analytics_rounded, color: LayoutTokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tile.label}: ${tile.valueText} ${tile.unitText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LayoutTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            tile.deltaText,
            style: TextStyle(color: tile.accentColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyKpiState extends StatelessWidget {
  const _EmptyKpiState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.insights_outlined, color: LayoutTokens.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No hay variables disponibles para esta operación.',
              style: TextStyle(color: LayoutTokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DensityMode { compact, comfortable }

enum _TileLayoutMode { grid, list }

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
