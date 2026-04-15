import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({super.key, this.onRefresh, this.onOpenMenu});

  final VoidCallback? onRefresh;
  final VoidCallback? onOpenMenu;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
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
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: LayoutTokens.textPrimary)),
        if (onOpenMenu != null)
          IconButton(onPressed: onOpenMenu, icon: const Icon(Icons.tune_rounded, color: LayoutTokens.textPrimary)),
      ],
    );
  }
}
