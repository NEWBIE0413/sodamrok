import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/utils/spacing.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.child});

  factory TopBar.home({
    required VoidCallback onSearchTap,
    VoidCallback? onNotificationsTap,
  }) {
    return TopBar(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              '소',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Gaps.sm,
          Expanded(
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE0D8CF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    Gaps.sm,
                    const Expanded(
                      child: Text(
                        '장소나 태그를 검색해 보세요.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Gaps.sm,
          IconButton(
            onPressed: onNotificationsTap ?? () {},
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(4),
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
