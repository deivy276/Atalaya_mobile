import 'package:flutter/material.dart';

import '../../../core/theme/atalaya_theme.dart';
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
    final colors = context.atalayaColors;
    final statusColor = isActive ? colors.success : colors.warning;

    return Container(
      padding: const EdgeInsets.all(LayoutTokens.spacing16),
      decoration: BoxDecoration(
        gradient: colors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow,
            blurRadius: colors.isDark ? 16 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.oil_barrel_rounded, color: colors.textSecondary),
          const SizedBox(width: LayoutTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  well.isEmpty ? 'Well not available' : well,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: LayoutTokens.spacing4),
                Text(
                  job.isEmpty ? 'No active operation' : job,
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: colors.isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: colors.isDark ? 1 : 0.72)),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'STALE',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
