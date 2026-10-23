import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// `84 s` → `01:24`. Nunca negativo: un reloj de servidor adelantado no debe
/// mostrar un tiempo menor que cero.
String formatDrillTime(Duration elapsed) {
  final int seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final String rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// «Tu tiempo» en un simulacro: lo que lleva la persona desde que se emitió, y la
/// meta del colegio.
///
/// El reloj cuenta desde la hora de emisión que dice el servidor, no desde que se
/// abrió la pantalla: quien recibe el aviso un minuto tarde ya perdió ese minuto
/// y el resultado del simulacro tiene que reflejarlo.
class DrillTimer extends StatefulWidget {
  const DrillTimer({
    required this.startedAt,
    required this.goal,
    this.now = DateTime.now,
    super.key,
  });

  final DateTime startedAt;
  final Duration goal;

  /// El reloj, para poder probarlo.
  final DateTime Function() now;

  @override
  State<DrillTimer> createState() => _DrillTimerState();
}

class _DrillTimerState extends State<DrillTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration elapsed = widget.now().difference(widget.startedAt);
    final int goalMinutes = widget.goal.inMinutes;
    final String goalText =
        '$goalMinutes:${(widget.goal.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0x38000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'TU TIEMPO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
                Text(
                  formatDrillTime(elapsed),
                  key: const Key('tiempo-simulacro'),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const Text(
                'Meta del colegio',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              Text(
                'menos de $goalText',
                key: const Key('meta-simulacro'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
