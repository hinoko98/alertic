import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../help/presentation/help_screen.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../student/presentation/screens/guided_route_screen.dart';
import '../../../student/presentation/screens/safe_check_in_screen.dart';
import '../../domain/alert.dart';
import '../../domain/safety_report.dart';
import '../widgets/alert_level_style.dart';
import '../widgets/hazard_icon.dart';

/// Pantallas 07: la alerta que recibe la persona.
///
/// Es una sola pantalla para los tres niveles. Lo que cambia (color, tamaño del
/// título, acciones) lo decide [AlertLevelStyle.of]; lo que no cambia es el
/// orden de lectura: qué pasa, a quién cobija, qué hacer, y las acciones.
///
/// A un **estudiante** en alerta roja se le ofrecen tres cosas, todas a un toque:
/// ver su ruta, decir que está a salvo y pedir ayuda. Cada una abre su pantalla;
/// cuando una respuesta queda registrada, [onResponded] deja de pedirle que
/// responda.
class AlertScreen extends StatelessWidget {
  const AlertScreen({
    required this.alert,
    required this.onAcknowledge,
    this.onRespond,
    this.student,
    this.onResponded,
    super.key,
  });

  final Alert alert;

  /// La persona leyó la alerta. En amarilla y naranja cierra la pantalla.
  final VoidCallback onAcknowledge;

  /// Solo en roja y para quien no es estudiante: responde si está bien o necesita
  /// ayuda.
  final ValueChanged<SafetyStatus>? onRespond;

  /// El estudiante que recibe la alerta, si lo es. Con él, la roja ofrece la
  /// ruta, «estoy a salvo» y «necesito ayuda».
  final StudentEnrollment? student;

  /// El estudiante ya respondió: se puede cerrar la alerta.
  final VoidCallback? onResponded;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(alert.level);

    return PopScope(
      // Una alerta no se quita con el botón de atrás: se responde.
      canPop: false,
      child: Scaffold(
        backgroundColor: style.bodyColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TopRow(alert: alert, style: style),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.md,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: <Widget>[
                      _Title(alert: alert, style: style),
                      const SizedBox(height: AppSpacing.lg),
                      _Instructions(alert: alert, style: style),
                      if (alert.coordinatorNote != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _CoordinatorNote(alert: alert, style: style),
                      ],
                    ],
                  ),
                ),
              ),
              _Actions(
                alert: alert,
                style: style,
                student: student,
                onAcknowledge: onAcknowledge,
                onRespond: onRespond,
                onResponded: onResponded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja superior: «ALERTA ACTIVA» y la hora.
class _TopRow extends StatelessWidget {
  const _TopRow({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        0,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: style.isFullBleed ? Colors.white : style.headerColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.circle,
                  size: 8,
                  color: style.isFullBleed ? style.headerColor : style.headerForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  alert.isDrill ? 'SIMULACRO' : 'ALERTA ${alert.level.label}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: style.isFullBleed ? style.headerColor : style.headerForeground,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            alert.issuedAtLabel,
            style: TextStyle(fontSize: 12, color: style.bodyForeground.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// El círculo con el icono de la amenaza, el título y a quién cobija.
class _Title extends StatelessWidget {
  const _Title({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    final Color fg = style.bodyForeground;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fg.withValues(alpha: 0.18),
            border: Border.all(color: fg.withValues(alpha: 0.6), width: 2),
          ),
          child: Icon(hazardIcon(alert.hazard), size: 34, color: fg),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          alert.title,
          key: const Key('titulo-alerta'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: style.titleSize,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.5,
            color: fg,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _scopeLine(alert),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.85)),
        ),
      ],
    );
  }

  static String _scopeLine(Alert alert) {
    final String? point = alert.meetingPoint;
    if (point == null) return '${alert.scope} · ${alert.level.meaning}';
    return '${alert.scope} · Punto $point';
  }
}

/// «Qué hacer ahora»: los pasos, numerados y legibles de lejos.
class _Instructions extends StatelessWidget {
  const _Instructions({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    final Color fg = style.bodyForeground;
    final bool onColor = style.isFullBleed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: onColor ? Colors.black.withValues(alpha: 0.2) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: onColor ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'QUÉ HACER AHORA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: fg.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < alert.instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: onColor ? Colors.white : style.headerColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: onColor ? style.headerColor : style.headerForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      alert.instructions[i],
                      style: TextStyle(
                        fontSize: alert.level.requiresResponse ? 16 : 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Nota de coordinación: por qué se emitió la alerta.
class _CoordinatorNote extends StatelessWidget {
  const _CoordinatorNote({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: style.isFullBleed
            ? style.bodyForeground.withValues(alpha: 0.14)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        '${alert.issuedBy ?? 'Coordinación'}: ${alert.coordinatorNote}',
        style: AppTextStyles.caption.copyWith(color: style.bodyForeground),
      ),
    );
  }
}

/// Botones del pie y la nota de qué hace el celular con esta alerta.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.alert,
    required this.style,
    required this.student,
    required this.onAcknowledge,
    required this.onRespond,
    required this.onResponded,
  });

  final Alert alert;
  final AlertLevelStyle style;
  final StudentEnrollment? student;
  final VoidCallback onAcknowledge;
  final ValueChanged<SafetyStatus>? onRespond;
  final VoidCallback? onResponded;

  @override
  Widget build(BuildContext context) {
    final StudentEnrollment? who = student;
    final bool studentMustRespond = who != null && alert.level.requiresResponse;
    final String? secondary = style.secondaryAction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (studentMustRespond) ...<Widget>[
            _AlertButton(
              key: const Key('ver-mi-ruta'),
              label: 'Ver mi ruta de evacuación',
              icon: Icons.map_outlined,
              background: Colors.white,
              foreground: style.headerColor,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      GuidedRouteScreen(student: who, onResponded: onResponded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _AlertButton(
                    key: const Key('estoy-a-salvo'),
                    label: 'Estoy a salvo',
                    background: Colors.transparent,
                    foreground: AppColors.onBrand,
                    border: Colors.white70,
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => SafeCheckInScreen(
                          alert: alert,
                          student: who,
                          onResponded: onResponded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AlertButton(
                    key: const Key('necesito-ayuda-alerta'),
                    label: 'Necesito ayuda',
                    background: Colors.black.withValues(alpha: 0.35),
                    foreground: AppColors.onBrand,
                    onPressed: () async {
                      final bool? sent = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (BuildContext context) =>
                              HelpScreen(alert: alert, classroom: who.classroom),
                        ),
                      );
                      if (sent == true) onResponded?.call();
                    },
                  ),
                ),
              ],
            ),
          ] else if (secondary == null)
            _AlertButton(
              key: const Key('alerta-entendido'),
              label: style.primaryAction,
              icon: Icons.check,
              background: AppColors.ink,
              foreground: AppColors.onBrand,
              onPressed: onAcknowledge,
            )
          else ...<Widget>[
            _AlertButton(
              label: style.primaryAction,
              icon: Icons.check,
              background: Colors.white,
              foreground: style.headerColor,
              onPressed: () => onRespond?.call(SafetyStatus.safe),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AlertButton(
              label: secondary,
              icon: Icons.error_outline,
              background: Colors.black.withValues(alpha: 0.35),
              foreground: AppColors.onBrand,
              onPressed: () => onRespond?.call(SafetyStatus.needsHelp),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            style.footnote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: style.isFullBleed ? Colors.white70 : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.icon,
    this.border,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        onTap: onPressed,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
