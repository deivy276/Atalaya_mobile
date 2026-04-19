import 'package:flutter/material.dart';

import '../../../core/theme/atalaya_theme.dart';
import '../../../core/theme/layout_tokens.dart';

class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({
    super.key,
    this.onRefresh,
    this.onOpenSettings,
    this.onOpenMenu,
    this.onLogout,
  });

  final VoidCallback? onRefresh;
  final VoidCallback? onOpenSettings;

  // Backward compatibility with older DashboardV2Screen revisions.
  final VoidCallback? onOpenMenu;

  // Logout intentionally remains inside Settings to reduce accidental taps.
  final VoidCallback? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final settingsCallback = onOpenSettings ?? onOpenMenu;

    return AppBar(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: LayoutTokens.spacing16,
      title: Row(
        children: <Widget>[
          const Image(
            image: AssetImage('assets/Atalaya.png'),
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: LayoutTokens.spacing8),
          Text(
            'Atalaya Mobile',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (onRefresh != null)
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
          ),
        if (settingsCallback != null)
          IconButton(
            tooltip: 'Configuración',
            onPressed: settingsCallback,
            icon: Icon(Icons.settings_rounded, color: colors.textPrimary),
          ),
      ],
    );
  }
}
