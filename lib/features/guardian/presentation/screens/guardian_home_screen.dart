import 'dart:async';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/shell_scope.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/design/status_banner.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../account/presentation/alerts_feed_screen.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/format.dart';
import '../../../drills/presentation/drills_screen.dart';
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

  /// Lo que el colegio tiene para la familia en calma: el próximo simulacro y
  /// cómo salió la última alerta.
  Drill? _nextDrill;
  Alert? _lastAlert;
  String? _lastSummary;
  bool _askedSchoolNews = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_askedSchoolNews) {
      _askedSchoolNews = true;
      _loadSchoolNews();
    }
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

  Future<void> _loadSchoolNews() async {
    final AppScope scope = AppScope.of(context);
    try {
      final DrillOverview? overview = await scope.drillRepository?.load();
      if (mounted && overview != null) setState(() => _nextDrill = overview.next);
    } catch (error, stack) {
      // Son extras: sin ellos el inicio sirve igual.
      ErrorReporter.report(error, stack, context: 'próximo simulacro');
    }

    try {
      final List<Alert> history = await scope.alertRepository.loadHistory();
      if (!mounted || history.isEmpty) return;
      final Alert last = history.first;
      final List<ChildStatus> children =
          await scope.guardianRepository!.loadChildren(last.id);
      if (!mounted) return;
      setState(() {
        _lastAlert = last;
        _lastSummary = _summaryOf(last, children);
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'última alerta');
    }
  }

  /// «Tus hijos confirmaron a salvo en 4 y 6 min».
  static String _summaryOf(Alert alert, List<ChildStatus> children) {
    final List<int> minutes = <int>[
      for (final ChildStatus child in children)
        if (child.isSafe && child.reportedAt != null)
          child.reportedAt!.difference(alert.issuedAt).inMinutes.clamp(0, 999),
    ];
    if (minutes.isEmpty) return 'Sin confirmaciones registradas';
    final String times = minutes.length == 1
        ? '${minutes.first} min'
        : '${minutes.sublist(0, minutes.length - 1).join(', ')} y ${minutes.last} min';
    return minutes.length == 1
        ? 'Tu hijo confirmó a salvo en $times'
        : 'Tus hijos confirmaron a salvo en $times';
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
    final String? school = ShellScope.maybeOf(context)?.schoolName;

    return StreamBuilder<Alert?>(
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

        return AppPage(
          title: 'Hola, ${PersonName.firstName(widget.guardian.fullName)}',
          subtitle: <String>['Acudiente', ?school].join(' · '),
          bottom: const _CallButton(),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: <Widget>[
              if (active != null)
                _AlertNotice(alert: active)
              else
                const _CalmNotice(),
              const SectionLabel('TUS HIJOS'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                )
              else
                for (final ChildStatus child in _children)
                  _ChildCard(child: child, alertActive: active != null),
              if (active != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const _WhatToDo(),
              ],
              if (active == null && !_loading) ...<Widget>[
                for (final ChildStatus child in _children)
                  if (!child.appActive)
                    _InactiveNotice(
                      key: Key('sin-activar-${PersonName.firstName(child.fullName)}'),
                      child: child,
                    ),
                const SizedBox(height: AppSpacing.sm),
                _PickupLink(children: _children),
                if (_nextDrill != null || _lastAlert != null) ...<Widget>[
                  const SectionLabel('DEL COLEGIO'),
                  if (_nextDrill != null)
                    _NextDrillTile(
                      drill: _nextDrill!,
                      onTap: () => pushInShell<void>(context, (_) => const DrillsScreen()),
                    ),
                  if (_nextDrill != null && _lastAlert != null)
                    const SizedBox(height: AppSpacing.sm),
                  if (_lastAlert != null)
                    _LastAlertTile(
                      alert: _lastAlert!,
                      summary: _lastSummary ?? '',
                      onTap: () =>
                          pushInShell<void>(context, (_) => const AlertsFeedScreen()),
                    ),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              _LinkCard(
                icon: Icons.event_outlined,
                title: 'Simulacros',
                onTap: () => pushInShell<void>(context, (_) => const DrillsScreen()),
              ),
              const SizedBox(height: AppSpacing.sm),
              _LinkCard(
                icon: Icons.notifications_none,
                title: 'Alertas y avisos',
                onTap: () => pushInShell<void>(context, (_) => const AlertsFeedScreen()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// «Tomás aún no activa ALERTIC en su celular».
class _InactiveNotice extends StatelessWidget {
  const _InactiveNotice({required this.child, super.key});

  final ChildStatus child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: const Color(0xFFF1D9A6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline, size: 20, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${PersonName.firstName(child.fullName)} aún no activa ALERTIC en su '
                'celular. Pídele el código en secretaría.',
                style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF5E3D00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextDrillTile extends StatelessWidget {
  const _NextDrillTile({required this.drill, required this.onTap});

  final Drill drill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('proximo-simulacro'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  Fmt.monthTag(drill.scheduledAt),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
                Text(
                  '${drill.scheduledAt.day}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Simulacro de ${drill.hazard.label.toLowerCase()}',
                  style: AppTextStyles.itemTitle,
                ),
                Text(
                  '${Fmt.weekday(drill.scheduledAt)} · ${Fmt.hour(drill.scheduledAt)} · '
                  'No es necesario ir al colegio',
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

class _LastAlertTile extends StatelessWidget {
  const _LastAlertTile({required this.alert, required this.summary, required this.onTap});

  final Alert alert;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('ultima-alerta'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble.neutral(icon: hazardIcon(alert.hazard), size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Última alerta: ${alert.hazard.label.toLowerCase()} · '
                  '${Fmt.dayMonthShort(alert.issuedAt)}',
                  style: AppTextStyles.itemTitle,
                ),
                Text(summary, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
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
      key: const Key('aviso-alerta-acudiente'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.levelRed,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: <Widget>[
          Icon(hazardIcon(alert.hazard), size: 24, color: AppColors.onBrand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_titleCase(alert.title)} en el colegio · ${alert.issuedAtLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBrand,
                  ),
                ),
                Text(
                  'Alerta ${alert.level.label.toLowerCase()} · ${alert.level.meaning.toLowerCase()}',
                  style: const TextStyle(fontSize: 13, color: AppColors.onBrand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `SISMO` → `Sismo`.
  static String _titleCase(String title) {
    final String lower = title.toLowerCase();
    return lower.isEmpty ? lower : '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}

/// Lo que la familia debe hacer —y no hacer— mientras dura la alerta.
class _WhatToDo extends StatelessWidget {
  const _WhatToDo();

  static const List<String> _steps = <String>[
    'No vayas al colegio todavía: las vías deben quedar libres.',
    'Evita llamar a tus hijos: necesitan atención para evacuar.',
    'Espera aquí el punto y la hora para recogerlos.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('que-hacer-acudiente'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'QUÉ HACER COMO ACUDIENTE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white),
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

class _CalmNotice extends StatelessWidget {
  const _CalmNotice();

  @override
  Widget build(BuildContext context) {
    return const StatusBanner(
      key: Key('sin-alertas'),
      icon: Icons.verified_user_outlined,
      title: 'Todo tranquilo',
      subtitle: 'No hay alertas en el colegio de tus hijos',
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: alertActive && child.needsHelp ? AppColors.brand : AppColors.border,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  _Avatar(child: child, alertActive: alertActive),
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
                        if (!alertActive)
                          Text(
                            '${child.shift} · ${child.homeroomTeacher}',
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  if (alertActive)
                    _StatusPill(child: child)
                  else
                    Pill(
                      child.appActive ? 'App activa' : 'Sin activar',
                      tone: child.appActive ? PillTone.success : PillTone.warning,
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
                    const Expanded(
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
      ),
    );
  }
}

/// El estado de un hijo durante una alerta, en una insignia.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.child});

  final ChildStatus child;

  @override
  Widget build(BuildContext context) {
    if (child.isSafe) {
      final DateTime? at = child.reportedAt;
      final String hour = at == null
          ? ''
          : ' · ${at.hour}:${at.minute.toString().padLeft(2, '0')}';
      return Pill('A SALVO$hour', tone: PillTone.success);
    }
    if (child.needsHelp) {
      return const Pill('NECESITA AYUDA', tone: PillTone.brand);
    }
    return const Pill('SIN CONFIRMAR', tone: PillTone.warning);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.child, required this.alertActive});

  final ChildStatus child;
  final bool alertActive;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = !alertActive
        ? (AppColors.surfaceAlt, AppColors.ink)
        : child.isSafe
            ? (AppColors.successSoft, AppColors.success)
            : child.needsHelp
                ? (AppColors.brandSoft, AppColors.brand)
                : (AppColors.warningSoft, AppColors.warning);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        PersonName.initials(child.fullName),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}

class _PickupLink extends StatelessWidget {
  const _PickupLink({required this.children});

  final List<ChildStatus> children;

  @override
  Widget build(BuildContext context) {
    return _LinkCard(
      icon: Icons.badge_outlined,
      title: 'CÓMO RECOGERLOS',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => PickupScreen(children: children),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: AppTextStyles.itemTitle)),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton();

  /// Llama al teléfono que publicó el colegio.
  ///
  /// Viene del servidor y no está escrito en la app. Si no hay, se dice: un
  /// número inventado, con una familia preocupada, es peor que ninguno. Si el
  /// celular no puede abrir el marcador, se muestra el número para marcarlo a
  /// mano.
  static Future<void> _call(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GuardianRepository? repository = AppScope.of(context).guardianRepository;

    void say(String message) => messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    try {
      final String? phone = await repository?.loadSchoolPhone();
      if (phone == null) {
        say(
          'El colegio todavía no publicó un número de contacto. Acércate a la '
          'portería.',
        );
        return;
      }

      final String digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final bool opened = await launchUrl(Uri(scheme: 'tel', path: digits))
          .catchError((Object _) => false);
      if (!opened) say('Coordinación · $phone');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'teléfono del colegio');
      say('No pudimos traer el número. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: SecondaryButton(
        key: const Key('llamar-coordinacion'),
        label: 'LLAMAR A COORDINACIÓN',
        icon: Icons.call_outlined,
        onPressed: () => _call(context),
      ),
    );
  }
}
