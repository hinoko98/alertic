import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// El bloque de color que dice cómo está todo: verde si no hay alertas, rojo si
/// las hay, ámbar si falta algo por confirmar.
enum BannerTone { success, danger, warning, dark }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.title,
    required this.icon,
    this.subtitle,
    this.tone = BannerTone.success,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final BannerTone tone;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color background = switch (tone) {
      BannerTone.success => AppColors.success,
      BannerTone.danger => AppColors.brand,
      BannerTone.warning => AppColors.warning,
      BannerTone.dark => AppColors.ink,
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.onBrand, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBrand,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
