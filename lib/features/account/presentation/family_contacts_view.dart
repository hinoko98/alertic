import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/account_repository.dart';

/// A quién se avisa cuando la persona confirma que está a salvo.
///
/// Los acudientes los carga el colegio y no se quitan desde aquí; los demás
/// contactos los suma y quita la persona. El interruptor decide si el aviso sale
/// solo.
///
/// Se usa en el último paso del registro y en el perfil: es lo mismo, con otro
/// marco.
class FamilyContactsView extends StatefulWidget {
  const FamilyContactsView({super.key});

  @override
  State<FamilyContactsView> createState() => _FamilyContactsViewState();
}

class _FamilyContactsViewState extends State<FamilyContactsView> {
  List<FamilyContact> _contacts = <FamilyContact>[];
  AccountSettings? _settings;
  bool _loading = true;
  bool _failed = false;
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
    try {
      final List<FamilyContact> contacts = await _repository.loadContacts();
      final AccountSettings settings = await _repository.loadSettings();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _settings = settings;
          _loading = false;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'contactos de familia');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _toggleNotify(bool value) async {
    final AccountSettings? before = _settings;
    if (before == null) return;

    // Se ve el cambio de inmediato; si el servidor no lo guarda, vuelve atrás.
    setState(() {
      _settings = before.copyWith(notifyFamily: value);
      _error = null;
    });
    try {
      final AccountSettings saved = await _repository.updateSettings(notifyFamily: value);
      if (mounted) setState(() => _settings = saved);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'avisar a la familia');
      if (mounted) {
        setState(() {
          _settings = before;
          _error = 'No se pudo guardar. Intenta otra vez.';
        });
      }
    }
  }

  Future<void> _add() async {
    final NewContact? contact = await showModalBottomSheet<NewContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => const _NewContactSheet(),
    );
    if (contact == null || !mounted) return;

    try {
      final List<FamilyContact> updated = await _repository.addContact(contact);
      if (mounted) setState(() => _contacts = updated);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'agregar contacto');
      if (mounted) setState(() => _error = 'No se pudo agregar. Intenta otra vez.');
    }
  }

  Future<void> _remove(FamilyContact contact) async {
    try {
      final List<FamilyContact> updated = await _repository.removeContact(contact.id);
      if (mounted) setState(() => _contacts = updated);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'quitar contacto');
      if (mounted) setState(() => _error = 'No se pudo quitar. Intenta otra vez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          child: const Text('No pudimos cargar tus contactos. Reintentar'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: _contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'El colegio todavía no registró acudientes. Puedes sumar a '
                    'quien quieras que se entere.',
                    style: AppTextStyles.caption,
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < _contacts.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      _ContactRow(
                        contact: _contacts[i],
                        onRemove: _contacts[i].fromSchool ? null : () => _remove(_contacts[i]),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DashedButton(
          key: const Key('agregar-contacto'),
          label: 'Agregar contacto',
          onTap: _add,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            key: const Key('error-contactos'),
            style: AppTextStyles.caption.copyWith(color: AppColors.brand),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Avisar automáticamente', style: AppTextStyles.itemTitle),
                    SizedBox(height: 2),
                    Text(
                      'Cuando marques «Estoy a salvo», les llega un aviso con tu '
                      'punto de encuentro. Solo lo reciben los acudientes con la '
                      'app.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('avisar-familia'),
                value: _settings?.notifyFamily ?? true,
                onChanged: _toggleNotify,
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.brand,
                inactiveThumbColor: AppColors.surface,
                inactiveTrackColor: AppColors.border,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onRemove});

  final FamilyContact contact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final List<String> parts =
        contact.fullName.split(' ').where((String p) => p.isNotEmpty).toList();
    final String initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts[1][0]}'.toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(contact.fullName, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                Text(
                  <String>[
                    contact.relationship,
                    if (contact.maskedPhone != null) contact.maskedPhone!,
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (contact.fromSchool)
            const Pill('Acudiente', tone: PillTone.success)
          else ...<Widget>[
            const Pill('Agregado'),
            IconButton(
              tooltip: 'Quitar',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18, color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: CustomPaint(
        painter: _DashedBorder(),
        child: const SizedBox(
          height: 48,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.add, size: 18, color: AppColors.brand),
              SizedBox(width: 6),
              Text(
                'Agregar contacto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.brand.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final RRect box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppSpacing.radius),
    );
    final Path path = Path()..addRRect(box);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewContactSheet extends StatefulWidget {
  const _NewContactSheet();

  @override
  State<_NewContactSheet> createState() => _NewContactSheetState();
}

class _NewContactSheetState extends State<_NewContactSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _relationship = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    final String relationship = _relationship.text.trim();
    final String phone = _phone.text.trim();

    if (name.length < 3) {
      setState(() => _error = 'Escribe el nombre de tu contacto.');
      return;
    }
    if (relationship.length < 2) {
      setState(() => _error = 'Dinos qué es tuyo: mamá, tío, abuela…');
      return;
    }
    if (!RegExp(r'^[0-9+() -]{7,20}$').hasMatch(phone)) {
      setState(() => _error = 'Revisa el celular: solo números, mínimo 7.');
      return;
    }
    Navigator.of(context).pop(
      NewContact(fullName: name, relationship: relationship, phone: phone),
    );
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
            const Text('Agregar contacto', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('contacto-nombre'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('contacto-parentesco'),
              controller: _relationship,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Parentesco (tía, abuelo…)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('contacto-celular'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.brand)),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('guardar-contacto'),
              label: 'Guardar',
              icon: null,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
