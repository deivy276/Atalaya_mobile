import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class WellOverviewCard extends StatelessWidget {
  const WellOverviewCard({
    super.key,
    required this.well,
    required this.job,
    required this.isActive,
  });

  final String well;
  final String job;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LayoutTokens.spacing16),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.oil_barrel_rounded, color: LayoutTokens.textSecondary),
          const SizedBox(width: LayoutTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  well.isEmpty ? 'Well not available' : well,
                  style: const TextStyle(
                    color: LayoutTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: LayoutTokens.spacing4),
                Text(
                  job.isEmpty ? 'No active operation' : job,
                  style: const TextStyle(color: LayoutTokens.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isActive ? LayoutTokens.accentGreen : LayoutTokens.accentOrange).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: isActive ? LayoutTokens.accentGreen : LayoutTokens.accentOrange),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'STALE',
              style: TextStyle(
                color: isActive ? LayoutTokens.accentGreen : LayoutTokens.accentOrange,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
