import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Pantalla 00: la entrada animada.
///
/// El escudo aparece, late y las ondas se expanden: dice «alerta» y «protección»
/// en tres segundos, mientras la app termina de arrancar. Tocar la pantalla
/// salta la espera.
class SplashScreen extends StatefulWidget {
  const SplashScreen({this.duration = const Duration(milliseconds: 2800), super.key});

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _continue);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _continue,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, _) => _Logo(t: _controller.value),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 36),
                  child: Column(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Preparando tu información…',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.t});

  /// Avance de la animación, de 0 a 1.
  final double t;

  @override
  Widget build(BuildContext context) {
    // El escudo entra en el primer tramo y después late suavemente.
    final double appear = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
    final double beat = 1 + 0.04 * (t > 0.35 ? (1 - ((t * 6) % 1 - 0.5).abs() * 2) : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (final double offset in const <double>[0, 0.33, 0.66])
                _Wave(progress: ((t * 1.6) + offset) % 1, visible: t > 0.2),
              Transform.scale(
                scale: appear * beat,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 52,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: (t / 0.5).clamp(0.0, 1.0),
          child: const Column(
            children: <Widget>[
              Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Alertas tempranas para tu colegio',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Wave extends StatelessWidget {
  const _Wave({required this.progress, required this.visible});

  final double progress;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final double size = 104 + 116 * progress;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5 * (1 - progress)),
          width: 2,
        ),
      ),
    );
  }
}
