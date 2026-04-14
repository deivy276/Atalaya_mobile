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
    final borderColor = selected ? LayoutTokens.accentOrange : color.withValues(alpha: 0.75);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(LayoutTokens.spacing12),
        decoration: BoxDecoration(
          color: selected ? LayoutTokens.surfaceCardSelected : LayoutTokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: LayoutTokens.textSecondary, fontSize: 13)),
            const SizedBox(height: LayoutTokens.spacing8),
            RichText(
              text: TextSpan(
                text: value,
                style: const TextStyle(color: LayoutTokens.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
                children: <InlineSpan>[
                  TextSpan(text: ' $unit', style: const TextStyle(color: LayoutTokens.textSecondary, fontSize: 18, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
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
                            barWidth: 1.6,
                            color: color,
                            spots: List<FlSpot>.generate(sparkline.length, (i) => FlSpot(i.toDouble(), sparkline[i])),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: LayoutTokens.spacing4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(delta, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
