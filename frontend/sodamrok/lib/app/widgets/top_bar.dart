import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/utils/spacing.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.child});

  factory TopBar.home({required VoidCallback onSearchTap}) {
    return TopBar(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.local_florist_rounded, color: AppColors.primary),
          ),
          Gaps.sm,
          const Expanded(
            child: Text(
              '수원 팔달구',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Gaps.sm,
          InkWell(
            onTap: onSearchTap,
            overlayColor: MaterialStatePropertyAll(AppColors.primaryOpacity10),
            child: const Padding(
              padding: EdgeInsets.all(Insets.sm),
              child: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  factory TopBar.placeholder(String title) {
    return TopBar(
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textMain,
          fontSize: 18,
        ),
      ),
    );
  }

  final Widget child;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}
