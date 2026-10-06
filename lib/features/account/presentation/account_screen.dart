import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/shell_scope.dart';
import '../../../app/sign_out.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/design/icon_bubble.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/design/section_label.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../onboarding/domain/enrollment.dart';
import '../../onboarding/domain/person_name.dart';
import '../../onboarding/presentation/widgets/identity_card.dart';
import '../domain/account_repository.dart';
import 'alerts_feed_screen.dart';
import 'change_password_sheet.dart';
import 'family_contacts_view.dart';

/// Perfil y ajustes (pantalla 20), para los cuatro roles.
///
/// Es una sola pantalla porque hacen lo mismo aquí —ver sus datos, ajustar sus
/// avisos y salir—; lo que cambia es qué datos tienen y si entran con contraseña
/// (y por tanto pueden cambiarla).
///
/// Lo que se cambia aquí se guarda en el colegio: es lo que el servidor consulta
/// al decidir, por ejemplo, si avisa a la familia.
class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.enrollment, super.key});

  final Enrollment enrollment;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountSettings? _settings;
  List<FamilyContact> _contacts = <FamilyContact>[];
  String? _error;
  bool _started = false;

  Enrollment get _person => widget.enrollment;
  bool get _usesPassword => _person.role.usesPassword;
  bool get _isStudent => _person is StudentEnrollment;
  bool get _isAdmin => _person is AdminEnrollment;

  AccountRepository? get _repository => AppScope.of(context).accountRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final AccountRepository? repository = _repository;
    if (repository == null || _isAdmin) return;
    try {
      final AccountSettings settings = await repository.loadSettings();
      final List<FamilyContact> contacts =
          _isStudent ? await repository.loadContacts() : <FamilyContact>[];
      if (mounted) {
        setState(() {
          _settings = settings;
          _contacts = contacts;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'ajustes');
    }
  }

  Future<void> _update({bool? criticalAlerts, bool? shareLocation}) async {
    final AccountSettings? before = _settings;
    final AccountRepository? repository = _repository;
    if (before == null || repository == null) return;

    // Se ve el cambio de inmediato; si el servidor no lo guarda, vuelve atrás y
    // se dice, en vez de dejar un interruptor que miente.
    setState(() {
      _settings = before.copyWith(criticalAlerts: criticalAlerts, shareLocation: shareLocation);
      _error = null;
    });
    try {
      final AccountSettings saved = await repository.updateSettings(
        criticalAlerts: criticalAlerts,
        shareLocation: shareLocation,
      );
      if (mounted) setState(() => _settings = saved);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar ajuste');
      if (mounted) {
        setState(() {
          _settings = before;
          _error = 'No se pudo guardar. Intenta otra vez.';
        });
      }
    }
  }

  Future<void> _editMedical() async {
    final AccountSettings? current = _settings;
    final AccountRepository? repository = _repository;
    if (current == null || repository == null) return;

    final ({String? text, bool clear})? result =
        await showModalBottomSheet<({String? text, bool clear})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _MedicalSheet(initial: current.medicalInfo ?? ''),
    );
    if (result == null || !mounted) return;

    try {
      final AccountSettings saved = await repository.updateSettings(
        medicalInfo: result.text,
        clearMedicalInfo: result.clear,
      );
      if (mounted) setState(() => _settings = saved);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'información médica');
      if (mounted) setState(() => _error = 'No se pudo guardar. Intenta otra vez.');
    }
  }

  Future<void> _push(WidgetBuilder builder) => pushInShell<void>(context, builder);

  Future<void> _changePassword() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool changed = await showChangePassword(context);
    if (changed) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Contraseña cambiada. Tus otras sesiones se cerraron.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Enrollment person = _person;
    final String? school = ShellScope.maybeOf(context)?.schoolName;
    final bool student = _isStudent;

    return AppPage(
      title: student ? 'Perfil' : 'Tu cuenta',
      subtitle: student ? 'Tu cuenta y ajustes' : 'Tus datos y ajustes',
      showHelp: !_isAdmin,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          _Header(person: person, school: school),
          const SizedBox(height: AppSpacing.md),
          IdentityCard(children: _details(person)),
          const SizedBox(height: AppSpacing.sm),
          LockedDataNote(
            message: _usesPassword
                ? 'El colegio registró estos datos. Si algo está mal, pídele a '
                    'coordinación que lo cambie.'
                : 'El colegio registró estos datos. Si algo está mal, avisa en '
                    'secretaría.',
          ),
          if (!_isAdmin && _settings != null) ...<Widget>[
            const SectionLabel('Tus ajustes'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  if (student) ...<Widget>[
                    _Row(
                      key: const Key('contactos-de-familia'),
                      icon: Icons.family_restroom_outlined,
                      title: 'Contactos de familia',
                      subtitle: '${_contacts.length} ${_contacts.length == 1 ? 'contacto' : 'contactos'}',
                      onTap: () async {
                        await _push((_) => const _FamilyContactsScreen());
                        _load();
                      },
                    ),
                    const Divider(height: 1),
                  ],
                  _Row(
                    icon: Icons.notifications_none,
                    title: 'Alertas críticas',
                    subtitle: 'Sonar aunque esté en silencio',
                    switchKey: const Key('ajuste-alertas'),
                    value: _settings!.criticalAlerts,
                    onChanged: (bool v) => _update(criticalAlerts: v),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.location_on_outlined,
                    title: 'Ubicación en emergencias',
                    subtitle: 'Solo durante alertas',
                    switchKey: const Key('ajuste-ubicacion'),
                    value: _settings!.shareLocation,
                    onChanged: (bool v) => _update(shareLocation: v),
                  ),
                  const Divider(height: 1),
                  _Row(
                    key: const Key('informacion-medica'),
                    icon: Icons.favorite_border,
                    title: 'Información médica',
                    subtitle: _settings!.medicalInfo == null
                        ? 'Opcional · solo la ve coordinación'
                        : 'Anotada · solo la ve coordinación',
                    onTap: _editMedical,
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.history,
                    title: 'Alertas y avisos',
                    subtitle: 'Historial de tu colegio y tus reportes',
                    onTap: () => _push((_) => const AlertsFeedScreen()),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('error-ajustes'),
                style: AppTextStyles.caption.copyWith(color: AppColors.brand),
              ),
            ),
          if (!_usesPassword) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const LockedDataNote(
              message: '¿Cambias de celular? Pide un código nuevo en secretaría: '
                  'el anterior deja de funcionar.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (_usesPassword) ...<Widget>[
            SecondaryButton(
              key: const Key('cambiar-contrasena'),
              label: 'Cambiar contraseña',
              onPressed: _changePassword,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SecondaryButton(
            key: const Key('cerrar-sesion'),
            label: 'Cerrar sesión',
            onPressed: () => confirmAndSignOut(
              context,
              message: _usesPassword ? SignOutMessages.withPassword : SignOutMessages.withCode,
            ),
          ),
        ],
      ),
    );
  }

  /// Los datos de cada rol. Un `switch` sobre la clase sellada: si se agrega un
  /// rol nuevo, el compilador obliga a decidir qué se muestra aquí.
  static List<Widget> _details(Enrollment person) {
    return switch (person) {
      TeacherEnrollment() => <Widget>[
          if (person.email != null) ...<Widget>[
            DetailRow(label: 'Correo', value: person.email!),
            const Divider(height: 1),
          ],
          DetailRow(label: 'Materia', value: person.subject),
          const Divider(height: 1),
          DetailRow(
            label: 'Director de grupo',
            value: person.homeroomGroup ?? 'No dirige un grupo',
          ),
          const Divider(height: 1),
          DetailRow(
            label: 'Grupos que dicta',
            value: person.groups.isEmpty ? '—' : person.groups.join(', '),
          ),
        ],
      AdminEnrollment() => <Widget>[
          if (person.email != null) ...<Widget>[
            DetailRow(label: 'Correo', value: person.email!),
            const Divider(height: 1),
          ],
          DetailRow(label: 'Alcance', value: person.scope),
        ],
      GuardianEnrollment() => <Widget>[
          DetailRow(label: 'Celular registrado', value: person.maskedPhone),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('HIJOS VINCULADOS', style: AppTextStyles.eyebrow),
          ),
          for (final LinkedStudent child in person.children)
            LinkedPersonRow(
              name: child.fullName,
              detail: '${child.grade} · ${child.shift}',
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      StudentEnrollment() => <Widget>[
          DetailRow(label: 'Grado', value: '${person.grade} · ${person.shift}'),
          const Divider(height: 1),
          DetailRow(label: 'Salón', value: person.classroom),
          const Divider(height: 1),
          DetailRow(
            label: 'Punto de encuentro',
            value: '${person.meetingPoint.code} · ${person.meetingPoint.name}',
          ),
        ],
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.person, required this.school});

  final Enrollment person;
  final String? school;

  @override
  Widget build(BuildContext context) {
    final Enrollment who = person;

    return AppCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              PersonName.initials(who.fullName),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onBrand,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  who.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: AppColors.ink,
                  ),
                ),
                if (school != null) Text(school!, style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    Pill(_roleLabel(who), tone: PillTone.brand),
                    if (who is StudentEnrollment) Pill(who.grade),
                    if (who is TeacherEnrollment && who.homeroomGroup != null)
                      Pill('Dir. ${who.homeroomGroup}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(Enrollment who) => switch (who.role) {
        UserRole.estudiante => 'Estudiante',
        UserRole.acudiente => 'Acudiente',
        UserRole.docente => 'Docente',
        UserRole.administrador => 'Coordinación',
      };
}

/// Una fila de la lista de ajustes: tocable, o con un interruptor.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
    this.switchKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            IconBubble.neutral(icon: icon, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (value != null)
              Switch(
                key: switchKey,
                value: value!,
                onChanged: onChanged,
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.brand,
                inactiveThumbColor: AppColors.surface,
                inactiveTrackColor: AppColors.border,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _FamilyContactsScreen extends StatelessWidget {
  const _FamilyContactsScreen();

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Contactos de familia',
      subtitle: 'A quién avisamos cuando estás a salvo',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: const <Widget>[FamilyContactsView()],
      ),
    );
  }
}

class _MedicalSheet extends StatefulWidget {
  const _MedicalSheet({required this.initial});

  final String initial;

  @override
  State<_MedicalSheet> createState() => _MedicalSheetState();
}

class _MedicalSheetState extends State<_MedicalSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Información médica', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Opcional. Alergias, medicamentos o una condición que un brigadista '
              'deba saber si pides ayuda. Solo la ve coordinación, y solo cuando '
              'pides ayuda en una alerta.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('texto-medico'),
              controller: _text,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Ej. alergia a la penicilina'),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const Key('guardar-medico'),
              label: 'Guardar',
              icon: null,
              onPressed: () => Navigator.of(context).pop(
                (
                  text: _text.text.trim().isEmpty ? null : _text.text.trim(),
                  clear: _text.text.trim().isEmpty,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
