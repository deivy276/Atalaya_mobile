import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/layout_tokens.dart';
import '../providers/api_client_provider.dart';

const String _predictorScreenTitle = 'Special Predictor Screen';

const List<Color> _seriesPalette = <Color>[
  Color(0xFF2F73FF),
  Color(0xFF7C4DFF),
  Color(0xFFFF8A3D),
  Color(0xFF1E88FF),
  Color(0xFF9A63FF),
  Color(0xFFFF6F40),
  Color(0xFF00B8D4),
  Color(0xFF4AD66D),
];

enum PredictorChartType {
  hookLoad('Hook Load', 'ton', 'hook_load'),
  surfaceTorque('Surface Torque', 'ft-lbf', 'surface_torque'),
  pumpPressure('Pump Pressure', 'psi', 'pump_pressure');

  const PredictorChartType(this.label, this.unit, this.apiValue);

  final String label;
  final String unit;
  final String apiValue;
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
        title: const Text(_predictorScreenTitle),
      ),
      body: PredictorChartsPanel(
        initialType: initialType,
        sourceLabel: sourceLabel,
        sourceTag: sourceTag,
      ),
    );
  }
}

class PredictorChartsPanel extends ConsumerStatefulWidget {
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
  ConsumerState<PredictorChartsPanel> createState() => _PredictorChartsPanelState();
}

class _PredictorChartsPanelState extends ConsumerState<PredictorChartsPanel> {
  late PredictorChartType _selected;
  Future<_SpecialPredictorChartData>? _chartFuture;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialType;
    _chartFuture = _loadChart(_selected);
  }

  @override
  void didUpdateWidget(covariant PredictorChartsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialType != widget.initialType) {
      _selected = widget.initialType;
      _chartFuture = _loadChart(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        _predictorScreenTitle,
                        style: TextStyle(
                          color: LayoutTokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _reloadSelected(),
                      tooltip: 'Actualizar',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: LayoutTokens.textSecondary,
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
                'Active Drag & Tension · Solo lectura',
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
                  _StatusBadge(label: 'Solo lectura', icon: Icons.lock_outline_rounded),
                  _StatusBadge(label: 'API Predictor', icon: Icons.hub_outlined),
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
                      color: isSelected ? const Color(0x883FA7FF) : LayoutTokens.dividerSubtle,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : LayoutTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => _selectType(type),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<_SpecialPredictorChartData>(
                  future: _chartFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final chartData = snapshot.data ?? _buildFallbackChartData(_selected);
                    return _SpecialPredictorChart(data: chartData);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectType(PredictorChartType type) {
    if (_selected == type) return;
    setState(() {
      _selected = type;
      _chartFuture = _loadChart(type);
    });
  }

  void _reloadSelected() {
    setState(() => _chartFuture = _loadChart(_selected));
  }

  Future<_SpecialPredictorChartData> _loadChart(PredictorChartType type) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<dynamic>(
        '/api/v1/predictor',
        queryParameters: <String, dynamic>{'type': type.apiValue},
      );

      final payload = _asMap(response.data);
      if (payload == null) {
        return _buildFallbackChartData(
          type,
          note: 'Respuesta no JSON. No se dibujan curvas sintéticas.',
        );
      }

      return _parseChartPayload(type, payload);
    } catch (error) {
      return _buildFallbackChartData(
        type,
        note: 'API predictor no disponible. No se dibujan curvas sintéticas.',
      );
    }
  }

  _SpecialPredictorChartData _parseChartPayload(
    PredictorChartType type,
    Map<String, dynamic> payload,
  ) {
    final data = _asMap(payload['data']) ?? payload;
    final series = <_SpecialPredictorSeries>[];

    int colorIndex = 0;
    void addSeries(String name, List<FlSpot> points, {bool dashed = false, Color? color}) {
      if (points.isEmpty) return;
      series.add(
        _SpecialPredictorSeries(
          name: _compactSeriesName(name),
          points: points,
          color: color ?? _seriesPalette[colorIndex++ % _seriesPalette.length],
          dashed: dashed,
          width: dashed ? 1.4 : 2.0,
        ),
      );
    }

    final shouldRenderCurves = _shouldRenderAuthoritativeCurves(data, payload);
    if (shouldRenderCurves) {
      final rawSeries = _asList(data['series']) ?? _asList(data['lines']);
      if (rawSeries != null) {
        for (final item in rawSeries) {
          final map = _asMap(item);
          if (map == null) continue;
          final points = _parsePoints(map['points'] ?? map['data']);
          addSeries(
            (map['name'] ?? map['label'] ?? 'Serie ${series.length + 1}').toString(),
            points,
            dashed: _asBool(map['dashed']) ?? false,
          );
        }
      }

      final rawEnvelopes = _asList(data['envelopes']);
      if (rawEnvelopes != null) {
        for (var index = 0; index < rawEnvelopes.length; index++) {
          final item = rawEnvelopes[index];
          final map = _asMap(item);
          final points = map == null ? _parsePoints(item) : _parsePoints(map['points'] ?? map['data']);
          addSeries(
            map == null
                ? 'Envelope ${index + 1}'
                : (map['name'] ?? map['label'] ?? 'Envelope ${index + 1}').toString(),
            points,
          );
        }
      }

      final warnLine = _parsePoints(data['warnLine'] ?? data['warn_line']);
      addSeries('Warn', warnLine, dashed: true, color: LayoutTokens.accentOrange);

      final criticalLine = _parsePoints(data['criticalLine'] ?? data['critical_line'] ?? data['critLine']);
      addSeries('Crit', criticalLine, dashed: true, color: LayoutTokens.accentRed);
    }

    final fieldPoints = _parsePoints(
      data['fieldPoints'] ?? data['field_points'] ?? data['fieldData'] ?? data['field_data'],
    );

    final source = (data['source'] ?? payload['source'] ?? 'Atalaya-Predictor').toString();
    final note = data['note']?.toString() ??
        (shouldRenderCurves
            ? null
            : 'Mostrando datos reales de campo. Curvas ocultas hasta recibir curvas oficiales de Atalaya-Predictor.');

    return _SpecialPredictorChartData.fromSeries(
      type: type,
      source: source,
      note: note,
      series: series,
      fieldPoints: fieldPoints.take(180).toList(growable: false),
    );
  }

  bool _shouldRenderAuthoritativeCurves(
    Map<String, dynamic> data,
    Map<String, dynamic> rootPayload,
  ) {
    final explicit = _asBool(data['curvesAreAuthoritative'] ?? rootPayload['curvesAreAuthoritative']);
    if (explicit == true) return true;

    final source = '${data['seriesSource'] ?? rootPayload['seriesSource'] ?? ''}'.toLowerCase().trim();
    return source == 'atalaya-predictor' ||
        source == 'atalaya-predictor-web' ||
        source == 'predictor-web' ||
        source == 'web-figure';
  }

  String _compactSeriesName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'Serie';
    final lower = text.toLowerCase();
    final pickup = RegExp(r'pickup[-_\s]*ff?[-_\s]*(\d+)|pickup[-_\s]*(\d+)').firstMatch(lower);
    if (pickup != null) return 'PU-${pickup.group(1) ?? pickup.group(2) ?? ''}'.trim();
    final slack = RegExp(r'slack[-_\s]*off[-_\s]*ff?[-_\s]*(\d+)|slackoff[-_\s]*(\d+)').firstMatch(lower);
    if (slack != null) return 'SO-${slack.group(1) ?? slack.group(2) ?? ''}'.trim();
    return text
        .replaceAll('Pickup-', 'PU-')
        .replaceAll('Pickup ', 'PU-')
        .replaceAll('Slackoff-', 'SO-')
        .replaceAll('Slack-off-', 'SO-')
        .replaceAll('(1000 Kgf)', '')
        .replaceAll('(1000 kgf)', '')
        .trim();
  }

  List<FlSpot> _parsePoints(dynamic raw) {
    final rows = _asList(raw);
    if (rows == null) return const <FlSpot>[];

    final points = <FlSpot>[];
    for (final row in rows) {
      if (row is FlSpot) {
        points.add(FlSpot(row.x, -row.y.abs()));
        continue;
      }

      if (row is List && row.length >= 2) {
        final x = _toDouble(row[0]);
        final depth = _toDouble(row[1]);
        if (x != null && depth != null) points.add(FlSpot(x, -depth.abs()));
        continue;
      }

      final map = _asMap(row);
      if (map == null) continue;
      final x = _toDouble(
        map['x'] ?? map['value'] ?? map['load'] ?? map['torque'] ?? map['pressure'],
      );
      final depth = _toDouble(
        map['y'] ?? map['depth'] ?? map['md'] ?? map['mdDepth'] ?? map['measuredDepth'],
      );
      if (x != null && depth != null) points.add(FlSpot(x, -depth.abs()));
    }

    points.sort((a, b) => b.y.compareTo(a.y));
    return points;
  }

  _SpecialPredictorChartData _buildFallbackChartData(PredictorChartType type, {String? note}) {
    return _SpecialPredictorChartData.fromSeries(
      type: type,
      source: 'Sin datos oficiales de Atalaya-Predictor',
      note: note ?? 'No se dibujan curvas sintéticas en Special Predictor Screen.',
      series: const <_SpecialPredictorSeries>[],
      fieldPoints: const <FlSpot>[],
    );
  }
}

class _SpecialPredictorChart extends StatelessWidget {
  const _SpecialPredictorChart({required this.data});

  final _SpecialPredictorChartData data;

  @override
  Widget build(BuildContext context) {
    final yMaxDepth = _roundedDepthMax(data.maxDepth);
    final yInterval = _niceInterval(yMaxDepth / 6);
    final xAxis = _xAxisConfig(data.type, data.maxX);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: LayoutTokens.surfaceCard.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LayoutTokens.dividerSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${data.type.label} · MD Depth vs ${data.type.label} (${data.type.unit})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LayoutTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _ChartMetaLine(data: data),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _CompactLegend(series: data.series, hasFieldPoints: data.fieldPoints.isNotEmpty),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
            decoration: BoxDecoration(
              color: LayoutTokens.surfaceCard.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LayoutTokens.dividerSubtle.withValues(alpha: 0.72)),
            ),
            child: LineChart(
              LineChartData(
                minX: xAxis.min,
                maxX: xAxis.max,
                minY: -yMaxDepth,
                maxY: 0,
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchSpotThreshold: 24,
                  getTouchedSpotIndicator: (barData, indicators) {
                    return indicators.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.18),
                          strokeWidth: 1,
                          dashArray: const <int>[3, 3],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, spotIndex) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: bar.color ?? Colors.white,
                          ),
                        ),
                      );
                    }).toList(growable: false);
                  },
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final depth = _formatDepth(-spot.y);
                        final value = _formatXAxisValue(data.type, spot.x);
                        return LineTooltipItem(
                          '$value ${data.type.unit}\nMD $depth m',
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: yInterval,
                  verticalInterval: xAxis.interval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0x184A6D96),
                    strokeWidth: 0.8,
                  ),
                  getDrawingVerticalLine: (_) => const FlLine(
                    color: Color(0x124A6D96),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'MD Depth (m)',
                        style: TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yInterval,
                      reservedSize: 48,
                      getTitlesWidget: (value, _) => Text(
                        _formatDepth(-value),
                        style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${data.type.label} (${data.type.unit})',
                        style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xAxis.interval,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        if (!_isAlignedTick(value, xAxis.interval)) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _formatXAxisValue(data.type, value),
                          style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  ...data.series.map(
                    (series) => LineChartBarData(
                      spots: series.points,
                      isCurved: true,
                      curveSmoothness: 0.18,
                      color: series.color.withValues(alpha: series.dashed ? 0.74 : 0.94),
                      barWidth: series.width,
                      isStrokeCapRound: true,
                      dashArray: series.dashed ? const <int>[6, 5] : null,
                      dotData: const FlDotData(show: false),
                    ),
                  ),
                  if (data.fieldPoints.isNotEmpty)
                    LineChartBarData(
                      spots: data.fieldPoints,
                      isCurved: false,
                      color: Colors.transparent,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 2.7,
                          color: LayoutTokens.accentRed.withValues(alpha: 0.56),
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (data.note != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            data.note!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  double _niceInterval(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    if (normalized <= 1) return magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }
}

class _CompactLegend extends StatelessWidget {
  const _CompactLegend({required this.series, required this.hasFieldPoints});

  final List<_SpecialPredictorSeries> series;
  final bool hasFieldPoints;

  @override
  Widget build(BuildContext context) {
    final visible = series.take(6).toList(growable: false);
    final hiddenCount = series.length - visible.length;

    if (visible.isEmpty && !hasFieldPoints) {
      return const SizedBox(
        height: 30,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sin datos oficiales para graficar',
            style: TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
          ),
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: item.dashed ? 0.72 : 0.90),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _shortLegendLabel(item.name),
                    style: const TextStyle(
                      color: LayoutTokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '+$hiddenCount curvas',
                style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
              ),
            ),
          if (hasFieldPoints) ...const <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.scatter_plot_rounded, size: 12, color: LayoutTokens.accentRed),
                SizedBox(width: 5),
                Text('Datos reales', style: TextStyle(color: LayoutTokens.textMuted, fontSize: 11)),
              ],
            ),
            SizedBox(width: 12),
            Text(
              'Curvas oficiales pendientes',
              style: TextStyle(color: LayoutTokens.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartMetaLine extends StatelessWidget {
  const _ChartMetaLine({required this.data});

  final _SpecialPredictorChartData data;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = data.isFallback ? 'Fallback local' : 'Datos reales';
    final sourceColor = data.isFallback ? LayoutTokens.accentOrange : LayoutTokens.accentGreen;

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: sourceLabel,
            style: TextStyle(color: sourceColor, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' · ${data.fieldPoints.length} puntos · ${data.series.length} curvas'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: LayoutTokens.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _XAxisConfig {
  const _XAxisConfig({required this.min, required this.max, required this.interval});

  final double min;
  final double max;
  final double interval;
}

_XAxisConfig _xAxisConfig(PredictorChartType type, double observedMax) {
  final interval = switch (type) {
    PredictorChartType.hookLoad => 50.0,
    PredictorChartType.surfaceTorque => 50.0,
    PredictorChartType.pumpPressure => 500.0,
  };

  final minimumMax = switch (type) {
    PredictorChartType.hookLoad => 300.0,
    PredictorChartType.surfaceTorque => 400.0,
    PredictorChartType.pumpPressure => 4500.0,
  };

  final safeMax = observedMax.isFinite ? observedMax : minimumMax;
  final roundedMax = math.max(minimumMax, (safeMax / interval).ceil() * interval);

  return _XAxisConfig(min: 0, max: roundedMax, interval: interval);
}

double _roundedDepthMax(double observedMax) {
  if (!observedMax.isFinite || observedMax <= 0) return 8200;
  final rounded = (observedMax / 1000).ceil() * 1000.0;
  return math.max(rounded, 8200);
}

String _formatDepth(double value) {
  final clean = value.abs() < 0.0001 ? 0.0 : value.abs();
  return clean.toStringAsFixed(0);
}

String _formatXAxisValue(PredictorChartType type, double value) {
  final clean = value.abs() < 0.0001 ? 0.0 : value;
  if (type == PredictorChartType.pumpPressure) {
    return clean.toStringAsFixed(0);
  }
  return clean % 1 == 0 ? clean.toStringAsFixed(0) : clean.toStringAsFixed(1);
}

bool _isAlignedTick(double value, double interval) {
  if (interval <= 0) return true;
  final ratio = value / interval;
  return (ratio - ratio.round()).abs() < 0.01;
}

String _shortLegendLabel(String raw) {
  final label = raw.trim();
  final lower = label.toLowerCase();
  final numberMatch = RegExp(r'(\d+)').firstMatch(label);
  final suffix = numberMatch == null ? '' : '-${numberMatch.group(1)}';

  if (lower.contains('pickup')) return 'PU$suffix';
  if (lower.contains('slack')) return 'SO$suffix';
  if (lower.contains('critical') || lower == 'crit') return 'Crit';
  if (lower.contains('warn')) return 'Warn';
  if (lower.contains('field')) return 'Real';

  if (label.length <= 12) return label;
  return '${label.substring(0, 10)}…';
}

class _PredictorContextCard extends StatelessWidget {
  const _PredictorContextCard({this.sourceLabel, this.sourceTag});

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
              style: const TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          if (sourceTag != null) ...<Widget>[
            if (sourceLabel != null) const SizedBox(height: 4),
            Text(
              'Tag: $sourceTag',
              style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.icon});

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
          Icon(icon, size: 16, color: LayoutTokens.textSecondary),
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

class _SpecialPredictorChartData {
  const _SpecialPredictorChartData({
    required this.type,
    required this.source,
    required this.series,
    required this.fieldPoints,
    required this.minX,
    required this.maxX,
    required this.minDepth,
    required this.maxDepth,
    this.note,
  });

  factory _SpecialPredictorChartData.fromSeries({
    required PredictorChartType type,
    required String source,
    required List<_SpecialPredictorSeries> series,
    required List<FlSpot> fieldPoints,
    String? note,
  }) {
    final points = <FlSpot>[
      for (final item in series) ...item.points,
      ...fieldPoints,
    ];

    if (points.isEmpty) {
      return _SpecialPredictorChartData(
        type: type,
        source: source,
        note: note,
        series: series,
        fieldPoints: fieldPoints,
        minX: 0,
        maxX: 1,
        minDepth: 0,
        maxDepth: 1,
      );
    }

    var minX = points.first.x;
    var maxX = points.first.x;
    var minDepth = -points.first.y;
    var maxDepth = -points.first.y;

    for (final point in points) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minDepth = math.min(minDepth, -point.y);
      maxDepth = math.max(maxDepth, -point.y);
    }

    final xPad = math.max((maxX - minX) * 0.06, 1.0);
    final yPad = math.max((maxDepth - minDepth) * 0.04, 100.0);

    return _SpecialPredictorChartData(
      type: type,
      source: source,
      note: note,
      series: series,
      fieldPoints: fieldPoints,
      minX: minX - xPad,
      maxX: maxX + xPad,
      minDepth: math.max(0, minDepth - yPad),
      maxDepth: maxDepth + yPad,
    );
  }

  final PredictorChartType type;
  final String source;
  final String? note;

  bool get isFallback => source.toLowerCase().contains('fallback') || (note ?? '').toLowerCase().contains('fallback');
  final List<_SpecialPredictorSeries> series;
  final List<FlSpot> fieldPoints;
  final double minX;
  final double maxX;
  final double minDepth;
  final double maxDepth;
}

class _SpecialPredictorSeries {
  const _SpecialPredictorSeries({
    required this.name,
    required this.points,
    required this.color,
    this.dashed = false,
    this.width = 1.8,
  });

  final String name;
  final List<FlSpot> points;
  final Color color;
  final bool dashed;
  final double width;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is! Map) return null;
  return value.map((key, dynamic entryValue) => MapEntry(key.toString(), entryValue));
}

List<dynamic>? _asList(dynamic value) {
  if (value is List) return value;
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
    if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
  }
  return null;
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim().replaceAll(',', '.'));
  return null;
}
