import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/server_status_badge.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';

/// Pantallas 02 a 05: la bienvenida, en cuatro pasos que se deslizan.
///
/// 1. Qué es ALERTIC. 2. Te avisa al instante. 3. Te guía a un lugar seguro.
/// 4. Tu familia sabe que estás bien. «Saltar» y «Empezar» llevan a «¿Quién
/// eres?».
///
/// **Sin nombre de colegio**: la misma pantalla sirve para cualquier institución
/// que adopte ALERTIC. El colegio aparece cuando la persona escribe el código de
/// su carné y el servidor lo reconoce.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const int _pageCount = 4;
  static const Duration _slide = Duration(milliseconds: 280);

  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(page, duration: _slide, curve: Curves.easeOut);
  }

  void _next() {
    if (_isLast) {
      _start();
    } else {
      _goTo(_page + 1);
    }
  }

  void _start() => Navigator.of(context).pushNamed(AppRoutes.whoAreYou);

  @override
  Widget build(BuildContext context) {
    // «Atrás» del sistema retrocede una pantalla de la bienvenida en vez de
    // cerrar la app.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(
                page: _page,
                onBack: () => _goTo(_page - 1),
                onSkip: _start,
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (int page) => setState(() => _page = page),
                  children: const <Widget>[
                    _Slide(
                      title: 'Bienvenido a ALERTIC',
                      body:
                          'Una app para que toda la comunidad educativa sepa '
                          'qué hacer cuando hay una emergencia en el colegio.',
                      illustration: _WhatIsIllustration(),
                      extra: _HazardGrid(hazards: Hazard.values),
                    ),
                    _Slide(
                      title: 'Te avisa al instante',
                      body:
                          'Cuando el colegio emite una alerta, tu celular '
                          'suena aunque esté en silencio y te dice qué hacer en '
                          'ese momento.',
                      illustration: _AlertIllustration(),
                    ),
                    _Slide(
                      title: 'Te guía a un lugar seguro',
                      body:
                          'Un mapa del colegio muestra dónde estás en tiempo '
                          'real y el camino más seguro hasta tu punto de '
                          'encuentro.',
                      illustration: _MapIllustration(),
                    ),
                    _Slide(
                      title: 'Tu familia sabe que estás bien',
                      body:
                          'Con un toque confirmas que estás a salvo y avisamos '
                          'a tu familia y a tu docente. Si necesitas ayuda, '
                          'también llega al instante.',
                      illustration: _FamilyIllustration(),
                    ),
                  ],
                ),
              ),
              _Footer(
                page: _page,
                pageCount: _pageCount,
                onNext: _next,
                onHaveAccount: () =>
                    Navigator.of(context).pushNamed(AppRoutes.signIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La marca a la izquierda (o la flecha de volver) y «Saltar» a la derecha.
/// En la última pantalla ya no hay nada que saltar.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            if (page == 0)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 22,
                      color: AppColors.brand,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              )
            else
              IconButton(
                tooltip: 'Atrás',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              ),
            const Spacer(),
            if (page < 3)
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: AppColors.inkMuted,
                ),
                child: const Text(
                  'Saltar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Los puntos de avance y el botón. «Ya tengo cuenta» (docentes y coordinación,
/// que entran con la cuenta del colegio y no con un código) va solo en la
/// primera pantalla para no estorbar el resto del recorrido.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.pageCount,
    required this.onNext,
    required this.onHaveAccount,
  });

  final int page;
  final int pageCount;
  final VoidCallback onNext;
  final VoidCallback onHaveAccount;

  @override
  Widget build(BuildContext context) {
    final bool last = page == pageCount - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: 'Pantalla ${page + 1} de $pageCount',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == page
                            ? AppColors.brand
                            : const Color(0xFFD5DAE0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: last ? 'Empezar' : 'Siguiente',
            onPressed: onNext,
          ),
          if (last) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Ten a mano el código que te entrega tu colegio.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
          if (page == 0)
            TextButton(
              onPressed: onHaveAccount,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: AppColors.inkMuted,
              ),
              child: const Text(
                'Ya tengo cuenta',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una pantalla de la bienvenida: la ilustración arriba, ocupando lo que sobre,
/// y el título y el texto abajo. Si el celular es bajo, todo se desplaza.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.title,
    required this.body,
    required this.illustration,
    this.extra,
  });

  final String title;
  final String body;
  final Widget illustration;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(child: illustration),
                    ),
                  ),
                  Text(title, style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(body, style: AppTextStyles.body),
                  if (extra != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    extra!,
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El círculo grande de fondo suave que sostiene cada ilustración.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.child,
    this.color = AppColors.brandSoft,
    this.size = 280,
  });

  final Widget child;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );
  }
}

class _WhatIsIllustration extends StatelessWidget {
  const _WhatIsIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _Disc(
          size: 140,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x2EB3263A),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                width: 98,
                height: 98,
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Pill('Alertas tempranas', tone: PillTone.brand),
        const SizedBox(height: AppSpacing.md),
        // Dice con quién habla la app: servidor, y si responde.
        const ServerStatusBadge(),
      ],
    );
  }
}

class _AlertIllustration extends StatelessWidget {
  const _AlertIllustration();

  @override
  Widget build(BuildContext context) {
    return _Disc(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 28,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x4DB3263A),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: 232,
            margin: const EdgeInsets.only(top: 64),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x291C2731),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // La insignia cede si el texto del sistema es grande.
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Pill('● ALERTA · SISMO', tone: PillTone.brand),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('ahora', style: AppTextStyles.caption),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Evacúa al Punto A · Cancha',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Agáchate, cúbrete y sujétate. Cuando pare, sal sin correr.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapIllustration extends StatelessWidget {
  const _MapIllustration();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mapa con tu ubicación y la ruta al punto de encuentro',
      image: true,
      child: ExcludeSemantics(
        child: ClipOval(
          child: SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(painter: _MapPainter()),
          ),
        ),
      ),
    );
  }
}

/// El mapa de muestra: manzanas, el punto de encuentro «A» y la ruta desde la
/// persona. Se dibuja en una cuadrícula de 300 × 300 y se escala al tamaño real.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300, size.height / 300);

    final Paint fill = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 300),
      fill..color = const Color(0xFFE8EEE4),
    );
    fill.color = const Color(0xFFD2E2CA);
    canvas.drawCircle(const Offset(60, 80), 40, fill);
    canvas.drawCircle(const Offset(250, 230), 44, fill);

    final Paint blockFill = Paint()..color = Colors.white;
    final Paint blockLine = Paint()
      ..color = const Color(0xFFAEB6BE)
      ..style = PaintingStyle.stroke;
    for (final Rect block in const <Rect>[
      Rect.fromLTWH(150, 60, 90, 70),
      Rect.fromLTWH(70, 150, 70, 60),
    ]) {
      final RRect rounded = RRect.fromRectAndRadius(
        block,
        const Radius.circular(6),
      );
      canvas.drawRRect(rounded, blockFill);
      canvas.drawRRect(rounded, blockLine);
    }

    // La zona segura: relleno verde con borde punteado.
    final Path zone = Path()
      ..moveTo(120, 230)
      ..lineTo(210, 220)
      ..lineTo(215, 290)
      ..lineTo(125, 295)
      ..close();
    canvas.drawPath(zone, Paint()..color = const Color(0xFFCFE8D8));
    final Paint dash = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in zone.computeMetrics()) {
      double at = 0;
      while (at < m.length) {
        canvas.drawPath(m.extractPath(at, at + 6), dash);
        at += 10;
      }
    }

    final Path route = Path()
      ..moveTo(190, 130)
      ..lineTo(170, 165)
      ..lineTo(160, 205)
      ..lineTo(168, 252);
    Paint line(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(route, line(Colors.white, 11));
    canvas.drawPath(route, line(AppColors.brand, 5));

    // El punto de encuentro.
    canvas.drawCircle(
      const Offset(168, 256),
      15,
      Paint()..color = AppColors.success,
    );
    canvas.drawCircle(
      const Offset(168, 256),
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final TextPainter letter = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letter.paint(
      canvas,
      Offset(168 - letter.width / 2, 256 - letter.height / 2),
    );

    // Tú: el punto azul con su halo.
    const Color blue = Color(0xFF2F6FD6);
    canvas.drawCircle(
      const Offset(190, 130),
      22,
      Paint()..color = blue.withValues(alpha: 0.2),
    );
    canvas.drawCircle(const Offset(190, 130), 9, Paint()..color = blue);
    canvas.drawCircle(
      const Offset(190, 130),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FamilyIllustration extends StatelessWidget {
  const _FamilyIllustration();

  @override
  Widget build(BuildContext context) {
    return _Disc(
      color: AppColors.successSoft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x4D1F6B45),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check, size: 36, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 224,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1F1C2731),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: <Widget>[
                _Notified(initial: 'M', name: 'Mamá', status: 'Avisada'),
                Divider(height: 1, color: AppColors.border),
                _Notified(
                  initial: 'D',
                  name: 'Director de grupo',
                  status: 'Avisado',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notified extends StatelessWidget {
  const _Notified({
    required this.initial,
    required this.name,
    required this.status,
  });

  final String initial;
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Las cuatro amenazas que cubre el sistema, en dos columnas.
class _HazardGrid extends StatelessWidget {
  const _HazardGrid({required this.hazards});

  final List<Hazard> hazards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final Hazard hazard in hazards)
          SizedBox(
            width:
                (MediaQuery.sizeOf(context).width -
                    AppSpacing.screenGutter * 2 -
                    AppSpacing.sm) /
                2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(hazardIcon(hazard), size: 16, color: AppColors.brand),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _label(hazard),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _label(Hazard hazard) => switch (hazard) {
    Hazard.lluvia => 'Lluvias',
    Hazard.inundacion => 'Inundación',
    Hazard.sismo => 'Sismos',
    Hazard.incendio => 'Incendios',
  };
}
