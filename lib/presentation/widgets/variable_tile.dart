import 'package:flutter/material.dart';

import '../../core/theme/pro_palette.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/well_variable.dart';

enum VariableHealth {
  normal,
  warning,
  critical,
}

class VariableTile extends StatelessWidget {
  const VariableTile({
    super.key,
    required this.variable,
    required this.well,
    required this.job,
    required this.unitPreferences,
    required this.health,
    required this.onTap,
  });

  final WellVariable variable;
  final String well;
  final String job;
  final Map<String, String> unitPreferences;
  final VariableHealth health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayUnit = variable.configured
        ? UnitConverter.resolveDisplayUnit(
            slotIndex: variable.slot - 1,
            tag: variable.tag,
            rawUnit: variable.rawUnit,
            well: well,
            job: job,
            preferences: unitPreferences,
          )
        : '';

    final labelText = variable.configured ? variable.label : 'VAR ${variable.slot}';
    final valueText = _buildValueText(displayUnit);
    final visualColor = _statusColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: ProPalette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: visualColor.withOpacity(0.9)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: visualColor.withOpacity(0.18),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: visualColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        labelText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProPalette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  valueText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (health) {
      case VariableHealth.normal:
        return ProPalette.ok;
      case VariableHealth.warning:
        return ProPalette.warn;
      case VariableHealth.critical:
        return ProPalette.danger;
    }
  }

  String _buildValueText(String displayUnit) {
    if (!variable.configured) {
      return '---';
    }

    if (variable.value != null) {
      final convertedValue = UnitConverter.convertValue(
        variable.value!,
        variable.rawUnit,
        displayUnit,
      );
      return displayUnit.isEmpty
          ? UnitConverter.formatNumber(convertedValue)
          : '${UnitConverter.formatNumber(convertedValue)}\n$displayUnit';
    }

    if (variable.rawTextValue != null && variable.rawTextValue!.trim().isNotEmpty) {
      return variable.rawUnit.trim().isEmpty
          ? variable.rawTextValue!
          : '${variable.rawTextValue!}\n${variable.rawUnit}';
    }

    return '---';
  }
}
