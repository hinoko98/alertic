import 'dart:async';

import 'package:flutter/material.dart';

import '../core/errors/error_reporter.dart';
import '../features/alerts/domain/live_updates.dart';
import '../features/alerts/presentation/widgets/alert_gate.dart';
import '../features/session/domain/session.dart';
import '../shared/design/app_bottom_nav.dart';
import 'app_scope.dart';
import 'role_experience.dart';
import 'shell_scope.dart';

/// La app ya registrada.
///
/// No sabe qué rol está mostrando: le pide las pestañas a la fábrica del rol
/// que trae la sesión. Envuelve todo en [AlertGate], para que una alerta entre
/// por encima de cualquier pestaña abierta.
///
/// También lleva la cuenta de los mensajes del colegio sin leer: la insignia del
/// chat tiene que verse en cualquier pestaña, y quien la dibuja no tiene por qué
/// preguntarle al servidor por su cuenta.
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

  final ValueNotifier<int> _chatUnread = ValueNotifier<int>(0);
  StreamSubscription<LiveChange>? _live;
  String? _schoolName;

  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange change) => change == LiveChange.chat)
          .listen((_) => _refreshChatUnread());
      _refreshChatUnread();
      _loadSchool();
    }
  }

  Future<void> _loadSchool() async {
    try {
      final school = await AppScope.of(context).accountRepository?.loadSchool();
      if (mounted && school != null) setState(() => _schoolName = school.name);
    } catch (error, stack) {
      // El nombre es un detalle de las cabeceras: sin él se muestran sin colegio.
      ErrorReporter.report(error, stack, context: 'nombre del colegio');
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    _chatUnread.dispose();
    super.dispose();
  }

  Future<void> _refreshChatUnread() async {
    final supportRepository = AppScope.of(context).supportRepository;
    if (supportRepository == null) return;

    try {
      final int count = await supportRepository.unreadCount();
      if (mounted) _chatUnread.value = count;
    } catch (error, stack) {
      // La insignia es un adorno útil: si no se puede traer no se muestra, y no
      // vale la pena avisarle a nadie.
      ErrorReporter.report(error, stack, context: 'mensajes sin leer');
    }
  }

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
        role: widget.session.role,
        chatUnread: _chatUnread,
        refreshChatUnread: _refreshChatUnread,
        schoolName: _schoolName,
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
              : ValueListenableBuilder<int>(
                  valueListenable: _chatUnread,
                  builder: (BuildContext context, int unread, _) => AppBottomNav(
                    index: _index,
                    onChanged: (int value) => setState(() => _index = value),
                    items: <NavItem>[
                      for (final AppDestination destination in _destinations)
                        NavItem(
                          label: destination.label,
                          icon: destination.icon,
                          badge: destination.showsChatBadge ? unread : 0,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
