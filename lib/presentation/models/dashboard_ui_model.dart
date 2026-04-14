import 'package:flutter/material.dart';

class DashboardUiModel {
  const DashboardUiModel({
    required this.appTitle,
    required this.activeWell,
    required this.wellStatus,
    required this.tiles,
    required this.predictorAlerts,
    this.selectedVariableId,
  });

  final String appTitle;
  final String activeWell;
  final String wellStatus;
  final List<VariableTileUiModel> tiles;
  final List<PredictorAlertUiModel> predictorAlerts;
  final String? selectedVariableId;
}

class VariableTileUiModel {
  const VariableTileUiModel({
    required this.id,
    required this.label,
    required this.valueText,
    required this.unitText,
    required this.trendSeries,
    required this.deltaText,
    required this.deltaDirection,
    required this.visualStatus,
    required this.accentColor,
    required this.isSelected,
    required this.isTappable,
  });

  final String id;
  final String label;
  final String valueText;
  final String unitText;
  final List<double> trendSeries;
  final String deltaText;
  final TrendDirection deltaDirection;
  final TileVisualStatus visualStatus;
  final Color accentColor;
  final bool isSelected;
  final bool isTappable;
}

class PredictorAlertUiModel {
  const PredictorAlertUiModel({
    required this.id,
    required this.severity,
    required this.source,
    required this.timestampText,
    required this.title,
    required this.body,
    this.acknowledged = false,
  });

  final String id;
  final AlertUiSeverity severity;
  final String source;
  final String timestampText;
  final String title;
  final String body;
  final bool acknowledged;
}

enum TrendDirection { up, down, flat }

enum TileVisualStatus { normal, selected, warning, critical, stale, loading, disabled }

enum AlertUiSeverity { info, warning, critical }
