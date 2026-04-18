import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';


class KpiTileV2 extends StatelessWidget {
  const KpiTileV2({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.delta,
    required this.sparkline,
    required this.onTap,
    this.selected = false,
    this.accentColor,
  });

  final String label;
  final String value;
  final String unit;
  final String delta;
  final List<double> sparkline;
  final VoidCallback onTap;
  final bool selected;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final trendColor = accentColor ?? const Color(0xFF5FDE92);
    final deltaValue = _parseDeltaValue(delta);
    final deltaColor = deltaValue >= 0 ? trendColor : const Color(0xFFFFA65B);
    final borderColor = selected
        ? trendColor.withValues(alpha: 0.78)
        : const Color(0xFF1C3650);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF0B1A28),
                Color(0xFF0A2233),
                Color(0xFF0B2941),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? trendColor.withValues(alpha: 0.16)
                    : const Color(0xFF02111E).withValues(alpha: 0.28),
                blurRadius: selected ? 18 : 12,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDDE8F5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.12,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      text: value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        height: 0.96,
                        letterSpacing: -0.5,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: ' $unit',
                          style: const TextStyle(
                            color: Color(0xFFB6C3D2),
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: sparkline.length < 2
                      ? const SizedBox.shrink()
                      : _Sparkline(
                          values: sparkline,
                          color: trendColor,
                        ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatDelta(deltaValue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.08,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _parseDeltaValue(String raw) {
    final normalized = raw
        .replaceAll('↗', '')
        .replaceAll('↘', '')
        .replaceAll('%', '')
        .replaceAll('+', '')
        .replaceAll(',', '.')
        .trim();

    return double.tryParse(normalized) ?? 0;
  }

  String _formatDelta(double value) {
    final arrow = value >= 0 ? '↗' : '↘';
    final sign = value >= 0 ? '+' : '-';
    return '$arrow $sign${value.abs().toStringAsFixed(1)}%';
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final verticalPadding =
        (maxValue - minValue).abs() < 0.01 ? 1.0 : (maxValue - minValue) * 0.18;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: minValue - verticalPadding,
        maxY: maxValue + verticalPadding,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: List<FlSpot>.generate(
              values.length,
              (index) => FlSpot(index.toDouble(), values[index]),
            ),
            isCurved: true,
            curveSmoothness: 0.24,
            color: color,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  color.withValues(alpha: 0.18),
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
}
