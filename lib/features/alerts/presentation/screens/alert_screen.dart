import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../help/presentation/help_screen.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../student/presentation/screens/guided_route_screen.dart';
import '../../../student/presentation/screens/safe_check_in_screen.dart';
import '../../domain/alert.dart';
import '../../domain/alert_level.dart';
import '../../domain/safety_report.dart';
import '../widgets/alert_level_style.dart';
import '../widgets/alert_palette.dart';
import '../widgets/pulsing_icon.dart';
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
    final AlertPalette palette = AlertPalette.of(alert);

    return PopScope(
      // Una alerta no se quita con el botón de atrás: se responde.
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TopRow(alert: alert, palette: palette),
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
                      _Title(alert: alert, palette: palette),
                      const SizedBox(height: AppSpacing.lg),
                      _Instructions(alert: alert, style: style, palette: palette),
                      if (alert.coordinatorNote != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _CoordinatorNote(alert: alert, palette: palette),
                      ],
                    ],
                  ),
                ),
              ),
              _Actions(
                alert: alert,
                style: style,
                palette: palette,
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
  const _TopRow({required this.alert, required this.palette});

  final Alert alert;
  final AlertPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        0,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.topChipBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '● ${palette.topLabel}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: palette.topChipForeground,
              ),
            ),
          ),
          const Spacer(),
          Text(
            alert.issuedAtLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: palette.isLight ? FontWeight.w600 : FontWeight.w400,
              color: palette.foreground.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

/// El icono de la amenaza (con un latido), el título, el nivel y a quién cobija.
class _Title extends StatelessWidget {
  const _Title({required this.alert, required this.palette});

  final Alert alert;
  final AlertPalette palette;

  /// El título más corto se ve más grande: `SISMO` a 52, `LLUVIAS FUERTES` a 40.
  static double _titleSize(String title) {
    if (title.length <= 7) return 52;
    if (title.length <= 11) return 44;
    return 40;
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = palette.foreground;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        PulsingIcon(
          icon: hazardIcon(alert.hazard),
          color: fg,
          pulse: !palette.isLight,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          alert.title,
          key: const Key('titulo-alerta'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _titleSize(alert.title),
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: 0.5,
            color: fg,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _LevelChip(alert: alert, palette: palette),
        const SizedBox(height: AppSpacing.md),
        Text(
          _scopeLine(alert),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: fg.withValues(alpha: 0.95)),
        ),
      ],
    );
  }

  static String _scopeLine(Alert alert) {
    final String? point = alert.meetingPoint;
    if (point == null) return alert.scope;
    return '${alert.scope} · Punto $point';
  }
}

/// «Alerta roja · Evacuar ya»: el nivel dicho con palabras, además del color.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.alert, required this.palette});

  final Alert alert;
  final AlertPalette palette;

  @override
  Widget build(BuildContext context) {
    final String text = alert.isDrill
        ? 'Simulacro programado · ${alert.scope}'
        : 'Alerta ${alert.level.label.toLowerCase()} · ${alert.level.meaning}';
    final (Color background, Color foreground) = palette.levelChipFromLevel
        ? switch (alert.level) {
            AlertLevel.amarilla => (AppColors.levelYellow, AppColors.ink),
            AlertLevel.naranja => (const Color(0xFFF28C28), AppColors.ink),
            AlertLevel.roja => (AppColors.levelRed, Colors.white),
          }
        : (palette.levelChipBackground, palette.levelChipForeground);

    return Container(
      key: const Key('nivel-alerta'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}

/// «Qué hacer ahora»: los pasos, numerados y legibles de lejos.
class _Instructions extends StatelessWidget {
  const _Instructions({
    required this.alert,
    required this.style,
    required this.palette,
  });

  final Alert alert;
  final AlertLevelStyle style;
  final AlertPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color fg = palette.foreground;
    // Sobre un fondo claro los números van en el color oscuro; sobre uno de
    // color, en blanco con el número del color del fondo.
    final Color numberBackground = palette.isLight ? palette.accent : Colors.white;
    final Color numberForeground = palette.isLight ? Colors.white : palette.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'QUÉ HACER AHORA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: fg,
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
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: numberBackground,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: numberForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      alert.instructions[i],
                      style: TextStyle(fontSize: 15, height: 1.4, color: fg),
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
  const _CoordinatorNote({required this.alert, required this.palette});

  final Alert alert;
  final AlertPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.foreground.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        '${alert.issuedBy ?? 'Coordinación'}: ${alert.coordinatorNote}',
        style: AppTextStyles.caption.copyWith(color: palette.foreground),
      ),
    );
  }
}

/// Botones del pie y la nota de qué hace el celular con esta alerta.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.alert,
    required this.style,
    required this.palette,
    required this.student,
    required this.onAcknowledge,
    required this.onRespond,
    required this.onResponded,
  });

  final Alert alert;
  final AlertLevelStyle style;
  final AlertPalette palette;
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
              foreground: palette.accent,
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
              background: palette.isLight ? AppColors.ink : Colors.white,
              foreground: palette.isLight ? AppColors.onBrand : palette.accent,
              onPressed: onAcknowledge,
            )
          else ...<Widget>[
            _AlertButton(
              label: style.primaryAction,
              icon: Icons.check,
              background: Colors.white,
              foreground: palette.accent,
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
              color: palette.foreground.withValues(alpha: 0.8),
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
