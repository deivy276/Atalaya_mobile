import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class LayoutSummaryChips extends StatelessWidget {
  const LayoutSummaryChips({
    super.key,
    required this.tileCount,
    required this.densityLabel,
    required this.layoutLabel,
    this.onTapDensity,
    this.onTapLayout,
  });

  final int tileCount;
  final String densityLabel;
  final String layoutLabel;
  final VoidCallback? onTapDensity;
  final VoidCallback? onTapLayout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ChipLabel(text: '$tileCount variables'),
        _ChipLabel(
          text: 'Densidad: $densityLabel',
          icon: Icons.tune_rounded,
          onTap: onTapDensity,
        ),
        _ChipLabel(
          text: 'Vista: $layoutLabel',
          icon: Icons.grid_view_rounded,
          onTap: onTapLayout,
        ),
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.text,
    this.icon,
    this.onTap,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: LayoutTokens.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: LayoutTokens.dividerSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: LayoutTokens.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: const TextStyle(
                  color: LayoutTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
