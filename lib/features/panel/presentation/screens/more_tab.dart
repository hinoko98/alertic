import 'package:flutter/material.dart';

import '../../../../app/shell_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../drills/presentation/drills_screen.dart';
import '../../../risks/presentation/risk_inbox_screen.dart';
import 'history_tab.dart';
import 'protocols_tab.dart';

/// «Más»: lo que coordinación consulta de vez en cuando, sin ocupar una
/// pestaña cada cosa.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Más',
      subtitle: 'Gestión del colegio',
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _MoreRow(
                  icon: Icons.fitness_center_outlined,
                  title: 'Simulacros',
                  subtitle: 'Programar, iniciar y ver resultados',
                  onTap: () => pushInShell<void>(
                    context,
                    (_) => const DrillsScreen(canSchedule: true),
                  ),
                ),
                const Divider(height: 1),
                _MoreRow(
                  icon: Icons.report_problem_outlined,
                  title: 'Reportes de riesgo',
                  subtitle: 'Lo que la comunidad avisa',
                  onTap: () => pushInShell<void>(
                    context,
                    (_) => const RiskInboxScreen(canManage: true),
                  ),
                ),
                const Divider(height: 1),
                _MoreRow(
                  icon: Icons.history,
                  title: 'Historial',
                  subtitle: 'Alertas anteriores',
                  onTap: () => pushInShell<void>(context, (_) => const _Subpage(child: HistoryTab())),
                ),
                const Divider(height: 1),
                _MoreRow(
                  icon: Icons.menu_book_outlined,
                  title: 'Protocolos',
                  subtitle: 'Qué hacer en cada emergencia',
                  onTap: () => pushInShell<void>(context, (_) => const _Subpage(child: ProtocolsTab())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las pestañas de historial y protocolos ya traen su propio título: aquí solo
/// se les da dónde apoyarse y un botón para volver.
class _Subpage extends StatelessWidget {
  const _Subpage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: child,
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            IconBubble.neutral(icon: icon, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
