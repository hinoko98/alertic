import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../alerts/presentation/widgets/haptic_pattern.dart';
import '../domain/account_repository.dart';
import '../domain/alert_preferences.dart';

/// Pantalla 34: «Cómo te avisamos».
///
/// Sonido, vibración y tamaño de letra de las alertas. «Sonar aunque esté en
/// silencio» lo guarda el colegio con los demás ajustes de la cuenta; la
/// vibración y la letra se guardan en este celular, porque dependen del aparato.
class AlertPreferencesScreen extends StatefulWidget {
  const AlertPreferencesScreen({super.key});

  @override
  State<AlertPreferencesScreen> createState() => _AlertPreferencesScreenState();
}

class _AlertPreferencesScreenState extends State<AlertPreferencesScreen> {
  AlertPreferences _prefs = const AlertPreferences();
  bool _criticalAlerts = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final AccountRepository? accounts = AppScope.of(context).accountRepository;
    try {
      final AlertPreferences prefs = await AlertPreferencesStore.load();
      final AccountSettings? settings = await accounts?.loadSettings();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _criticalAlerts = settings?.criticalAlerts ?? true;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preferencias de alerta');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar tus ajustes. Puedes cambiarlos igual.';
        });
      }
    }
  }

  Future<void> _save() async {
    final AccountRepository? accounts = AppScope.of(context).accountRepository;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AlertPreferencesStore.save(_prefs);
      await accounts?.updateSettings(criticalAlerts: _criticalAlerts);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar preferencias de alerta');
      if (mounted) setState(() => _error = 'No se pudo guardar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Suena y vibra como lo haría una alerta, sin avisarle a nadie.
  Future<void> _test() async {
    await SystemSound.play(SystemSoundType.alert);
    if (_prefs.strongVibration) {
      await AlertHaptics.play();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Cómo te avisamos',
      subtitle: 'Sonido, vibración y tamaño de letra',
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
            key: const Key('guardar-avisos'),
            label: 'Guardar',
            icon: null,
            isLoading: _saving,
            onPressed: _loading ? null : _save,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      _ToggleRow(
                        switchKey: const Key('aviso-silencio'),
                        title: 'Sonar aunque esté en silencio',
                        subtitle: 'Solo en alertas rojas y naranjas',
                        value: _criticalAlerts,
                        onChanged: (bool v) => setState(() => _criticalAlerts = v),
                      ),
                      const Divider(height: 1),
                      _ToggleRow(
                        switchKey: const Key('aviso-vibracion'),
                        title: 'Vibración fuerte',
                        subtitle: 'Tres golpes seguidos al llegar la alerta',
                        value: _prefs.strongVibration,
                        onChanged: (bool v) =>
                            setState(() => _prefs = _prefs.copyWith(strongVibration: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('TAMAÑO DE LA LETRA EN ALERTAS', style: AppTextStyles.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EAEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      for (final AlertTextSize size in AlertTextSize.values)
                        Expanded(
                          child: _SizeButton(
                            key: Key('letra-${size.wire}'),
                            size: size,
                            selected: size == _prefs.textSize,
                            onTap: () => setState(() => _prefs = _prefs.copyWith(textSize: size)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Prueba tu alerta', style: AppTextStyles.itemTitle),
                      const SizedBox(height: 4),
                      const Text(
                        'Escucha y siente cómo te llegará, sin avisar a nadie más.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryButton(
                        key: const Key('probar-alerta'),
                        label: 'Probar alerta',
                        icon: Icons.volume_up_outlined,
                        onPressed: _test,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    key: const Key('error-avisos'),
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
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Key switchKey;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

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
                if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
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

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.size,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AlertTextSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              // Cada botón se escribe con el tamaño que representa.
              child: Text(
                size.label,
                style: TextStyle(
                  fontSize: 14 * size.scale,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.brand : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
