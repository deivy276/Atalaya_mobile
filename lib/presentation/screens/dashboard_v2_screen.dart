import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/layout_tokens.dart';
import '../../core/theme/atalaya_theme.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/alert.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/trend_point.dart';
import '../../data/models/well_variable.dart';
import '../models/dashboard_ui_model.dart';
import '../providers/dashboard_controller.dart';
import '../providers/trend_controller.dart';
import '../providers/unit_preferences_controller.dart';
import '../providers/operational_alarm_events_provider.dart';
import '../providers/app_settings_controller.dart';
import '../providers/alert_settings_controller.dart';
import 'predictor_charts_screen.dart';
import '../services/atalaya_alarm_feedback.dart';
import '../widgets/v2/brand_top_bar.dart';
import '../widgets/v2/kpi_tile_v2.dart';
import '../widgets/v2/predictor_alerts_dock.dart';
import '../widgets/v2/settings_panel.dart';
import '../widgets/v2/well_overview_card.dart';

class DashboardV2Screen extends ConsumerStatefulWidget {
  const DashboardV2Screen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  ConsumerState<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends ConsumerState<DashboardV2Screen> {
  static const String _densityPrefKey = 'dashboard_v2_density_mode';
  static const String _layoutPrefKey = 'dashboard_v2_tile_layout_mode';

  String? _selectedVariableTag;
  _DensityMode _densityMode = _DensityMode.comfortable;
  _TileLayoutMode _tileLayoutMode = _TileLayoutMode.grid;
  final Set<String> _activeOperationalAlarmRuleIds = <String>{};

  bool get _isDefaultLayoutConfig =>
      _densityMode == _DensityMode.comfortable && _tileLayoutMode == _TileLayoutMode.grid;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreferences();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<OperationalAlarmEvent>>(
      operationalAlarmEventsProvider,
      (previous, next) => _handleOperationalAlarmEvents(next),
    );

    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);
    final appSettings = ref.watch(appSettingsControllerProvider);

    return Scaffold(
      extendBody: true,
      appBar: BrandTopBar(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
        onOpenSettings: _openSettingsPanel,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: context.atalayaColors.pageGradient,
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
              final uiModel = _buildUiModel(viewState, _effectiveUnitPreferences(viewState, unitPrefs, appSettings.unitSystem));
              final width = MediaQuery.of(context).size.width;
              final isWideLayout = width >= 1100;

              return isWideLayout
                  ? _buildWideLayout(viewState, uiModel, payload.job)
                  : _buildMobileLayout(context, viewState, uiModel, payload.job);
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
    String job,
  ) {
    return CustomScrollView(
      slivers: <Widget>[
        _buildOverviewSliver(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          viewState: viewState,
          uiModel: uiModel,
          job: job,
        ),
        _buildTilesGrid(viewState, uiModel),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: PredictorAlertsDock(
              alerts: viewState.payload.alerts,
              onOpenAlert: _openAlertDetail,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    DashboardViewState viewState,
    DashboardUiModel uiModel,
    String job,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Row(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  _buildOverviewSliver(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                    viewState: viewState,
                    uiModel: uiModel,
                    job: job,
                  ),
                  _buildTilesGrid(viewState, uiModel),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
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

  Widget _buildOverviewSliver({
    required EdgeInsets padding,
    required DashboardViewState viewState,
    required DashboardUiModel uiModel,
    required String job,
  }) {
    final selectedTile = _findSelectedTile(uiModel);

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildListDelegate.fixed(<Widget>[
          WellOverviewCard(
            well: uiModel.activeWell,
            job: job,
            isActive: viewState.connectionStatus == ConnectionStatus.connected,
          ),
          if (selectedTile != null) ...<Widget>[
            const SizedBox(height: 12),
            _SelectedVariableBanner(tile: selectedTile),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildTilesGrid(
    DashboardViewState viewState,
    DashboardUiModel uiModel,
  ) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width >= 1100
        ? const EdgeInsets.fromLTRB(20, 0, 12, 0)
        : const EdgeInsets.symmetric(horizontal: 16);
    final itemCount = uiModel.tiles.length + 1;

    Widget buildTileItem(BuildContext context, int index) {
      if (index == uiModel.tiles.length) {
        return _SpecialPredictorTile(
          selected: false,
          onTap: _openSpecialPredictorScreen,
        );
      }

      final model = uiModel.tiles[index];
      final variable = viewState.payload.variables.firstWhere(
        (WellVariable item) => item.tag == model.id,
        orElse: () => WellVariable.empty(index + 1),
      );

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
          _openVariableTrend(variable: variable, tile: model);
        },
      );
    }

    if (_tileLayoutMode == _TileLayoutMode.list) {
      return SliverPadding(
        padding: horizontalPadding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == itemCount - 1 ? 0 : 12,
              ),
              child: SizedBox(
                height: 170,
                child: buildTileItem(context, index),
              ),
            ),
            childCount: itemCount,
          ),
        ),
      );
    }

    final crossAxisCount = _resolveCrossAxisCount(width);

    return SliverPadding(
      padding: horizontalPadding,
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          buildTileItem,
          childCount: itemCount,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: _densityMode == _DensityMode.compact ? 1.28 : 1.12,
        ),
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
      if (tile.id == _selectedVariableTag) {
        return tile;
      }
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

  Future<void> _resetLayoutPreferences() async {
    setState(() {
      _densityMode = _DensityMode.comfortable;
      _tileLayoutMode = _TileLayoutMode.grid;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_densityPrefKey);
    await prefs.remove(_layoutPrefKey);
  }

  Future<void> _confirmAndResetLayout({bool closeControlsSheet = false}) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restablecer layout'),
          content: const Text('Â¿Quieres volver a la configuraciÃ³n visual predeterminada?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restablecer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _resetLayoutPreferences();
    await HapticFeedback.lightImpact();

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Layout restablecido a valores predeterminados'),
        duration: Duration(seconds: 2),
      ),
    );

    if (closeControlsSheet) {
      navigator.pop();
    }
  }

  Map<String, String> _effectiveUnitPreferences(
    DashboardViewState state,
    Map<String, String> currentPreferences,
    AtalayaUnitSystem unitSystem,
  ) {
    if (unitSystem == AtalayaUnitSystem.field) {
      return currentPreferences;
    }

    final payload = state.payload;
    final next = Map<String, String>.from(currentPreferences);

    for (final variable in payload.variables) {
      final targetUnit = _targetUnitForSystem(unitSystem, variable.rawUnit);
      if (targetUnit == null || targetUnit.trim().isEmpty) {
        continue;
      }

      final key = UnitConverter.makePrefKey(
        slotIndex: variable.slot - 1,
        tag: variable.tag,
        rawUnit: variable.rawUnit,
        well: payload.well,
        job: payload.job,
      );
      next[key] = targetUnit;
    }

    return next;
  }

  String? _targetUnitForSystem(AtalayaUnitSystem unitSystem, String rawUnit) {
    final dimension = UnitConverter.unitDimension(rawUnit);
    if (dimension.isEmpty) {
      return null;
    }

    switch (unitSystem) {
      case AtalayaUnitSystem.field:
        return null;
      case AtalayaUnitSystem.english:
        return switch (dimension) {
          'pressure' => 'psi',
          'length' => 'ft',
          'velocity' => 'ft/min',
          'flow' => 'gpm',
          'force' => 'lbs',
          'torque' => 'ft-lbf',
          'temperature' => 'Â°F',
          _ => null,
        };
      case AtalayaUnitSystem.metric:
        return switch (dimension) {
          'pressure' => 'bar',
          'length' => 'm',
          'velocity' => 'm/min',
          'flow' => 'lpm',
          'force' => 'kgf',
          'torque' => 'NÂ·m',
          'temperature' => 'Â°C',
          _ => null,
        };
    }
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

      final converted = variable.value == null
          ? null
          : UnitConverter.convertValue(variable.value!, variable.rawUnit, displayUnit);
      final rawSparkline = state.variableHistoryByTag[variable.tag] ?? const <double>[];
      final sparkline = rawSparkline
          .map((value) => UnitConverter.convertValue(value, variable.rawUnit, displayUnit))
          .toList(growable: false);
      final delta = sparkline.length >= 2
          ? ((sparkline.last - sparkline.first) / (sparkline.first == 0 ? 1 : sparkline.first)) * 100
          : 0.0;
      final deltaPrefix = delta >= 0 ? 'â†—' : 'â†˜';
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
      appTitle: 'OperaciÃ³n en tiempo real',
      activeWell: payload.well,
      wellStatus: state.connectionStatus == ConnectionStatus.connected ? 'En lÃ­nea' : 'Datos desactualizados',
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

  void _handleOperationalAlarmEvents(List<OperationalAlarmEvent> events) {
    final currentActiveIds = events.map((event) => event.ruleId).toSet();
    OperationalAlarmEvent? newEvent;

    for (final event in events) {
      if (!_activeOperationalAlarmRuleIds.contains(event.ruleId)) {
        newEvent = event;
        break;
      }
    }

    _activeOperationalAlarmRuleIds
      ..clear()
      ..addAll(currentActiveIds);

    if (newEvent == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _presentOperationalAlarm(newEvent!);
      }
    });
  }

  Future<void> _presentOperationalAlarm(OperationalAlarmEvent event) async {
    final settings = ref.read(alertSettingsControllerProvider);
    if (!settings.enabled) {
      return;
    }

    await AtalayaAlarmFeedback.presentOperationalAlarm(
      context,
      event,
      visual: event.rule.visual || settings.visual,
      sound: event.rule.sound || settings.sound,
      vibrate: settings.vibrate || event.rule.sound,
    );
  }
  Future<void> _openAlertDetail(AtalayaAlert alert) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.atalayaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
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
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w700,
                      ),
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

  Future<void> _openSettingsPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AtalayaSettingsPanel(
          onLogout: widget.onLogout,
          onOpenLayoutControls: _openLayoutControls,
        );
      },
    );
  }
  Future<void> _openLayoutControls() async {
    final dashboardState = ref.read(dashboardControllerProvider).asData?.value;
    final currentTileCount = (dashboardState?.payload.variables.take(6).length ?? 0) + 1;
    final currentStatus = dashboardState == null
        ? 'Sin datos'
        : (dashboardState.connectionStatus == ConnectionStatus.connected ? 'En lÃ­nea' : 'Desactualizado');
    final currentStatusColor = dashboardState == null
        ? LayoutTokens.textMuted
        : (dashboardState.connectionStatus == ConnectionStatus.connected
            ? LayoutTokens.accentGreen
            : LayoutTokens.accentOrange);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.atalayaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                    const SizedBox(height: 4),
                    Text(
                      'Actual: ${_densityMode == _DensityMode.compact ? 'Compacto' : 'CÃ³modo'} Â· '
                      '${_tileLayoutMode == _TileLayoutMode.grid ? 'Grilla' : 'Lista'}',
                      style: const TextStyle(color: LayoutTokens.textMuted),
                    ),
                    const SizedBox(height: 2),
                    _ControlsStatusSummary(
                      currentStatus: currentStatus,
                      currentTileCount: currentTileCount,
                      currentStatusColor: currentStatusColor,
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
                          label: Text('CÃ³modo'),
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
                    const SizedBox(height: 14),
                    const Divider(color: LayoutTokens.dividerSubtle),
                    const SizedBox(height: 8),
                    const Text(
                      'Acciones',
                      style: TextStyle(color: LayoutTokens.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: _isDefaultLayoutConfig
                            ? 'No hay cambios para restablecer'
                            : 'Restablecer a configuraciÃ³n predeterminada',
                        child: TextButton.icon(
                          onPressed: _isDefaultLayoutConfig
                              ? null
                              : () async {
                                  await _confirmAndResetLayout(closeControlsSheet: true);
                                },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Restablecer layout'),
                        ),
                      ),
                    ),
                    if (_isDefaultLayoutConfig)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Ya estÃ¡s usando la configuraciÃ³n por defecto.',
                          style: TextStyle(
                            color: LayoutTokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
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

  Future<void> _openVariableTrend({
    required WellVariable variable,
    required VariableTileUiModel tile,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: _VariableTrendSheet(
              variable: variable,
              tile: tile,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSpecialPredictorScreen() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return const FractionallySizedBox(
          heightFactor: 0.94,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: PredictorChartsPanel(
              embedded: true,
            ),
          ),
        );
      },
    );
  }
}

class _VariableTrendSheet extends ConsumerStatefulWidget {
  const _VariableTrendSheet({
    required this.variable,
    required this.tile,
  });

  final WellVariable variable;
  final VariableTileUiModel tile;

  @override
  ConsumerState<_VariableTrendSheet> createState() => _VariableTrendSheetState();
}

class _VariableTrendSheetState extends ConsumerState<_VariableTrendSheet> {
  TrendRange _selectedRange = TrendRange.m30;

  static const List<TrendRange> _ranges = <TrendRange>[
    TrendRange.m30,
    TrendRange.h2,
    TrendRange.h6,
    TrendRange.h8,
    TrendRange.h12,
    TrendRange.h24,
  ];

  @override
  Widget build(BuildContext context) {
    final variable = widget.variable;
    final tile = widget.tile;
    final accentColor = tile.accentColor;
    final request = TrendRequest(
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      displayUnit: tile.unitText,
      range: _selectedRange,
    );
    final trendAsync = ref.watch(trendSeriesProvider(request));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[LayoutTokens.bgPrimary, LayoutTokens.bgSecondary],
        ),
      ),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tile.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LayoutTokens.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          variable.tag.isEmpty ? 'Variable' : 'Tag: ${variable.tag}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LayoutTokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded, color: LayoutTokens.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              trendAsync.when(
                loading: () => _VariableValueSummary(
                  valueText: tile.valueText,
                  unitText: tile.unitText,
                  deltaText: tile.deltaText,
                  accentColor: accentColor,
                ),
                error: (_, __) => _VariableValueSummary(
                  valueText: tile.valueText,
                  unitText: tile.unitText,
                  deltaText: tile.deltaText,
                  accentColor: accentColor,
                ),
                data: (trend) => _VariableValueSummary(
                  valueText: UnitConverter.formatNumber(trend.yLast),
                  unitText: trend.displayUnit,
                  deltaText: _deltaTextForPoints(trend.points),
                  accentColor: _deltaForPoints(trend.points) < 0
                      ? LayoutTokens.accentOrange
                      : LayoutTokens.accentGreen,
                ),
              ),
              const SizedBox(height: 12),
              _VariableRangeSelector(
                ranges: _ranges,
                selected: _selectedRange,
                onSelected: (range) => setState(() => _selectedRange = range),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'GrÃ¡fica de variable',
                      style: TextStyle(
                        color: LayoutTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  trendAsync.maybeWhen(
                    data: (trend) => Text(
                      trend.rangeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LayoutTokens.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: LayoutTokens.surfaceCard.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: LayoutTokens.dividerSubtle),
                  ),
                  child: trendAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _VariableChartError(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(trendSeriesProvider(request)),
                    ),
                    data: (trend) => trend.points.length >= 2
                        ? _VariableTimeLineChart(
                            points: trend.points,
                            unit: trend.displayUnit,
                            color: accentColor,
                            range: _selectedRange,
                          )
                        : const _NoVariableChartData(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              trendAsync.when(
                loading: () => Text(
                  'Cargando ${_selectedRange.displayLabel} Â· solo lectura',
                  style: const TextStyle(
                    color: LayoutTokens.textMuted,
                    fontSize: 12,
                  ),
                ),
                error: (_, __) => Text(
                  'No fue posible cargar ${_selectedRange.displayLabel}.',
                  style: const TextStyle(
                    color: LayoutTokens.textMuted,
                    fontSize: 12,
                  ),
                ),
                data: (trend) => Text(
                  trend.points.length >= 2
                      ? '${trend.points.length} muestras Â· ${_selectedRange.displayLabel} Â· eje X en tiempo Â· solo lectura'
                      : 'AÃºn no hay suficientes muestras para ${_selectedRange.displayLabel}.',
                  style: const TextStyle(
                    color: LayoutTokens.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _deltaForPoints(List<TrendPoint> points) {
    if (points.length < 2) {
      return 0;
    }
    final first = points.first.value;
    final last = points.last.value;
    if (first == 0) {
      return 0;
    }
    return ((last - first) / first) * 100;
  }

  String _deltaTextForPoints(List<TrendPoint> points) {
    final delta = _deltaForPoints(points);
    final arrow = delta >= 0 ? 'â†—' : 'â†˜';
    final sign = delta >= 0 ? '+' : '';
    return '$arrow $sign${delta.toStringAsFixed(1)}%';
  }
}

class _VariableRangeSelector extends StatelessWidget {
  const _VariableRangeSelector({
    required this.ranges,
    required this.selected,
    required this.onSelected,
  });

  final List<TrendRange> ranges;
  final TrendRange selected;
  final ValueChanged<TrendRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ranges.map((range) {
        final isSelected = selected == range;
        return ChoiceChip(
          label: Text(range.displayLabel),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: LayoutTokens.accentBlue.withValues(alpha: 0.20),
          backgroundColor: LayoutTokens.surfaceCard,
          side: BorderSide(
            color: isSelected
                ? LayoutTokens.accentBlue.withValues(alpha: 0.72)
                : LayoutTokens.dividerSubtle,
          ),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : LayoutTokens.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          onSelected: (_) => onSelected(range),
        );
      }).toList(growable: false),
    );
  }
}

class _VariableValueSummary extends StatelessWidget {
  const _VariableValueSummary({
    required this.valueText,
    required this.unitText,
    required this.deltaText,
    required this.accentColor,
  });

  final String valueText;
  final String unitText;
  final String deltaText;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: valueText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: unitText.isEmpty ? '' : ' $unitText',
                    style: const TextStyle(
                      color: LayoutTokens.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            deltaText,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariableTimeLineChart extends StatelessWidget {
  const _VariableTimeLineChart({
    required this.points,
    required this.unit,
    required this.color,
    required this.range,
  });

  final List<TrendPoint> points;
  final String unit;
  final Color color;
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final ordered = List<TrendPoint>.from(points)
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final values = ordered.map((point) => point.value).toList(growable: false);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs();
    final padding = span < 0.01 ? 1.0 : span * 0.18;
    final spots = ordered
        .map(
          (point) => FlSpot(
            point.timestamp.toUtc().millisecondsSinceEpoch / 1000,
            point.value,
          ),
        )
        .toList(growable: false);
    final minX = spots.first.x;
    final maxX = spots.last.x;
    final xSpan = math.max(1, maxX - minX);
    final xInterval = math.max(60, xSpan / 4).toDouble();

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minValue - padding,
        maxY: maxValue + padding,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0x334A6D96),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => const FlLine(
            color: Color(0x1F4A6D96),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Tiempo',
                style: TextStyle(
                  color: LayoutTokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: xInterval,
              getTitlesWidget: (value, meta) => Text(
                _formatAxisTime(value),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LayoutTokens.textMuted,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                unit.isEmpty ? 'Valor' : unit,
                style: const TextStyle(
                  color: LayoutTokens.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => Text(
                UnitConverter.formatNumber(value),
                style: const TextStyle(
                  color: LayoutTokens.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xEE0A162A),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final value = UnitConverter.formatNumber(spot.y);
                final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  (spot.x * 1000).round(),
                  isUtc: true,
                ).toLocal();
                final time = DateFormat('dd/MM HH:mm').format(timestamp);
                final formattedValue = unit.isEmpty ? value : '$value $unit';
                return LineTooltipItem(
                  '$formattedValue\n$time',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                );
              }).toList(growable: false);
            },
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.24,
            color: color,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAxisTime(double epochSeconds) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      (epochSeconds * 1000).round(),
      isUtc: true,
    ).toLocal();

    if (range == TrendRange.h24) {
      return DateFormat('dd/MM\nHH:mm').format(timestamp);
    }

    return DateFormat('HH:mm').format(timestamp);
  }
}

class _NoVariableChartData extends StatelessWidget {
  const _NoVariableChartData();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.show_chart_rounded,
              color: LayoutTokens.textMuted,
              size: 34,
            ),
            SizedBox(height: 10),
            Text(
              'Sin datos suficientes para este rango.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LayoutTokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Prueba otro rango de tiempo o espera nuevas muestras.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LayoutTokens.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariableChartError extends StatelessWidget {
  const _VariableChartError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, color: LayoutTokens.textMuted, size: 34),
            const SizedBox(height: 10),
            const Text(
              'No se pudo cargar el histÃ³rico.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LayoutTokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LayoutTokens.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
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

class _SpecialPredictorTile extends StatelessWidget {
  const _SpecialPredictorTile({
    required this.onTap,
    this.selected = false,
  });

  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? LayoutTokens.accentBlue : Colors.white12;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(LayoutTokens.spacing12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF112336),
              Color(0xFF09233C),
              Color(0xFF0A1C2F),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: LayoutTokens.accentBlue.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: LayoutTokens.accentBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LayoutTokens.accentBlue.withValues(alpha: 0.38)),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    color: LayoutTokens.accentBlue,
                    size: 18,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: LayoutTokens.textSecondary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Special Predictor Screen',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LayoutTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hook Load Â· Torque Â· Pressure',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LayoutTokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                _MiniPredictorDot(color: LayoutTokens.accentGreen),
                const SizedBox(width: 5),
                _MiniPredictorDot(color: LayoutTokens.accentOrange),
                const SizedBox(width: 5),
                _MiniPredictorDot(color: LayoutTokens.accentRed),
                const Spacer(),
                const Text(
                  'Abrir',
                  style: TextStyle(
                    color: LayoutTokens.accentBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPredictorDot extends StatelessWidget {
  const _MiniPredictorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ControlsStatusSummary extends StatelessWidget {
  const _ControlsStatusSummary({
    required this.currentStatus,
    required this.currentTileCount,
    required this.currentStatusColor,
  });

  final String currentStatus;
  final int currentTileCount;
  final Color currentStatusColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado actual $currentStatus con $currentTileCount tiles visibles',
      child: Tooltip(
        message: 'Estado: $currentStatus | Tiles visibles: $currentTileCount',
        child: Row(
          children: <Widget>[
            Icon(
              Icons.circle,
              size: 10,
              color: currentStatusColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Estado: $currentStatus Â· Tiles: $currentTileCount',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LayoutTokens.textMuted),
              ),
            ),
          ],
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
    final colors = context.atalayaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.analytics_rounded, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tile.label}: ${tile.valueText} ${tile.unitText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            tile.deltaText,
            style: TextStyle(color: tile.accentColor, fontWeight: FontWeight.w800),
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
    final colors = context.atalayaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.insights_outlined, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No hay variables disponibles para esta operaciÃ³n.',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
enum _DensityMode { compact, comfortable }

enum _TileLayoutMode { grid, list }




