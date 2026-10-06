import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/session/user_role.dart';

/// Lo que el shell le ofrece a las pestañas: moverse entre ellas y saber cuántos
/// mensajes del colegio quedan sin leer.
///
/// Inicio necesita llevar al Mapa y a la Guía, pero no tiene por qué saber en
/// qué posición quedaron: pide la pestaña por su nombre y el shell resuelve.
class ShellScope extends InheritedWidget {
  const ShellScope({
    required this.openTab,
    required this.role,
    required this.chatUnread,
    required this.refreshChatUnread,
    required super.child,
    this.schoolName,
    super.key,
  });

  /// Abre la pestaña con esa etiqueta. Si no existe, no hace nada.
  final void Function(String label) openTab;

  final UserRole role;

  /// Mensajes del colegio sin leer, para la insignia del chat.
  final ValueListenable<int> chatUnread;

  /// El nombre del colegio, cuando ya se supo. Lo dice el servidor.
  final String? schoolName;

  /// Vuelve a preguntar cuántos hay: se llama al cerrar el chat.
  final VoidCallback refreshChatUnread;

  /// Estudiantes y acudientes abren el chat desde la cabecera; el colegio lo
  /// tiene como pestaña.
  bool get chatInHeader =>
      role == UserRole.estudiante || role == UserRole.acudiente;

  /// Una copia de este alcance sobre otro árbol. Las pantallas que se abren
  /// encima (el chat, una guía, los simulacros) son rutas nuevas y no cuelgan del
  /// shell: sin esto no podrían cambiar de pestaña ni saber el rol.
  Widget wrap(Widget child) => ShellScope(
        openTab: openTab,
        role: role,
        chatUnread: chatUnread,
        refreshChatUnread: refreshChatUnread,
        schoolName: schoolName,
        child: child,
      );

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.openTab != openTab ||
      oldWidget.role != role ||
      oldWidget.chatUnread != chatUnread ||
      oldWidget.schoolName != schoolName;
}

/// Abre una pantalla encima de la actual **sin perder el alcance del shell**.
///
/// Es lo que se usa para lo que se abre desde las pestañas: así la pantalla de
/// arriba sigue pudiendo, por ejemplo, llevar a otra pestaña o mostrar el chat.
Future<T?> pushInShell<T>(BuildContext context, WidgetBuilder builder) {
  final ShellScope? shell = ShellScope.maybeOf(context);
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (BuildContext context) =>
          shell == null ? builder(context) : shell.wrap(Builder(builder: builder)),
    ),
  );
}
