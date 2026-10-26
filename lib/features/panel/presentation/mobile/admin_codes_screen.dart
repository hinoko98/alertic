import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/section_label.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../domain/panel_repository.dart';
import '../widgets/bulk_code_dialogs.dart';

/// Pantalla 54: códigos de acceso desde el celular.
///
/// El caso de todos los días: alguien cambió de celular o perdió el carné y
/// necesita un código nuevo ya, en el pasillo. Se busca a la persona, se emite
/// y se le dicta o se le muestra. La carga masiva desde Excel sigue en el panel
/// web, donde hay teclado y pantalla para revisarla.
class AdminCodesScreen extends StatefulWidget {
  const AdminCodesScreen({super.key});

  @override
  State<AdminCodesScreen> createState() => _AdminCodesScreenState();
}

class _AdminCodesScreenState extends State<AdminCodesScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  List<CommunityMember> _results = const <CommunityMember>[];
  bool _searching = false;
  CommunityMember? _selected;

  /// El código recién emitido, solo mientras la pantalla está abierta: después
  /// no existe en ningún lado más que en manos de la persona.
  String? _issued;
  bool _issuing = false;

  CommunityStats? _stats;
  bool _started = false;

  PanelRepository get _panel => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_loadStats());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final CommunityStats stats = await _panel.loadStats();
      if (mounted) setState(() => _stats = stats);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'estado de los códigos');
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final String query = value.trim();
    if (query.length < 2) {
      setState(() => _results = const <CommunityMember>[]);
      return;
    }
    setState(() => _searching = true);
    try {
      final List<CommunityMember> people = await _panel.loadCommunity(query: query);
      if (!mounted) return;
      setState(() {
        // Docentes y coordinación entran con contraseña: aquí no tienen código.
        _results = people
            .where((CommunityMember p) => p.role == 'estudiante' || p.role == 'acudiente')
            .take(8)
            .toList();
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'buscar para código');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _issue(CommunityMember person) async {
    final String who = PersonName.short(person.fullName);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Emitir un código nuevo?'),
        content: Text(
          'Se revoca el código actual y se cierra la sesión de $who en sus '
          'celulares. Solo entra quien tenga el código nuevo.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text('EMITIR'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _issuing = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String code = await _panel.renewCode(person.id);
      if (!mounted) return;
      setState(() => _issued = code);
      unawaited(_loadStats());
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'emitir código');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'No se pudo emitir el código. Intenta otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _copy(String code) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Código copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final CommunityMember? selected = _selected;
    final CommunityStats? stats = _stats;

    return AppPage(
      title: 'Códigos de acceso',
      subtitle: 'Estudiantes y acudientes',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          const Text('BUSCAR PERSONA', style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const Key('codigos-buscar'),
            controller: _query,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Nombre o documento',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                      ),
                    )
                  : null,
            ),
          ),
          if (selected == null && _results.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _results.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      key: Key('codigos-persona-${_results[i].id}'),
                      title: Text(_results[i].fullName, style: AppTextStyles.itemTitle),
                      subtitle: Text(_roleLine(_results[i]), style: AppTextStyles.caption),
                      trailing: _StatusChip(status: _results[i].codeStatus),
                      onTap: () => setState(() {
                        _selected = _results[i];
                        _issued = null;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (selected != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _PersonCard(
              person: selected,
              issued: _issued,
              issuing: _issuing,
              onIssue: () => _issue(selected),
              onCopy: _copy,
              onClear: () => setState(() {
                _selected = null;
                _issued = null;
              }),
            ),
          ],
          const SectionLabel('Estado de los códigos'),
          Row(
            key: const Key('codigos-estado'),
            children: <Widget>[
              Expanded(
                child: _Figure(
                  value: stats == null ? '—' : '${stats.activeCodes}',
                  label: 'Activados',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Figure(
                  value: stats == null ? '—' : '${stats.pendingCodes}',
                  label: 'Sin usar',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            key: const Key('codigos-por-curso'),
            onPressed: () => showGroupCodes(context, onChanged: () => unawaited(_loadStats())),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('Generar códigos por curso', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'La carga masiva desde Excel está en el panel web.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  static String _roleLine(CommunityMember person) {
    final String role = person.role == 'estudiante' ? 'Estudiante' : 'Acudiente';
    final String? extra = person.grade ?? person.linkedTo;
    return extra == null ? role : '$role · $extra';
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.issued,
    required this.issuing,
    required this.onIssue,
    required this.onCopy,
    required this.onClear,
  });

  final CommunityMember person;
  final String? issued;
  final bool issuing;
  final VoidCallback onIssue;
  final ValueChanged<String> onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final String? code = issued;
    return AppCard(
      key: const Key('codigos-seleccionado'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceAlt,
                child: Text(
                  PersonName.initials(person.fullName),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(person.fullName, style: AppTextStyles.itemTitle),
                    Text(_AdminCodesScreenState._roleLine(person), style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (code == null) _StatusChip(status: person.codeStatus),
              IconButton(
                tooltip: 'Buscar a otra persona',
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (code == null)
            FilledButton(
              key: const Key('codigos-emitir'),
              onPressed: issuing ? null : onIssue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                issuing ? 'Emitiendo…' : 'Emitir código nuevo',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else ...<Widget>[
            _CodeDisplay(code: code),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Código nuevo de un solo uso. El anterior quedó desactivado.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('codigos-copiar'),
              onPressed: () => onCopy(code),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar código', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `IICB  9M2Q`: lo del colegio más tenue, lo de la persona destacado, para
/// dictarlo sin confundirse.
class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final String plain = code.replaceAll('-', '').toUpperCase();
    final String school = plain.length > 4 ? plain.substring(0, 4) : '';
    final String own = plain.length > 4 ? plain.substring(4) : plain;
    return Container(
      key: const Key('codigos-codigo'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (school.isNotEmpty) ...<Widget>[
            Text(
              school,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3, color: Colors.white70),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            own,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.onBrand),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color background, Color foreground) = switch (status) {
      'usado' => ('Activado', AppColors.successSoft, AppColors.success),
      'pendiente' || 'entregado' => ('Sin usar', AppColors.warningSoft, AppColors.warning),
      'vencido' => ('Vencido', AppColors.brandSoft, AppColors.brand),
      'revocado' => ('Revocado', AppColors.surfaceAlt, AppColors.inkMuted),
      _ => ('Sin código', AppColors.surfaceAlt, AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: foreground)),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
