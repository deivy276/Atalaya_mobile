import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/layout_tokens.dart';

class PredictorChartsScreen extends StatefulWidget {
  const PredictorChartsScreen({super.key});

  @override
  State<PredictorChartsScreen> createState() => _PredictorChartsScreenState();
}

enum _PredictorChartType {
  hookLoad('Hook Load', 'ton'),
  surfaceTorque('Surface Torque', 'ft-lbf'),
  pumpPressure('Pump Pressure', 'psi');

  const _PredictorChartType(this.label, this.unit);
  final String label;
  final String unit;
}

class _PredictorChartsScreenState extends State<PredictorChartsScreen> {
  _PredictorChartType _selected = _PredictorChartType.hookLoad;

  @override
  Widget build(BuildContext context) {
    final chartData = _buildMockChartData(_selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predictor Charts'),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Vista de solo lectura (mock)',
                  style: TextStyle(color: LayoutTokens.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _PredictorChartType.values.map((type) {
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: _selected == type,
                      showCheckmark: false,
                      selectedColor: const Color(0x443FA7FF),
                      backgroundColor: LayoutTokens.surfaceCard,
                      side: BorderSide(
                        color: _selected == type ? const Color(0x883FA7FF) : LayoutTokens.dividerSubtle,
                      ),
                      labelStyle: TextStyle(
                        color: _selected == type ? Colors.white : LayoutTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _selected = type),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: LayoutTokens.surfaceCard.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LayoutTokens.dividerSubtle),
                  ),
                  child: Text(
                    '${chartData.title} · Profundidad vs ${chartData.xAxisLabel}',
                    style: const TextStyle(color: LayoutTokens.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 6),
                    decoration: BoxDecoration(
                      color: LayoutTokens.surfaceCard.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
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
                          horizontalInterval: (chartData.maxY - chartData.minY) / 6,
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
                          leftTitles: AxisTitles(
                            axisNameWidget: const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text('MD Depth (m)', style: TextStyle(color: LayoutTokens.textMuted, fontSize: 11)),
                            ),
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1000,
                              reservedSize: 40,
                              getTitlesWidget: (value, _) => Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                chartData.xAxisLabel,
                                style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
                              ),
                            ),
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: chartData.xTick,
                              reservedSize: 22,
                              getTitlesWidget: (value, _) => Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 10),
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
                                  y: depth.dy,
                                  color: LayoutTokens.accentRed.withValues(alpha: 0.6),
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
                const SizedBox(height: 8),
                Text(
                  'Mock UI: ${chartData.envelopes.length} envelopes, límites Warn/Crit y puntos de campo.',
                  style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _PredictorChartMockData _buildMockChartData(_PredictorChartType type) {
    final seed = switch (type) {
      _PredictorChartType.hookLoad => 1.0,
      _PredictorChartType.surfaceTorque => 1.45,
      _PredictorChartType.pumpPressure => 1.9,
    };
    final unit = type.unit;
    final minX = switch (type) {
      _PredictorChartType.hookLoad => 30.0,
      _PredictorChartType.surfaceTorque => 50.0,
      _PredictorChartType.pumpPressure => 900.0,
    };
    final maxX = switch (type) {
      _PredictorChartType.hookLoad => 260.0,
      _PredictorChartType.surfaceTorque => 350.0,
      _PredictorChartType.pumpPressure => 3600.0,
    };
    final xTick = switch (type) {
      _PredictorChartType.hookLoad => 50.0,
      _PredictorChartType.surfaceTorque => 60.0,
      _PredictorChartType.pumpPressure => 500.0,
    };
    final minY = 0.0;
    final maxY = 8200.0;
    final depths = <double>[0, 800, 1600, 2400, 3200, 4200, 5200, 6200, 7200, 8000];

    List<FlSpot> envelope(double offset) {
      return List<FlSpot>.generate(depths.length, (i) {
        final depth = depths[i];
        final normalized = depth / maxY;
        final x = minX +
            (maxX - minX) * (0.05 + normalized * (0.85 + offset * 0.01)) +
            math.sin((i + seed) * 0.6 + offset) * (maxX - minX) * 0.015;
        return FlSpot(x.clamp(minX, maxX), depth);
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
        .map((spot) => FlSpot((spot.x * 1.05).clamp(minX, maxX), spot.y))
        .toList(growable: false);
    final criticalLine = envelopes[2]
        .map((spot) => FlSpot((spot.x * 1.1).clamp(minX, maxX), spot.y))
        .toList(growable: false);

    final fieldDepths = List<Offset>.generate(14, (index) {
      final depth = 400 + index * 420.0 + math.sin(index * 0.9 + seed) * 170;
      return Offset(0, depth.clamp(0, maxY));
    });

    return _PredictorChartMockData(
      title: type.label,
      xAxisLabel: '${type.label} ($unit)',
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
  final List<Offset> fieldDepths;
}
