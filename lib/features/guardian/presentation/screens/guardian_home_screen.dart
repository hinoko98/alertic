import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../domain/guardian_repository.dart';
import 'pickup_screen.dart';

/// Pantalla 16: el estado de los hijos durante una alerta.
///
/// La familia solo quiere saber una cosa, y la app tiene que contestarla sin
/// que toquen nada. Por eso el estado de cada hijo va arriba, y el mensaje más
/// importante —«no vengas al colegio todavía»— va antes que cualquier otra
/// cosa: un papá manejando hacia una evacuación estorba el operativo.
class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({required this.guardian, super.key});

  final GuardianEnrollment guardian;

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  List<ChildStatus> _children = <ChildStatus>[];
  String? _loadedForAlert;

  /// Sin esto, la primera carga no ocurría: en calma no hay alerta y comparar
  /// `null` con `null` daba «ya está cargado», dejando el indicador girando.
  bool _hasLoaded = false;
  bool _loading = true;

  /// Última consulta pedida.
  ///
  /// Si la alerta llega mientras la consulta «en calma» va en camino, la vieja
  /// puede contestar de última y pisar la nueva: el acudiente vería a sus hijos
  /// «sin confirmar» justo durante la emergencia. Se descarta toda respuesta
  /// que ya no corresponda a lo último pedido.
  Object? _pendingRequest;

  StreamSubscription<LiveChange>? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cuando uno de sus hijos confirma, la pantalla cambia sola. El servidor
    // solo avisa de los hijos de esta persona, no de los de nadie más.
    _live ??= AppScope.of(context).liveUpdates.changes
        .where((LiveChange change) => change == LiveChange.myChildren)
        .listen((_) {
      if (_hasLoaded) {
        unawaited(_load(_loadedForAlert));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    super.dispose();
  }

  Future<void> _load(String? alertId) async {
    final Object request = Object();
    _pendingRequest = request;

    try {
      final List<ChildStatus> children =
          await AppScope.of(context).guardianRepository!.loadChildren(alertId);
      if (mounted && identical(_pendingRequest, request)) {
        setState(() {
          _children = children;
          _loadedForAlert = alertId;
          _hasLoaded = true;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'estado de los hijos');
      if (mounted && identical(_pendingRequest, request)) {
        setState(() {
          _hasLoaded = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<Alert?>(
          stream: scope.alertRepository.watchActiveAlert(),
          builder: (BuildContext context, AsyncSnapshot<Alert?> snapshot) {
            final Alert? active = snapshot.data;

            // Cuando cambia la alerta hay que volver a preguntar por los hijos:
            // el estado de cada uno es por alerta.
            if (snapshot.connectionState != ConnectionState.waiting &&
                (!_hasLoaded || _loadedForAlert != active?.id)) {
              final String? wanted = active?.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _load(wanted);
              });
            }

            return Column(
              children: <Widget>[
                _TopBar(guardian: widget.guardian),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.md,
                      AppSpacing.screenGutter,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      if (active != null)
                        _AlertNotice(alert: active)
                      else
                        const _CalmNotice(),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('TUS HIJOS', style: AppTextStyles.eyebrow),
                      const SizedBox(height: AppSpacing.sm),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
                          ),
                        )
                      else
                        for (final ChildStatus child in _children)
                          _ChildCard(child: child, alertActive: active != null),
                      if (active == null && !_loading) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        _PickupLink(children: _children),
                      ],
                    ],
                  ),
                ),
                const _CallButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.guardian});

  final GuardianEnrollment guardian;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ALERTIC',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: AppColors.ink,
            ),
          ),
          Text(
            '${PersonName.short(guardian.fullName)} · ACUDIENTE'.toUpperCase(),
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Lo que el colegio necesita que la familia haga: esperar.
class _AlertNotice extends StatelessWidget {
  const _AlertNotice({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.levelRed,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ALERTA ${alert.level.label} · ${alert.issuedAtLabel}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${alert.title} · ${alert.scope}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No vayas al colegio todavía. Te avisaremos el punto y la hora de '
            'entrega.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.onBrand,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalmNotice extends StatelessWidget {
  const _CalmNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('ESTADO DEL COLEGIO', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        const Text('SIN ALERTAS', style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text('Jornada normal.', style: AppTextStyles.caption),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.alertActive});

  final ChildStatus child;
  final bool alertActive;

  @override
  Widget build(BuildContext context) {
    final String? note = child.note;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                _StatusBadge(child: child, alertActive: alertActive),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${PersonName.short(child.fullName)} · ${child.grade}',
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel(child, alertActive),
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: child.isSafe ? AppColors.brand : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (alertActive && child.isSafe) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Ubicación', style: AppTextStyles.caption),
                  ),
                  Text(
                    child.meetingPoint,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note != null) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(note, style: AppTextStyles.caption),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(ChildStatus child, bool alertActive) {
    if (!alertActive) {
      return '${child.shift} · ${child.homeroomTeacher}';
    }
    if (child.isSafe) {
      final DateTime? at = child.reportedAt;
      final String hour = at == null
          ? ''
          : ' · ${at.hour}:${at.minute.toString().padLeft(2, '0')}';
      return 'A SALVO$hour';
    }
    if (child.needsHelp) {
      return 'NECESITA AYUDA';
    }
    return 'SIN CONFIRMAR';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.child, required this.alertActive});

  final ChildStatus child;
  final bool alertActive;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color background, Color foreground) = switch (child) {
      _ when !alertActive => (
          Icons.school_outlined,
          AppColors.surfaceAlt,
          AppColors.ink,
        ),
      _ when child.isSafe => (Icons.check, AppColors.brand, AppColors.onBrand),
      _ when child.needsHelp => (
          Icons.error_outline,
          AppColors.ink,
          AppColors.onBrand,
        ),
      _ => (Icons.schedule, AppColors.surfaceAlt, AppColors.inkMuted),
    };

    return Container(
      width: 40,
      height: 40,
      color: background,
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: foreground),
    );
  }
}

class _PickupLink extends StatelessWidget {
  const _PickupLink({required this.children});

  final List<ChildStatus> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => PickupScreen(children: children),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.badge_outlined,
                size: 20,
                color: AppColors.ink,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'CÓMO RECOGERLOS',
                  style: AppTextStyles.itemTitle,
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton();

  /// Muestra el teléfono que publicó el colegio.
  ///
  /// Viene del servidor y no está escrito en la app. Si no hay, se dice: un
  /// número inventado, con una familia preocupada, es peor que ninguno.
  ///
  /// TODO(llamada): abrir el marcador con `url_launcher`. Por ahora solo se
  /// muestra el número, sin simular una llamada que no ocurre.
  static Future<void> _showPhone(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GuardianRepository? repository =
        AppScope.of(context).guardianRepository;

    String message;
    try {
      final String? phone = await repository?.loadSchoolPhone();
      message = phone == null
          ? 'El colegio todavía no publicó un número de contacto. Acércate a '
              'la portería.'
          : 'Coordinación IIC · $phone';
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'teléfono del colegio');
      message = 'No pudimos traer el número. Revisa tu conexión.';
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.lg,
        ),
        child: Material(
          color: AppColors.surface,
          shape: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
          child: InkWell(
            onTap: () => _showPhone(context),
            child: SizedBox(
              height: AppSpacing.buttonHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.call_outlined, size: 20, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'LLAMAR A COORDINACIÓN',
                    style: AppTextStyles.button.copyWith(color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
