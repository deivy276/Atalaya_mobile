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
    this.onTapReset,
  });

  final int tileCount;
  final String densityLabel;
  final String layoutLabel;
  final VoidCallback? onTapDensity;
  final VoidCallback? onTapLayout;
  final VoidCallback? onTapReset;

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
          semanticLabel: 'Cambiar densidad actual: $densityLabel',
        ),
        _ChipLabel(
          text: 'Vista: $layoutLabel',
          icon: Icons.grid_view_rounded,
          onTap: onTapLayout,
          semanticLabel: 'Cambiar vista actual: $layoutLabel',
        ),
        if (onTapReset != null)
          _ChipLabel(
            text: 'Restablecer',
            icon: Icons.restart_alt_rounded,
            onTap: onTapReset,
            semanticLabel: 'Restablecer ajustes de layout',
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
    this.semanticLabel,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? text,
      child: Tooltip(
        message: text,
        child: Material(
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
        ),
      ),
    );
  }
}
