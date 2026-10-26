import 'package:flutter/material.dart';

import '../../session/domain/session.dart';

import 'web_style.dart';

/// Las pantallas del panel web, en el orden y con los grupos del menú del diseño.
enum WebPage {
  resumen(WebSection.operacion, 'Resumen', Icons.home_outlined),
  alerta(WebSection.operacion, 'Emitir alerta', Icons.warning_amber_outlined),
  monitoreo(WebSection.operacion, 'Monitoreo en vivo', Icons.sensors_outlined),
  fuentes(WebSection.operacion, 'Alertas automáticas', Icons.cell_tower_outlined),
  usuarios(WebSection.preparacion, 'Usuarios y códigos', Icons.groups_outlined),
  docentes(WebSection.preparacion, 'Docentes y grupos', Icons.co_present_outlined),
  vinculos(WebSection.preparacion, 'Vincular acudientes', Icons.link),
  mapa(WebSection.preparacion, 'Mapa y rutas', Icons.map_outlined),
  simulacros(WebSection.preparacion, 'Simulacros', Icons.event_outlined),
  contenidos(WebSection.preparacion, 'Guías y asistente', Icons.menu_book_outlined),
  reportes(WebSection.seguimiento, 'Reportes de riesgo', Icons.flag_outlined),
  informes(WebSection.seguimiento, 'Informes', Icons.bar_chart),
  repeticion(WebSection.seguimiento, 'Repetición de simulacros', Icons.play_circle_outline),
  config(WebSection.institucion, 'Configuración', Icons.settings_outlined);

  const WebPage(this.section, this.label, this.icon);

  final WebSection section;
  final String label;
  final IconData icon;
}

enum WebSection {
  operacion('Operación'),
  preparacion('Preparación'),
  seguimiento('Seguimiento'),
  institucion('Institución');

  const WebSection(this.label);

  final String label;
}

/// Lo que el shell ofrece a las pantallas: ir a otra página, abrir el menú
/// (cuando es un cajón) y cerrar la sesión.
class WebNav extends InheritedWidget {
  const WebNav({
    required this.current,
    required this.session,
    required this.go,
    required this.openMenu,
    required this.open,
    required this.back,
    required this.hasDetail,
    required this.refreshBadges,
    required this.badges,
    required super.child,
    super.key,
  });

  final WebPage current;

  /// Quién tiene abierta la sesión del panel.
  final Session session;
  final void Function(WebPage page) go;
  final VoidCallback openMenu;

  /// Abre una pantalla de detalle encima de la página actual (el reporte, la
  /// persona, la confirmación de una alerta). Ir a otra página del menú la cierra.
  final void Function(Widget screen) open;

  /// Cierra el detalle y vuelve a la página.
  final VoidCallback back;
  final bool hasDetail;

  /// Vuelve a contar lo que muestran las insignias del menú.
  final VoidCallback refreshBadges;

  /// Contadores del menú: reportes sin revisar, avisos por decidir.
  final ValueNotifier<Map<WebPage, int>> badges;

  static WebNav of(BuildContext context) {
    final WebNav? nav = context.dependOnInheritedWidgetOfExactType<WebNav>();
    assert(nav != null, 'No hay un WebNav arriba en el árbol de widgets.');
    return nav!;
  }

  @override
  bool updateShouldNotify(WebNav oldWidget) =>
      oldWidget.current != current || oldWidget.hasDetail != hasDetail;
}

/// El marco de cada pantalla: encabezado blanco con título y acciones, y debajo
/// el cuerpo con scroll (`.top` y `.body`).
class WebPageFrame extends StatelessWidget {
  const WebPageFrame({
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bool drawer = WebBreakpoints.isDrawer(context);
    final bool narrow = WebBreakpoints.isNarrow(context);
    final double gutter = narrow ? 20 : 32;

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: gutter, vertical: narrow ? 16 : 18),
          decoration: const BoxDecoration(
            color: WebColors.card,
            border: Border(bottom: BorderSide(color: WebColors.line)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (drawer)
                    IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: WebNav.of(context).openMenu,
                      icon: const Icon(Icons.menu, color: WebColors.ink),
                    ),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: WebText.title),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(subtitle!, style: WebText.sub),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < children.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 20),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// «Volver» para las pantallas de detalle.
class WebBackButton extends StatelessWidget {
  const WebBackButton({this.label = 'Volver', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return WebButton(
      label: label,
      secondary: true,
      icon: Icons.arrow_back,
      onPressed: WebNav.of(context).back,
    );
  }
}
