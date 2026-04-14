import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class LayoutSummaryChips extends StatelessWidget {
  const LayoutSummaryChips({
    super.key,
    required this.tileCount,
    required this.densityLabel,
    required this.layoutLabel,
  });

  final int tileCount;
  final String densityLabel;
  final String layoutLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ChipLabel(text: '$tileCount variables'),
        _ChipLabel(text: 'Densidad: $densityLabel'),
        _ChipLabel(text: 'Vista: $layoutLabel'),
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: LayoutTokens.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}
