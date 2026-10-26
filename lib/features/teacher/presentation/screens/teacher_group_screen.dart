import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/section_label.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../../risks/presentation/report_risk_screen.dart';
import '../../domain/teacher_repository.dart';

/// «Mi grupo»: el grupo del docente en calma.
///
/// Responde lo que el docente necesita saber **antes** de la emergencia: cuántos
/// tienen la app, cuántos acudientes están vinculados, quién necesita apoyo para
/// salir y a quién le falta algo por activar. En la alerta eso mismo decide
/// quién se queda sin aviso.
class TeacherGroupScreen extends StatefulWidget {
  const TeacherGroupScreen({required this.teacher, super.key});

  final TeacherEnrollment teacher;

  @override
  State<TeacherGroupScreen> createState() => _TeacherGroupScreenState();
}

class _TeacherGroupScreenState extends State<TeacherGroupScreen> {
  GroupOverview? _overview;
  bool _loading = true;
  bool _failed = false;
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
    final String? grade = widget.teacher.primaryGroup;
    final TeacherRepository? teachers = AppScope.of(context).teacherRepository;
    if (grade == null || teachers == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final GroupOverview overview = await teachers.loadGroupOverview(grade);
      if (mounted) setState(() => _overview = overview);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'mi grupo');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? grade = widget.teacher.primaryGroup;
    final GroupOverview? overview = _overview;

    return AppPage(
      title: grade == null ? 'Mi grupo' : 'Mi grupo · $grade',
      subtitle: overview == null
          ? null
          : <String>[
              '${overview.enrolled} estudiantes',
              if (overview.meetingPoint != null) 'Punto ${overview.meetingPoint}',
            ].join(' · '),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : grade == null
              ? const _Note('Coordinación todavía no te asignó un grupo.')
              : _failed || overview == null
                  ? _Note(
                      'No pudimos cargar tu grupo. Intenta otra vez.',
                      onRetry: () {
                        setState(() {
                          _loading = true;
                          _failed = false;
                        });
                        _load();
                      },
                    )
                  : _Body(overview: overview),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.overview});

  final GroupOverview overview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.xl,
      ),
      children: <Widget>[
        AppCard(
          key: const Key('grupo-cobertura'),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              _Coverage(label: 'App activa', value: overview.appActive, total: overview.enrolled),
              const SizedBox(height: AppSpacing.md),
              _Coverage(
                label: 'Acudientes vinculados',
                value: overview.guardiansLinked,
                total: overview.enrolled,
              ),
            ],
          ),
        ),
        if (overview.needsSupport.isNotEmpty) ...<Widget>[
          const SectionLabel('Necesita apoyo para evacuar'),
          AppCard(
            key: const Key('grupo-apoyo'),
            borderColor: AppColors.brandSoft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < overview.needsSupport.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _PersonRow(
                    name: overview.needsSupport[i].fullName,
                    detail: _supportDetail(overview.needsSupport[i]),
                    brand: true,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (overview.pending.isNotEmpty) ...<Widget>[
          const SectionLabel('Pendientes'),
          AppCard(
            key: const Key('grupo-pendientes'),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < overview.pending.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _PersonRow(
                    name: overview.pending[i].fullName,
                    detail: overview.pending[i].reason,
                    chip: overview.pending[i].chip,
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.surfaceAlt,
          borderColor: AppColors.surfaceAlt,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 20, color: AppColors.ink),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Los estudiantes, grupos y puntos los asigna Coordinación desde el '
                  'panel. Si algo no coincide, avísale.',
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // El docente ya no tiene una pestaña propia para reportar: vive aquí, junto
        // a lo que ve del grupo, porque lo que reporta suele ser del edificio.
        AppCard(
          key: const Key('grupo-reportar-riesgo'),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const ReportRiskScreen(),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_outlined, size: 20, color: AppColors.brand),
              SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Reportar un riesgo del edificio', style: AppTextStyles.itemTitle)),
              Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ],
    );
  }

  static String _supportDetail(SupportedStudent student) {
    if (student.buddies.isEmpty) return student.needLabel;
    final List<String> names = student.buddies.map(PersonName.firstName).toList();
    final String joined = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
    return '${student.needLabel} · lo acompañan $joined';
  }
}

/// «App activa · 30 de 32» con su barra.
class _Coverage extends StatelessWidget {
  const _Coverage({required this.label, required this.value, required this.total});

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: AppTextStyles.itemTitle),
            Text('$value de $total', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: '$label: $value de $total',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : value / total,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, required this.detail, this.chip, this.brand = false});

  final String name;
  final String detail;
  final String? chip;

  /// Pinta las iniciales en rojo (alguien que necesita apoyo).
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: brand ? AppColors.brandSoft : AppColors.surfaceAlt,
            child: Text(
              PersonName.initials(name),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: brand ? AppColors.brand : AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(PersonName.short(name), style: AppTextStyles.itemTitle),
                Text(detail, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (chip != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chip!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text, style: AppTextStyles.body, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
