import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/utils/downsampler.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/trend_point.dart';
import 'api_client_provider.dart';

class TrendRequest {
  const TrendRequest({
    required this.tag,
    required this.rawUnit,
    required this.displayUnit,
    required this.range,
  });

  final String tag;
  final String rawUnit;
  final String displayUnit;
  final TrendRange range;

  @override
  bool operator ==(Object other) {
    return other is TrendRequest &&
        other.tag == tag &&
        other.rawUnit == rawUnit &&
        other.displayUnit == displayUnit &&
        other.range == range;
  }

  @override
  int get hashCode => Object.hash(tag, rawUnit, displayUnit, range);
}

class TrendSeriesState {
  const TrendSeriesState({
    required this.points,
    required this.displayUnit,
    required this.yMin,
    required this.yMax,
    required this.yLast,
    required this.yAvg30,
    required this.yAvgAll,
    required this.yViewMin,
    required this.yViewMax,
    required this.yStep,
    required this.yTicks,
    required this.bottomLabels,
    required this.rangeText,
  });

  final List<TrendPoint> points;
  final String displayUnit;
  final double yMin;
  final double yMax;
  final double yLast;
  final double yAvg30;
  final double yAvgAll;
  final double yViewMin;
  final double yViewMax;
  final double yStep;
  final List<double> yTicks;
  final Map<int, String> bottomLabels;
  final String rangeText;

  bool get hasEnoughData => points.length >= 3;
}

final trendSeriesProvider =
    FutureProvider.autoDispose.family<TrendSeriesState, TrendRequest>((ref, request) async {
  final repository = ref.watch(atalayaRepositoryProvider);
  final rawPoints = await repository.getTrend(tag: request.tag, range: request.range);
  final sampled = Downsampler.limit(rawPoints, maxPoints: 350);

  final converted = sampled
      .map(
        (point) => TrendPoint(
          timestamp: point.timestamp,
          value: UnitConverter.convertValue(
            point.value,
            request.rawUnit,
            request.displayUnit,
          ),
        ),
      )
      .toList(growable: false);

  if (converted.length < 3) {
    final rangeText = converted.isEmpty
        ? '--:-- → --:--'
        : '${DateFormat('HH:mm').format(converted.first.timestamp.toLocal())} → '
            '${DateFormat('HH:mm').format(converted.last.timestamp.toLocal())}';
    return TrendSeriesState(
      points: converted,
      displayUnit: request.displayUnit,
      yMin: 0,
      yMax: 0,
      yLast: converted.isEmpty ? 0 : converted.last.value,
      yAvg30: converted.isEmpty ? 0 : converted.last.value,
      yAvgAll: converted.isEmpty ? 0 : converted.last.value,
      yViewMin: converted.isEmpty ? 0 : converted.last.value - 1,
      yViewMax: converted.isEmpty ? 1 : converted.last.value + 1,
      yStep: 1,
      yTicks: const <double>[0, 1],
      bottomLabels: <int, String>{
        if (converted.isNotEmpty) 0: DateFormat('HH:mm').format(converted.first.timestamp.toLocal()),
      },
      rangeText: rangeText,
    );
  }

  final values = converted.map((point) => point.value).toList(growable: false);
  final yMin = values.reduce(math.min);
  final yMax = values.reduce(math.max);
  final yLast = values.last;
  final pad = yMax > yMin ? (yMax - yMin) * 0.12 : 1.0;

  final endTime = converted.last.timestamp.toUtc();
  final cutoff = endTime.subtract(const Duration(minutes: 30));
  final values30 = converted
      .where((point) => point.timestamp.toUtc().isAfter(cutoff) || point.timestamp.toUtc().isAtSameMomentAs(cutoff))
      .map((point) => point.value)
      .toList(growable: false);
  final yAvgAll = values.reduce((left, right) => left + right) / values.length;
  final yAvg30 = values30.length >= 3
      ? values30.reduce((left, right) => left + right) / values30.length
      : yAvgAll;

  final yViewMin = yMin - pad;
  final yViewMax = yMax + pad;
  final yStep = _niceStep((yViewMax - yViewMin) / 4);
  final yTicks = _buildYTicks(yViewMin: yViewMin, yViewMax: yViewMax, step: yStep);
  final bottomLabels = _buildBottomLabels(converted);
  final rangeText = '${DateFormat('HH:mm').format(converted.first.timestamp.toLocal())} → '
      '${DateFormat('HH:mm').format(converted.last.timestamp.toLocal())}';

  return TrendSeriesState(
    points: converted,
    displayUnit: request.displayUnit,
    yMin: yMin,
    yMax: yMax,
    yLast: yLast,
    yAvg30: yAvg30,
    yAvgAll: yAvgAll,
    yViewMin: yViewMin,
    yViewMax: yViewMax,
    yStep: yStep,
    yTicks: yTicks,
    bottomLabels: bottomLabels,
    rangeText: rangeText,
  );
});

double _niceStep(double rawStep) {
  if (rawStep <= 0 || rawStep.isNaN || rawStep.isInfinite) {
    return 1;
  }

  final exponent = (math.log(rawStep) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final normalized = rawStep / magnitude;

  double multiplier;
  if (normalized <= 1) {
    multiplier = 1;
  } else if (normalized <= 2) {
    multiplier = 2;
  } else if (normalized <= 5) {
    multiplier = 5;
  } else {
    multiplier = 10;
  }

  return multiplier * magnitude;
}

List<double> _buildYTicks({
  required double yViewMin,
  required double yViewMax,
  required double step,
}) {
  final start = (yViewMin / step).floor() * step;
  final end = (yViewMax / step).ceil() * step;
  final ticks = <double>[];

  var current = start;
  while (current <= end + step * 0.001) {
    ticks.add(double.parse(current.toStringAsFixed(6)));
    current += step;
  }

  const maxLabels = 4;
  if (ticks.length <= maxLabels) {
    return ticks;
  }

  final indexes = List<int>.generate(
    maxLabels,
    (index) => ((index * (ticks.length - 1)) / (maxLabels - 1)).round(),
    growable: false,
  ).toSet().toList()
    ..sort();

  return indexes.map((index) => ticks[index]).toList(growable: false);
}

Map<int, String> _buildBottomLabels(List<TrendPoint> points) {
  if (points.isEmpty) {
    return const <int, String>{};
  }

  final count = points.length;
  final indexes = count < 5
      ? List<int>.generate(count, (index) => index, growable: false)
      : <int>[0, count ~/ 4, count ~/ 2, (3 * count) ~/ 4, count - 1];

  final formatter = DateFormat('HH:mm');
  return <int, String>{
    for (final index in indexes.toSet()) index: formatter.format(points[index].timestamp.toLocal()),
  };
}
