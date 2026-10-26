import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Una pestaña del panel (comunidad, historial, protocolos, tablero) abierta
/// encima del panel del celular. Ya traen su propio título: aquí solo se les da
/// dónde apoyarse y un botón para volver.
class AdminSubpage extends StatelessWidget {
  const AdminSubpage({required this.child, super.key});

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
