import 'package:flutter/material.dart';

import '../../../core/theme/atalaya_theme.dart';

class LayoutSummaryChips extends StatelessWidget {
  static const double _compactBreakpoint = 420;

  const LayoutSummaryChips({
    super.key,
    required this.tileCount,
    required this.densityLabel,
    required this.layoutLabel,
    this.onTapDensity,
    this.onTapLayout,
    this.onTapReset,
    this.statusText,
    this.statusColor,
  });

  final int tileCount;
  final String densityLabel;
  final String layoutLabel;
  final VoidCallback? onTapDensity;
  final VoidCallback? onTapLayout;
  final VoidCallback? onTapReset;
  final String? statusText;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        return Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: compact ? 6 : 8,
          children: <Widget>[
            if (statusText != null)
              _ChipLabel(
                text: statusText!,
                icon: Icons.radio_button_checked_rounded,
                textColor: statusColor,
                semanticLabel: 'Estado operativo: $statusText',
              ),
            _ChipLabel(
              text: '$tileCount variables',
              icon: Icons.insights_rounded,
              semanticLabel: 'Cantidad de variables visibles: $tileCount',
            ),
            _ChipLabel(
              text: compact ? densityLabel : 'Densidad: $densityLabel',
              icon: Icons.tune_rounded,
              onTap: onTapDensity,
              semanticLabel: 'Cambiar densidad actual: $densityLabel',
            ),
            _ChipLabel(
              text: compact ? layoutLabel : 'Vista: $layoutLabel',
              icon: Icons.grid_view_rounded,
              onTap: onTapLayout,
              semanticLabel: 'Cambiar vista actual: $layoutLabel',
            ),
            _ChipLabel(
              text: compact ? 'Reset' : 'Restablecer',
              icon: Icons.restart_alt_rounded,
              onTap: onTapReset,
              semanticLabel: 'Restablecer ajustes de layout',
              showDisabledHint: true,
            ),
          ],
        );
      },
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.text,
    this.icon,
    this.onTap,
    this.semanticLabel,
    this.textColor,
    this.showDisabledHint = false,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? textColor;
  final bool showDisabledHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final foreground = textColor ?? (onTap == null ? colors.textMuted : colors.textSecondary);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel ?? text,
      child: Tooltip(
        message: onTap == null && showDisabledHint ? '$text (sin cambios pendientes)' : text,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: onTap == null
                    ? colors.card.withValues(alpha: colors.isDark ? 0.62 : 0.75)
                    : colors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 14, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    text,
                    style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700),
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
