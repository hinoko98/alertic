import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/sign_out.dart';
import '../../../core/errors/error_reporter.dart';
import '../../alerts/domain/live_updates.dart';
import '../../onboarding/domain/enrollment.dart';
import '../../session/domain/session.dart';
import 'screens/web_alerta_screen.dart';
import 'screens/web_config_screen.dart';
import 'screens/web_contenidos_screen.dart';
import 'screens/web_docentes_screen.dart';
import 'screens/web_fuentes_screen.dart';
import 'screens/web_informes_screen.dart';
import 'screens/web_mapa_screen.dart';
import 'screens/web_monitoreo_screen.dart';
import 'screens/web_reportes_screen.dart';
import 'screens/web_resumen_screen.dart';
import 'screens/web_simulacros_screen.dart';
import 'screens/web_usuarios_screen.dart';
import 'screens/web_vinculos_screen.dart';
import 'web_nav.dart';
import 'web_style.dart';

/// El panel del colegio en el navegador: menú lateral y una pantalla a la
/// derecha. Por debajo de [WebBreakpoints.drawer] el menú pasa a un cajón.
///
/// Es la misma app y el mismo código que el celular: reutiliza los repositorios
/// que ya existen y solo cambia la forma de mostrarlos.
class WebShell extends StatefulWidget {
  const WebShell({required this.session, required this.onSignedOut, super.key});

  final Session session;
  final VoidCallback onSignedOut;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  final ValueNotifier<Map<WebPage, int>> _badges =
      ValueNotifier<Map<WebPage, int>>(const <WebPage, int>{});

  WebPage _page = WebPage.resumen;
  Widget? _detail;
  String? _schoolName;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadSchool();
    _loadBadges();
    // Un reporte o un aviso nuevo mueve los contadores del menú sin recargar.
    AppScope.of(context).liveUpdates.changes.listen((LiveChange _) {
      if (mounted) _loadBadges();
    });
  }

  @override
  void dispose() {
    _badges.dispose();
    super.dispose();
  }

  Future<void> _loadSchool() async {
    try {
      final school = await AppScope.of(context).accountRepository?.loadSchool();
      if (mounted && school != null) setState(() => _schoolName = school.name);
    } catch (error, stack) {
      // El nombre es un adorno del menú: sin él se muestra solo ALERTIC.
      ErrorReporter.report(error, stack, context: 'nombre del colegio (panel web)');
    }
  }

  Future<void> _loadBadges() async {
    final AppScope scope = AppScope.of(context);
    final Map<WebPage, int> next = <WebPage, int>{};
    try {
      final reports = await scope.riskRepository?.loadInbox();
      if (reports != null) {
        next[WebPage.reportes] =
            reports.where((r) => r.status.wire == 'nuevo').length;
      }
      final signals = await scope.panelRepository?.loadSignals();
      if (signals != null) next[WebPage.fuentes] = signals.length;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'contadores del menú web');
    }
    if (mounted) _badges.value = next;
  }

  void _go(WebPage page) {
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
    setState(() {
      _page = page;
      _detail = null;
    });
  }

  void _open(Widget screen) => setState(() => _detail = screen);

  void _back() {
    setState(() => _detail = null);
    _loadBadges();
  }

  Future<void> _signOut() async {
    final AppScope scope = AppScope.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Volverás a entrar con tu correo y tu contraseña.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WebColors.brand),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await signOutOfDevice(scope);
    widget.onSignedOut();
  }

  Widget _screenFor(WebPage page) {
    return switch (page) {
      WebPage.resumen => WebResumenScreen(session: widget.session),
      WebPage.alerta => WebAlertaScreen(session: widget.session),
      WebPage.monitoreo => const WebMonitoreoScreen(),
      WebPage.fuentes => const WebFuentesScreen(),
      WebPage.usuarios => const WebUsuariosScreen(),
      WebPage.docentes => const WebDocentesScreen(),
      WebPage.vinculos => const WebVinculosScreen(),
      WebPage.mapa => const WebMapaScreen(),
      WebPage.simulacros => const WebSimulacrosScreen(),
      WebPage.contenidos => const WebContenidosScreen(),
      WebPage.reportes => const WebReportesScreen(),
      WebPage.informes => const WebInformesScreen(),
      WebPage.repeticion => const WebRepeticionScreen(),
      WebPage.config => const WebConfigScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool drawer = WebBreakpoints.isDrawer(context);
    final Widget menu = _SideMenu(
      current: _page,
      schoolName: _schoolName,
      profile: widget.session.profile,
      badges: _badges,
      onSelect: _go,
      onSignOut: _signOut,
    );

    return WebNav(
      current: _page,
      session: widget.session,
      go: _go,
      openMenu: () => _scaffold.currentState?.openDrawer(),
      open: _open,
      back: _back,
      hasDetail: _detail != null,
      refreshBadges: _loadBadges,
      badges: _badges,
      child: Scaffold(
        key: _scaffold,
        backgroundColor: WebColors.page,
        drawer: drawer ? Drawer(width: 280, backgroundColor: WebColors.ink, child: menu) : null,
        body: Row(
          children: <Widget>[
            if (!drawer) SizedBox(width: 256, child: ColoredBox(color: WebColors.ink, child: menu)),
            Expanded(child: KeyedSubtree(
                key: ValueKey<Object>(_detail ?? _page),
                child: _detail ?? _screenFor(_page),
              ),),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.current,
    required this.schoolName,
    required this.profile,
    required this.badges,
    required this.onSelect,
    required this.onSignOut,
  });

  final WebPage current;
  final String? schoolName;
  final Enrollment profile;
  final ValueNotifier<Map<WebPage, int>> badges;
  final void Function(WebPage page) onSelect;
  final VoidCallback onSignOut;

  static String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: WebColors.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_outlined, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'ALERTIC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (schoolName != null)
                          Text(
                            schoolName!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: WebColors.sideMuted, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Map<WebPage, int>>(
                valueListenable: badges,
                builder: (BuildContext context, Map<WebPage, int> counts, _) {
                  return ListView(
                    children: <Widget>[
                      for (final WebSection section in WebSection.values) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                          child: Text(
                            section.label.toUpperCase(),
                            style: const TextStyle(
                              color: WebColors.inkFaint,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final WebPage page in WebPage.values.where((WebPage p) => p.section == section))
                          _NavItem(
                            page: page,
                            selected: page == current,
                            count: counts[page] ?? 0,
                            onTap: () => onSelect(page),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 0, 0),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: WebColors.brand,
                    child: Text(
                      _initials(profile.fullName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (profile is AdminEnrollment && (profile as AdminEnrollment).email != null)
                          Text(
                            (profile as AdminEnrollment).email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: WebColors.sideMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout, size: 18, color: WebColors.sideText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final WebPage page;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0x1AFFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0x0FFFFFFF),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    page.icon,
                    size: 18,
                    color: selected ? const Color(0xFFF08A98) : WebColors.sideText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      page.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : WebColors.sideText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: WebColors.brand,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
