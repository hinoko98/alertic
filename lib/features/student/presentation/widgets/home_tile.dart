import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/icon_bubble.dart';

/// Atajo del inicio: un icono y qué abre.
class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconBubble(icon: icon, size: 34),
            Text(label, style: AppTextStyles.itemTitle.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
