import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/alert.dart';
import '../../domain/safety_report.dart';
import '../widgets/alert_level_style.dart';

/// Pantallas 07, 08 y 09: la alerta que recibe la persona.
///
/// Es una sola pantalla para los tres niveles. Lo que cambia (color, tamaño del
/// título, acciones) lo decide [AlertLevelStyle.of]; lo que no cambia es el
/// orden de lectura: qué pasa, a quién cobija, qué hacer, y una acción.
class AlertScreen extends StatelessWidget {
  const AlertScreen({
    required this.alert,
    required this.onAcknowledge,
    this.onRespond,
    super.key,
  });

  final Alert alert;

  /// La persona leyó la alerta. En amarilla y naranja cierra la pantalla.
  final VoidCallback onAcknowledge;

  /// Solo en roja: responde si está bien o necesita ayuda.
  final ValueChanged<SafetyStatus>? onRespond;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(alert: alert, style: style),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!style.isFullBleed) ...<Widget>[
                        Text(
                          'QUÉ HACER',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _Instructions(alert: alert, style: style),
                      if (alert.coordinatorNote != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        _CoordinatorNote(alert: alert, style: style),
                      ],
                    ],
                  ),
                ),
              ),
              _Actions(
                style: style,
                onAcknowledge: onAcknowledge,
                onRespond: onRespond,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja superior: nivel, hora, qué pasa y a quién cobija.
class _Header extends StatelessWidget {
  const _Header({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: style.headerColor,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(style.icon, size: 18, color: style.headerForeground),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'ALERTA ${alert.level.label} · ${alert.issuedAtLabel}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: style.headerForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            alert.title,
            style: TextStyle(
              fontSize: style.titleSize,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
              color: style.headerForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _scopeLine(alert),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: style.headerForeground,
            ),
          ),
        ],
      ),
    );
  }

  static String _scopeLine(Alert alert) {
    final String scope = alert.scope.toUpperCase();
    final String? point = alert.meetingPoint;
    if (point == null) {
      return '$scope · ${alert.level.meaning.toUpperCase()}';
    }
    return '$scope · PUNTO $point';
  }
}

/// Los pasos, numerados. En roja se leen de lejos y de corrido.
class _Instructions extends StatelessWidget {
  const _Instructions({required this.alert, required this.style});

  final Alert alert;
  final AlertLevelStyle style;

  @override
  Widget build(BuildContext context) {
    final bool urgent = alert.level.requiresResponse;
    final Color divider = style.isFullBleed
        ? style.bodyForeground.withValues(alpha: 0.35)
        : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < alert.instructions.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: urgent
                ? Text(
                    '${i + 1}. ${alert.instructions[i].toUpperCase()}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: style.bodyForeground,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: style.bodyForeground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          alert.instructions[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: style.bodyForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ],
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
      color: style.isFullBleed
          ? style.bodyForeground.withValues(alpha: 0.12)
          : AppColors.surfaceAlt,
      padding: const EdgeInsets.all(AppSpacing.md),
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
    required this.style,
    required this.onAcknowledge,
    required this.onRespond,
  });

  final AlertLevelStyle style;
  final VoidCallback onAcknowledge;
  final ValueChanged<SafetyStatus>? onRespond;

  @override
  Widget build(BuildContext context) {
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
        children: <Widget>[
          if (secondary == null)
            _AlertButton(
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
              background: AppColors.surface,
              foreground: AppColors.ink,
              onPressed: () => onRespond?.call(SafetyStatus.safe),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AlertButton(
              label: secondary,
              icon: Icons.error_outline,
              background: style.bodyColor,
              foreground: AppColors.onBrand,
              borderColor: AppColors.onBrand,
              onPressed: () => onRespond?.call(SafetyStatus.needsHelp),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            style.footnote,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  style.isFullBleed ? style.bodyForeground : AppColors.inkMuted,
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
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color? border = borderColor;

    return Material(
      color: background,
      shape: border == null
          ? null
          : Border.fromBorderSide(BorderSide(color: border)),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      fontSize: 15,
                      color: foreground,
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
