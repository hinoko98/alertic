import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'screens/community_tab.dart';
import 'screens/emergency_tab.dart';
import 'screens/history_tab.dart';
import 'screens/protocols_tab.dart';

/// Bloque F: el panel del colegio.
///
/// Corre en el computador de coordinación, no en un celular. Es otra app con el
/// mismo código: comparte dominio, tema y repositorios, y solo cambia la forma
/// de mostrarlo. Por eso vive en este mismo proyecto y no en uno aparte.
class PanelShell extends StatefulWidget {
  const PanelShell({this.onSignOut, super.key});

  /// Cierra la sesión. Es nulo con datos de prueba, donde no hay sesión.
  final VoidCallback? onSignOut;

  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell> {
  int _index = 0;

  static final List<({String label, Widget screen})> _tabs =
      <({String label, Widget screen})>[
    (label: 'EMERGENCIA', screen: EmergencyTab()),
    (label: 'COMUNIDAD', screen: CommunityTab()),
    (label: 'HISTORIAL', screen: HistoryTab()),
    (label: 'PROTOCOLOS', screen: ProtocolsTab()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: <Widget>[
          _TopBar(
            index: _index,
            onChanged: (int value) => setState(() => _index = value),
            onSignOut: widget.onSignOut,
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                for (final ({String label, Widget screen}) tab in _tabs)
                  tab.screen,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior con el nombre del colegio y las pestañas.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.onChanged,
    this.onSignOut,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          const Text(
            AppStrings.appName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'IIC Barbosa · Panel del colegio',
              style: AppTextStyles.caption,
            ),
          ),
          for (int i = 0; i < _PanelShellState._tabs.length; i++)
            _TabButton(
              label: _PanelShellState._tabs[i].label,
              selected: i == index,
              onTap: () => onChanged(i),
            ),
          if (onSignOut != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xl),
            TextButton(
              onPressed: onSignOut,
              style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
              child: const Text(
                'SALIR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.brand : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: selected ? AppColors.brand : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
