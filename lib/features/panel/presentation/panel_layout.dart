import 'package:flutter/widgets.dart';

/// Ancho a partir del cual el panel se dibuja como panel.
///
/// Las mismas cuatro pantallas viven en dos sitios muy distintos: el computador
/// de coordinación, donde caben dos columnas y una tabla de seis campos, y el
/// celular del administrador, donde no cabe ninguna de las dos cosas.
///
/// Se resuelve con una sola decisión y no duplicando las pantallas. Duplicarlas
/// significaría que el día que cambie el tablero hay que acordarse de cambiarlo
/// dos veces, y en una emergencia la versión olvidada es la que alguien está
/// mirando.
abstract final class PanelLayout {
  /// 720 lógicos: por debajo no caben dos columnas sin que el texto se parta en
  /// sílabas. Una tableta en horizontal queda por encima y ve el panel completo,
  /// que es lo correcto.
  static const double compactBreakpoint = 720;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  /// Margen lateral. En el celular se aprieta: cada píxel de borde es un dígito
  /// menos del conteo de personas a salvo.
  static double gutter(BuildContext context) => isCompact(context) ? 16 : 24;

  /// Margen del encabezado de una pestaña.
  ///
  /// Suma el alto de la barra de estado del celular, donde estas pantallas
  /// llegan hasta el borde de arriba. En el computador ese hueco es cero y no
  /// cambia nada.
  static EdgeInsets headerPadding(BuildContext context) {
    final double side = gutter(context);
    return EdgeInsets.fromLTRB(
      side,
      side + MediaQuery.paddingOf(context).top,
      side,
      side,
    );
  }
}
