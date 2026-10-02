import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/alerts/presentation/widgets/alert_gate.dart';
import '../features/session/domain/session.dart';
import 'role_experience.dart';
import 'shell_scope.dart';

/// La app ya registrada.
///
/// No sabe qué rol está mostrando: le pide las pestañas a la fábrica del rol
/// que trae la sesión. Envuelve todo en [AlertGate], para que una alerta entre
/// por encima de cualquier pestaña abierta.
class AppShell extends StatefulWidget {
  const AppShell({required this.session, super.key});

  final Session session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final List<AppDestination> _destinations =
      RoleExperiences.forRole(widget.session.role)
          .buildDestinations(widget.session);

  int _index = 0;

  void _openTab(String label) {
    final int target = _destinations.indexWhere(
      (AppDestination destination) => destination.label == label,
    );
    if (target >= 0 && target != _index) {
      setState(() => _index = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertGate(
      session: widget.session,
      child: ShellScope(
        openTab: _openTab,
        child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: <Widget>[
              for (final AppDestination destination in _destinations)
                Builder(builder: destination.builder),
            ],
          ),
          bottomNavigationBar: _destinations.length < 2
              ? null
              : _BottomBar(
                  destinations: _destinations,
                  index: _index,
                  onChanged: (int value) => setState(() => _index = value),
                ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.index,
    required this.onChanged,
  });

  final List<AppDestination> destinations;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBarTheme(
        data: const NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onChanged,
          destinations: <Widget>[
            for (int i = 0; i < destinations.length; i++)
              NavigationDestination(
                icon: Icon(
                  destinations[i].icon,
                  size: 22,
                  color: i == index ? AppColors.brand : AppColors.inkMuted,
                ),
                label: destinations[i].label,
              ),
          ],
        ),
      ),
    );
  }
}
