import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../onboarding/domain/person_name.dart';
import '../domain/account_repository.dart';
import '../domain/evacuation_support.dart';

/// Pantalla 35: apoyo para evacuar (accesibilidad e inclusión).
///
/// Quien necesita ayuda para salir lo dice aquí; el colegio le asigna compañeros
/// de apoyo y la alerta se adapta a la persona. Lo que se pide lo ven solo sus
/// compañeros de apoyo, el brigadista y su director de grupo.
///
/// **El destello y la voz se guardan pero todavía no los aplica la app**: hacen
/// falta permisos y componentes del celular que no están en esta versión. Lo que
/// sí se aplica hoy es la vibración fuerte en patrón.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  SupportSettings? _settings;
  List<SupportBuddy> _buddies = const <SupportBuddy>[];
  bool _loading = true;
  bool _saving = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  AccountRepository get _repository => AppScope.of(context).accountRepository!;

  Future<void> _load() async {
    final AccountRepository repository = _repository;
    try {
      final SupportOverview overview = await repository.loadSupport();
      if (!mounted) return;
      setState(() {
        _settings = overview.settings;
        _buddies = overview.buddies;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'apoyo para evacuar');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar tu apoyo. Intenta otra vez.';
        });
      }
    }
  }

  /// Elegir un apoyo es pedirlo: la primera vez se crea con la vibración
  /// encendida, que es lo que más sirve sin depender del sonido.
  void _pick(SupportNeed need) {
    setState(() {
      _settings = (_settings ?? SupportSettings(need: need)).copyWith(need: need);
    });
  }

  Future<void> _save() async {
    final SupportSettings? settings = _settings;
    if (settings == null) return;
    final AccountRepository repository = _repository;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repository.saveSupport(settings);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar apoyo');
      if (mounted) setState(() => _error = 'No se pudo guardar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final AccountRepository repository = _repository;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final SupportOverview overview = await repository.clearSupport();
      if (!mounted) return;
      setState(() {
        _settings = overview.settings;
        _buddies = overview.buddies;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'quitar apoyo');
      if (mounted) setState(() => _error = 'No se pudo quitar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupportSettings? settings = _settings;

    return AppPage(
      title: 'Apoyo para evacuar',
      subtitle: 'Accesibilidad e inclusión',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            key: const Key('guardar-apoyo'),
            label: 'Guardar',
            icon: null,
            isLoading: _saving,
            onPressed: settings == null || _loading ? null : _save,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              children: <Widget>[
                const Text(
                  'Si necesitas ayuda para salir, el colegio te asigna compañeros de '
                  'apoyo y la alerta se adapta a ti.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('¿QUÉ APOYO NECESITAS?', style: AppTextStyles.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final SupportNeed need in SupportNeed.values)
                      ChoiceChip(
                        key: Key('apoyo-${need.wire}'),
                        label: Text(need.label),
                        selected: settings?.need == need,
                        showCheckmark: false,
                        selectedColor: AppColors.brandSoft,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: settings?.need == need ? AppColors.brand : AppColors.border,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: settings?.need == need ? AppColors.brand : AppColors.ink,
                        ),
                        onSelected: (_) => _pick(need),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Tus compañeros de apoyo', style: AppTextStyles.itemTitle),
                      const SizedBox(height: AppSpacing.md),
                      if (_buddies.isEmpty)
                        const Text(
                          'El colegio todavía no te asignó compañeros de apoyo.',
                          key: Key('sin-companeros'),
                          style: AppTextStyles.caption,
                        )
                      else
                        for (final SupportBuddy buddy in _buddies)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.surfaceAlt,
                                  child: Text(
                                    PersonName.initials(buddy.fullName),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        buddy.fullName,
                                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                                      ),
                                      Text(buddy.detail, style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const Text(
                        'Reciben un aviso especial para ir por ti en cada alerta.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      _ToggleRow(
                        switchKey: const Key('apoyo-vibracion'),
                        title: 'Vibración fuerte en patrón',
                        subtitle: 'Sin depender del sonido',
                        value: settings?.vibrate ?? true,
                        onChanged: settings == null
                            ? null
                            : (bool v) => setState(() => _settings = settings.copyWith(vibrate: v)),
                      ),
                      const Divider(height: 1),
                      _ToggleRow(
                        switchKey: const Key('apoyo-destello'),
                        title: 'Destello con la linterna',
                        subtitle: 'Se guarda; esta versión todavía no lo aplica',
                        value: settings?.flash ?? false,
                        onChanged: settings == null
                            ? null
                            : (bool v) => setState(() => _settings = settings.copyWith(flash: v)),
                      ),
                      const Divider(height: 1),
                      _ToggleRow(
                        switchKey: const Key('apoyo-voz'),
                        title: 'Leer instrucciones en voz alta',
                        subtitle: 'Se guarda; esta versión todavía no lo aplica',
                        value: settings?.readAloud ?? false,
                        onChanged: settings == null
                            ? null
                            : (bool v) => setState(() => _settings = settings.copyWith(readAloud: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_outline, size: 14, color: AppColors.inkFaint),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Solo lo ven tus compañeros de apoyo, el brigadista y tu '
                        'director de grupo.',
                        style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                      ),
                    ),
                  ],
                ),
                if (settings != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  SecondaryButton(
                    key: const Key('quitar-apoyo'),
                    label: 'Ya no necesito apoyo',
                    onPressed: _saving ? null : _clear,
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    key: const Key('error-apoyo'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.brand),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.surface,
            activeTrackColor: AppColors.brand,
            inactiveThumbColor: AppColors.surface,
            inactiveTrackColor: AppColors.border,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
