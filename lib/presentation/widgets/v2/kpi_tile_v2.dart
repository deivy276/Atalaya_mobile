import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

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
    final color = accentColor ?? LayoutTokens.accentGreen;
    final borderColor = selected ? LayoutTokens.accentOrange.withValues(alpha: 0.9) : Colors.white12;
    final shadowColor = selected ? LayoutTokens.accentOrange : color;
    final parsedDelta = _parseDeltaValue(delta);
    final deltaIsPositive = parsedDelta >= 0;
    final deltaArrowIcon = deltaIsPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final deltaColor = deltaIsPositive ? color : LayoutTokens.accentOrange;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(LayoutTokens.spacing12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF112336),
              selected ? const Color(0xFF0F2A44) : const Color(0xFF0B1C2D),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor.withValues(alpha: selected ? 0.16 : 0.10),
              blurRadius: selected ? 18 : 14,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8EEF7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: LayoutTokens.spacing8),
            RichText(
              text: TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: Color(0xFFAFBAC7),
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 34,
              child: sparkline.length < 2
                  ? const SizedBox.shrink()
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        minY: sparkline.reduce((a, b) => a < b ? a : b),
                        maxY: sparkline.reduce((a, b) => a > b ? a : b),
                        lineBarsData: <LineChartBarData>[
                          LineChartBarData(
                            isCurved: true,
                            dotData: const FlDotData(show: false),
                            barWidth: 2.0,
                            color: color,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  color.withValues(alpha: 0.16),
                                  color.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                            spots: List<FlSpot>.generate(sparkline.length, (i) => FlSpot(i.toDouble(), sparkline[i])),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: LayoutTokens.spacing6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Icon(deltaArrowIcon, size: 14, color: deltaColor),
                const SizedBox(width: 2),
                Text(
                  delta,
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    height: 0.9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _parseDeltaValue(String raw) {
    final normalized = raw.trim().replaceAll('%', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
}
