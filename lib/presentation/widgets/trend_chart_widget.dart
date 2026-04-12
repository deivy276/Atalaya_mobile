import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/pro_palette.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/trend_point.dart';
import '../providers/trend_controller.dart';

class TrendRangeSelector extends StatelessWidget {
  const TrendRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TrendRange selected;
  final ValueChanged<TrendRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TrendRange.values
          .map(
            (range) => ChoiceChip(
              label: Text(range.label),
              selected: range == selected,
              onSelected: (_) => onChanged(range),
              labelStyle: TextStyle(
                color: range == selected ? Colors.black : ProPalette.text,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: ProPalette.accent,
              backgroundColor: ProPalette.chipBg,
              side: const BorderSide(color: ProPalette.stroke),
            ),
          )
          .toList(growable: false),
    );
  }
}

class TrendChartWidget extends StatelessWidget {
  const TrendChartWidget({
    super.key,
    required this.series,
  });

  final TrendSeriesState series;

  @override
  Widget build(BuildContext context) {
    if (!series.hasEnoughData) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: ProPalette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ProPalette.stroke),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'No hay suficientes datos para graficar',
                style: TextStyle(
                  color: ProPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Revisa señal, ingestión o tag.',
                style: TextStyle(
                  color: ProPalette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var index = 0; index < series.points.length; index++) {
      spots.add(FlSpot(index.toDouble(), series.points[index].value));
    }

    return Container(
      height: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProPalette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: series.points.length > 1 ? (series.points.length - 1).toDouble() : 1.0,
          minY: series.yViewMin,
          maxY: series.yViewMax,
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: ProPalette.stroke),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: series.yStep,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0x3322304A),
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  final label = series.bottomLabels[index];
                  if (label == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: ProPalette.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                series.displayUnit,
                style: const TextStyle(
                  color: ProPalette.muted,
                  fontSize: 10,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  final show = series.yTicks.any((tick) => (tick - value).abs() < 0.0001);
                  if (!show) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _formatYAxis(value, series.yStep),
                    style: const TextStyle(
                      color: ProPalette.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: <HorizontalLine>[
              HorizontalLine(
                y: series.yAvg30,
                color: ProPalette.warn,
                strokeWidth: 1.6,
              ),
              HorizontalLine(
                y: series.yLast,
                color: ProPalette.ok,
                strokeWidth: 1.6,
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => ProPalette.card.withOpacity(0.92),
              tooltipBorderRadius: BorderRadius.circular(8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final index = touchedSpot.x.round().clamp(0, series.points.length - 1).toInt();
                  final TrendPoint point = series.points[index];
                  final timestamp = DateFormat('HH:mm').format(point.timestamp.toLocal());
                  final value = UnitConverter.formatNumber(point.value);
                  final unit = series.displayUnit.isEmpty ? '' : ' ${series.displayUnit}';
                  return LineTooltipItem(
                    '$value$unit\n$timestamp',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
              color: ProPalette.accent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class TrendStatsWrap extends StatelessWidget {
  const TrendStatsWrap({
    super.key,
    required this.series,
  });

  final TrendSeriesState series;

  @override
  Widget build(BuildContext context) {
    final unit = series.displayUnit.isEmpty ? '' : ' ${series.displayUnit}';
    final chips = <String>[
      'Range: ${series.rangeText}',
      'N=${series.points.length}',
      'Min=${UnitConverter.formatNumber(series.yMin)}$unit',
      'Avg30m=${UnitConverter.formatNumber(series.yAvg30)}$unit',
      'Avg=${UnitConverter.formatNumber(series.yAvgAll)}$unit',
      'Max=${UnitConverter.formatNumber(series.yMax)}$unit',
      'Last=${UnitConverter.formatNumber(series.yLast)}$unit',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ProPalette.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ProPalette.stroke),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: ProPalette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

String _formatYAxis(double value, double step) {
  final absStep = step.abs();
  if (value.abs() >= 1000) {
    return value.toStringAsFixed(0);
  }
  if (absStep >= 1) {
    return value.toStringAsFixed(0);
  }
  if (absStep >= 0.1) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}
