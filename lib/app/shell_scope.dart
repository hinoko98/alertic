import 'package:flutter/widgets.dart';

/// Permite que una pestaña mande a otra sin conocer la barra de navegación.
///
/// Inicio necesita llevar al Mapa y a la Guía, pero no tiene por qué saber en
/// qué posición quedaron: pide la pestaña por su nombre y el shell resuelve.
class ShellScope extends InheritedWidget {
  const ShellScope({
    required this.openTab,
    required super.child,
    super.key,
  });

  /// Abre la pestaña con esa etiqueta. Si no existe, no hace nada.
  final void Function(String label) openTab;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.openTab != openTab;
}
