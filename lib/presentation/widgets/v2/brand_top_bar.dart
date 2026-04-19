import 'package:flutter/material.dart';

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

  // Kept for backward compatibility with older DashboardV2Screen revisions.
  final VoidCallback? onOpenMenu;

  // Logout is intentionally not rendered in the AppBar anymore.
  // It is exposed from the Settings panel to avoid accidental taps in field operation.
  final VoidCallback? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final settingsCallback = onOpenSettings ?? onOpenMenu;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: LayoutTokens.spacing16,
      title: const Row(
        children: <Widget>[
          Image(
            image: AssetImage('assets/Atalaya.png'),
            height: 24,
            fit: BoxFit.contain,
          ),
          SizedBox(width: LayoutTokens.spacing8),
          Text(
            'Atalaya Mobile',
            style: TextStyle(
              color: LayoutTokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (onRefresh != null)
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: LayoutTokens.textPrimary),
          ),
        if (settingsCallback != null)
          IconButton(
            tooltip: 'Configuración',
            onPressed: settingsCallback,
            icon: const Icon(Icons.settings_rounded, color: LayoutTokens.textPrimary),
          ),
      ],
    );
  }
}
