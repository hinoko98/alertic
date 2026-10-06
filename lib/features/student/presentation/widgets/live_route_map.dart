import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/location/geo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Un punto con nombre en el mapa.
class MapMarker {
  const MapMarker({required this.point, required this.label});

  final GeoPoint point;

  /// Lo que se escribe junto al punto: `P1`.
  final String label;
}

/// El mapa en vivo: la persona (punto azul con su margen de error y hacia dónde
/// camina), el punto de encuentro y la ruta entre los dos.
///
/// **No dibuja edificios ni calles que nadie midió.** Es un plano de coordenadas
/// reales —la ubicación del GPS y la del punto que puso coordinación— con escala y
/// norte, que funciona sin internet. Un plano inventado, en una evacuación, es
/// peor que ninguno.
///
/// Con [followMe] la cámara se centra en la persona y se acerca a medida que
/// llega, como un GPS. Sin él se ve todo junto.
class LiveRouteMap extends StatelessWidget {
  const LiveRouteMap({
    required this.target,
    this.me,
    this.accuracy,
    this.heading,
    this.trail = const <GeoPoint>[],
    this.others = const <MapMarker>[],
    this.followMe = false,
    this.height = 260,
    super.key,
  });

  /// Adónde hay que ir.
  final MapMarker target;

  /// Dónde está la persona; null si todavía no hay ubicación.
  final GeoPoint? me;

  /// Margen de error del GPS, en metros.
  final double? accuracy;

  /// Hacia dónde camina, en grados desde el norte.
  final double? heading;

  /// Por dónde ha pasado (se pinta en gris).
  final List<GeoPoint> trail;

  /// Otros puntos del colegio, en pequeño.
  final List<MapMarker> others;

  final bool followMe;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: me == null
          ? 'Mapa. Punto de encuentro ${target.label}. Sin tu ubicación todavía.'
          : 'Mapa en vivo. Estás a ${Geo.distanceLabel(Geo.distance(me!, target.point))} '
              'del punto ${target.label}, hacia el ${Geo.compassWord(Geo.bearing(me!, target.point))}.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E6),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: CustomPaint(
            painter: _MapPainter(
              target: target,
              me: me,
              accuracy: accuracy,
              heading: heading,
              trail: trail,
              others: others,
              followMe: followMe,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.target,
    required this.me,
    required this.accuracy,
    required this.heading,
    required this.trail,
    required this.others,
    required this.followMe,
  });

  final MapMarker target;
  final GeoPoint? me;
  final double? accuracy;
  final double? heading;
  final List<GeoPoint> trail;
  final List<MapMarker> others;
  final bool followMe;

  /// Radio dentro del cual se da por llegado, en metros.
  static const double _arrival = 15;

  @override
  void paint(Canvas canvas, Size size) {
    // El origen del plano es el punto de encuentro: todo se mide desde él.
    final GeoPoint origin = target.point;
    Offset m(GeoPoint p) {
      final ({double x, double y}) v = Geo.toMeters(origin, p);
      return Offset(v.x, -v.y); // en pantalla el norte es hacia arriba
    }

    // Qué rectángulo (en metros) se ve.
    final Offset targetM = m(target.point);
    late Offset center;
    late double halfSpan; // metros desde el centro hasta el borde corto
    final double shortSide = math.min(size.width, size.height);

    if (me == null) {
      center = targetM;
      halfSpan = 60;
    } else if (followMe) {
      center = m(me!);
      final double far = (m(me!) - targetM).distance;
      // Un margen para que el punto de llegada (con su zona) quede entero a la vista.
      halfSpan = math.max(far * 1.45 + 12, 40);
    } else {
      final Offset meM = m(me!);
      center = Offset((meM.dx + targetM.dx) / 2, (meM.dy + targetM.dy) / 2);
      final double extent = math.max(
        math.max((meM.dx - targetM.dx).abs(), (meM.dy - targetM.dy).abs()),
        40,
      );
      halfSpan = extent * 0.75 + 15;
    }

    final double scale = (shortSide / 2) / halfSpan; // píxeles por metro
    Offset toScreen(Offset meters) => Offset(
          size.width / 2 + (meters.dx - center.dx) * scale,
          size.height / 2 + (meters.dy - center.dy) * scale,
        );

    _grid(canvas, size, center, scale);

    // Zona de llegada.
    final Offset t = toScreen(targetM);
    canvas.drawCircle(
      t,
      _arrival * scale,
      Paint()..color = AppColors.success.withValues(alpha: 0.14),
    );
    _dashedCircle(canvas, t, _arrival * scale, AppColors.success);

    // Otros puntos del colegio, discretos.
    for (final MapMarker other in others) {
      final Offset o = toScreen(m(other.point));
      canvas.drawCircle(o, 5, Paint()..color = AppColors.ink);
      _label(canvas, other.label, o + const Offset(8, -7), AppColors.ink, 10);
    }

    // Lo que ya caminó, en gris.
    if (trail.length > 1) {
      final Path walked = Path()..moveTo(toScreen(m(trail.first)).dx, toScreen(m(trail.first)).dy);
      for (final GeoPoint p in trail.skip(1)) {
        final Offset s = toScreen(m(p));
        walked.lineTo(s.dx, s.dy);
      }
      canvas.drawPath(
        walked,
        Paint()
          ..color = const Color(0xFF9AA3AE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Lo que falta: de la persona al punto, en rojo.
    if (me != null) {
      final Offset a = toScreen(m(me!));
      _dashedLine(canvas, a, t, AppColors.brand);
    }

    // El punto de encuentro.
    canvas.drawCircle(t, 15, Paint()..color = AppColors.success);
    canvas.drawCircle(
      t,
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _label(canvas, target.label, t - Offset(_textWidth(target.label, 12, FontWeight.w900) / 2, 7),
        Colors.white, 12,
        weight: FontWeight.w900);

    // La persona.
    if (me != null) {
      final Offset a = toScreen(m(me!));
      final double accuracyPx = (accuracy ?? 0) * scale;
      if (accuracyPx > 8) {
        canvas.drawCircle(a, accuracyPx, Paint()..color = const Color(0xFF2F6FDE).withValues(alpha: 0.14));
      }
      if (heading != null) {
        _cone(canvas, a, heading!);
      }
      canvas.drawCircle(a, 9.5, Paint()..color = Colors.white);
      canvas.drawCircle(a, 7, Paint()..color = const Color(0xFF2F6FDE));
    }

    _northBadge(canvas, size);
    _scaleBar(canvas, size, scale);
  }

  /// Cuadrícula tenue cada 10, 20, 50 o 100 m, según el acercamiento.
  void _grid(Canvas canvas, Size size, Offset center, double scale) {
    final double step = _niceStep(60 / scale);
    final Paint line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    final double left = center.dx - size.width / 2 / scale;
    final double right = center.dx + size.width / 2 / scale;
    final double top = center.dy - size.height / 2 / scale;
    final double bottom = center.dy + size.height / 2 / scale;

    for (double x = (left / step).floorToDouble() * step; x <= right; x += step) {
      final double sx = size.width / 2 + (x - center.dx) * scale;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), line);
    }
    for (double y = (top / step).floorToDouble() * step; y <= bottom; y += step) {
      final double sy = size.height / 2 + (y - center.dy) * scale;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), line);
    }
  }

  static double _niceStep(double minMeters) {
    for (final double step in <double>[5, 10, 20, 50, 100, 200, 500, 1000]) {
      if (step >= minMeters) return step;
    }
    return 1000;
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final double length = (b - a).distance;
    if (length < 1) return;
    final Offset dir = (b - a) / length;
    const double dash = 12;
    const double gap = 7;
    for (double d = 0; d < length; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, length), paint);
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Color color) {
    if (radius < 4) return;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const int dashes = 28;
    for (int i = 0; i < dashes; i++) {
      final double start = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, math.pi / dashes, false, paint);
    }
  }

  /// El abanico que muestra hacia dónde camina la persona.
  void _cone(Canvas canvas, Offset at, double headingDegrees) {
    final double a = (headingDegrees - 90) * math.pi / 180;
    final Path cone = Path()
      ..moveTo(at.dx, at.dy)
      ..arcTo(Rect.fromCircle(center: at, radius: 34), a - 0.5, 1.0, false)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFF2F6FDE).withValues(alpha: 0.28));
  }

  void _northBadge(Canvas canvas, Size size) {
    final Offset c = Offset(size.width - 24, 24);
    canvas.drawCircle(c, 15, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      15,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke,
    );
    _label(canvas, 'N', c - const Offset(4.5, 8), AppColors.ink, 12, weight: FontWeight.w900);
  }

  void _scaleBar(Canvas canvas, Size size, double scale) {
    final double meters = _niceStep(40 / scale);
    final double px = meters * scale;
    final Offset start = Offset(14, size.height - 16);
    final Paint paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.5;
    canvas.drawLine(start, start + Offset(px, 0), paint);
    canvas.drawLine(start - const Offset(0, 4), start + const Offset(0, 4), paint);
    canvas.drawLine(start + Offset(px, -4), start + Offset(px, 4), paint);
    _label(canvas, '${meters.round()} m', start + Offset(px + 6, -7), AppColors.ink, 10,
        weight: FontWeight.w800);
  }

  double _textWidth(String text, double size, FontWeight weight) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size, {
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.me != me ||
      old.accuracy != accuracy ||
      old.heading != heading ||
      old.target.point != target.point ||
      old.trail.length != trail.length ||
      old.others.length != others.length ||
      old.followMe != followMe;
}
