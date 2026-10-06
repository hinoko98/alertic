import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'screen_header.dart';

/// El esqueleto de una pantalla: cabecera arriba, el cuerpo que se desplaza y,
/// si hace falta, un pie fijo (el botón de acción).
class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.body,
    this.subtitle,
    this.onBack,
    this.showHelp = true,
    this.actions = const <Widget>[],
    this.bottom,
    this.background = AppColors.background,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showHelp;
  final List<Widget> actions;

  /// Lo que ocupa el resto de la pantalla.
  final Widget body;

  /// Fijo debajo del cuerpo, sobre la barra de navegación.
  final Widget? bottom;

  final Color background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: <Widget>[
          AppScreenHeader(
            title: title,
            subtitle: subtitle,
            onBack: onBack,
            showHelp: showHelp,
            actions: actions,
          ),
          Expanded(child: body),
          ?bottom,
        ],
      ),
    );
  }
}
