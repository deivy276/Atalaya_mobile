import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/layout_tokens.dart';

const String _specialPredictorScreenTitle = 'Special Predictor Screen';

enum PredictorChartType {
  hookLoad('Hook Load', 'ton'),
  surfaceTorque('Surface Torque', 'ft-lbf'),
  pumpPressure('Pump Pressure', 'psi');

  const PredictorChartType(this.label, this.unit);

  final String label;
  final String unit;
}

class PredictorChartsScreen extends StatelessWidget {
  const PredictorChartsScreen({
    super.key,
    this.initialType = PredictorChartType.hookLoad,
    this.sourceLabel,
    this.sourceTag,
  });

  final PredictorChartType initialType;
  final String? sourceLabel;
  final String? sourceTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_specialPredictorScreenTitle),
      ),
      body: PredictorChartsPanel(
        initialType: initialType,
        sourceLabel: sourceLabel,
        sourceTag: sourceTag,
      ),
    );
  }
}

class PredictorChartsPanel extends StatefulWidget {
  const PredictorChartsPanel({
    super.key,
    this.embedded = false,
    this.initialType = PredictorChartType.hookLoad,
    this.sourceLabel,
    this.sourceTag,
  });

  final bool embedded;
  final PredictorChartType initialType;
  final String? sourceLabel;
  final String? sourceTag;

  @override
  State<PredictorChartsPanel> createState() => _PredictorChartsPanelState();
}

class _PredictorChartsPanelState extends State<PredictorChartsPanel> {
  late PredictorChartType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialType;
  }

  @override
  void didUpdateWidget(covariant PredictorChartsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialType != widget.initialType) {
      _selected = widget.initialType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartData = _buildMockChartData(_selected);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[LayoutTokens.bgPrimary, LayoutTokens.bgSecondary],
        ),
      ),
      child: SafeArea(
        top: !widget.embedded,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.embedded) ...<Widget>[
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
                    const Expanded(
                      child: Text(
                        _specialPredictorScreenTitle,
                        style: TextStyle(
                          color: LayoutTokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Cerrar',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: LayoutTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const Text(
                'Vista de solo lectura con mock data.',
                style: TextStyle(color: LayoutTokens.textMuted),
              ),
              if (widget.sourceLabel != null || widget.sourceTag != null) ...<Widget>[
                const SizedBox(height: 12),
                _PredictorContextCard(
                  sourceLabel: widget.sourceLabel,
                  sourceTag: widget.sourceTag,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const <Widget>[
                  _StatusBadge(
                    label: 'Solo lectura',
                    icon: Icons.lock_outline_rounded,
                  ),
                  _StatusBadge(
                    label: 'Mock data',
                    icon: Icons.science_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Variables',
                style: TextStyle(
                  color: LayoutTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PredictorChartType.values.map((type) {
                  final isSelected = _selected == type;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: const Color(0x443FA7FF),
                    backgroundColor: LayoutTokens.surfaceCard,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0x883FA7FF)
                          : LayoutTokens.dividerSubtle,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : LayoutTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selected = type),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: LayoutTokens.surfaceCard.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LayoutTokens.dividerSubtle),
                ),
                child: Text(
                  '${chartData.title} · Profundidad vs ${chartData.xAxisLabel}',
                  style: const TextStyle(
                    color: LayoutTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: LayoutTokens.surfaceCard.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LayoutTokens.dividerSubtle),
                  ),
                  child: LineChart(
                    LineChartData(
                      minX: chartData.minX,
                      maxX: chartData.maxX,
                      minY: chartData.minY,
                      maxY: chartData.maxY,
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval:
                            (chartData.maxY - chartData.minY) / 6,
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
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'MD Depth (m)',
                              style: TextStyle(
                                color: LayoutTokens.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1000,
                            reservedSize: 42,
                            getTitlesWidget: (value, _) => Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                color: LayoutTokens.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              chartData.xAxisLabel,
                              style: const TextStyle(
                                color: LayoutTokens.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: chartData.xTick,
                            reservedSize: 24,
                            getTitlesWidget: (value, _) => Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                color: LayoutTokens.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: <LineChartBarData>[
                        ...chartData.envelopes.map(
                          (line) => LineChartBarData(
                            spots: line,
                            isCurved: true,
                            color: const Color(0xFF2F73FF),
                            barWidth: 1.8,
                            dotData: const FlDotData(show: false),
                          ),
                        ),
                        LineChartBarData(
                          spots: chartData.warnLine,
                          isCurved: true,
                          color: LayoutTokens.accentOrange,
                          barWidth: 1.2,
                          dashArray: const <int>[4, 3],
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: chartData.criticalLine,
                          isCurved: true,
                          color: LayoutTokens.accentRed,
                          barWidth: 1.2,
                          dashArray: const <int>[6, 4],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: chartData.fieldDepths
                            .map(
                              (depth) => HorizontalLine(
                                y: depth,
                                color: LayoutTokens.accentRed.withValues(
                                  alpha: 0.60,
                                ),
                                strokeWidth: 0.8,
                                dashArray: const <int>[2, 3],
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Mock UI: ${chartData.envelopes.length} envelopes, '
                'límites Warn/Crit y puntos de campo.',
                style: const TextStyle(
                  color: LayoutTokens.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PredictorChartMockData _buildMockChartData(PredictorChartType type) {
    final seed = switch (type) {
      PredictorChartType.hookLoad => 1.0,
      PredictorChartType.surfaceTorque => 1.45,
      PredictorChartType.pumpPressure => 1.9,
    };

    final minX = switch (type) {
      PredictorChartType.hookLoad => 30.0,
      PredictorChartType.surfaceTorque => 50.0,
      PredictorChartType.pumpPressure => 900.0,
    };

    final maxX = switch (type) {
      PredictorChartType.hookLoad => 260.0,
      PredictorChartType.surfaceTorque => 350.0,
      PredictorChartType.pumpPressure => 3600.0,
    };

    final xTick = switch (type) {
      PredictorChartType.hookLoad => 50.0,
      PredictorChartType.surfaceTorque => 60.0,
      PredictorChartType.pumpPressure => 500.0,
    };

    const minY = 0.0;
    const maxY = 8200.0;
    const depths = <double>[
      0,
      800,
      1600,
      2400,
      3200,
      4200,
      5200,
      6200,
      7200,
      8000,
    ];

    List<FlSpot> envelope(double offset) {
      return List<FlSpot>.generate(depths.length, (int index) {
        final depth = depths[index];
        final normalized = depth / maxY;
        final x = minX +
            (maxX - minX) * (0.05 + normalized * (0.85 + offset * 0.01)) +
            math.sin((index + seed) * 0.6 + offset) *
                (maxX - minX) *
                0.015;

        return FlSpot(x.clamp(minX, maxX).toDouble(), depth);
      });
    }

    final envelopes = <List<FlSpot>>[
      envelope(0.0),
      envelope(2.0),
      envelope(4.0),
      envelope(6.0),
      envelope(8.0),
    ];

    final warnLine = envelopes[1]
        .map(
          (FlSpot spot) => FlSpot(
            (spot.x * 1.05).clamp(minX, maxX).toDouble(),
            spot.y,
          ),
        )
        .toList(growable: false);

    final criticalLine = envelopes[2]
        .map(
          (FlSpot spot) => FlSpot(
            (spot.x * 1.10).clamp(minX, maxX).toDouble(),
            spot.y,
          ),
        )
        .toList(growable: false);

    final fieldDepths = List<double>.generate(14, (int index) {
      final depth = 400 + index * 420.0 + math.sin(index * 0.9 + seed) * 170;
      return depth.clamp(0, maxY).toDouble();
    });

    return _PredictorChartMockData(
      title: type.label,
      xAxisLabel: '${type.label} (${type.unit})',
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      xTick: xTick,
      envelopes: envelopes,
      warnLine: warnLine,
      criticalLine: criticalLine,
      fieldDepths: fieldDepths,
    );
  }
}

class _PredictorContextCard extends StatelessWidget {
  const _PredictorContextCard({
    this.sourceLabel,
    this.sourceTag,
  });

  final String? sourceLabel;
  final String? sourceTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (sourceLabel != null)
            Text(
              sourceLabel!,
              style: const TextStyle(
                color: LayoutTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (sourceTag != null) ...<Widget>[
            if (sourceLabel != null) const SizedBox(height: 4),
            Text(
              'Tag: $sourceTag',
              style: const TextStyle(
                color: LayoutTokens.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: LayoutTokens.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: LayoutTokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictorChartMockData {
  const _PredictorChartMockData({
    required this.title,
    required this.xAxisLabel,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xTick,
    required this.envelopes,
    required this.warnLine,
    required this.criticalLine,
    required this.fieldDepths,
  });

  final String title;
  final String xAxisLabel;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double xTick;
  final List<List<FlSpot>> envelopes;
  final List<FlSpot> warnLine;
  final List<FlSpot> criticalLine;
  final List<double> fieldDepths;
}
