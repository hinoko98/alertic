import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../alerts/domain/alert.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../domain/teacher_repository.dart';

/// «Tu tarea · director de 9.° B»: lo que le toca a este docente en la alerta.
///
/// Tres pasos: proteger al grupo (el primero de la alerta), llevarlo al punto
/// (la tarea que asignó coordinación, o el punto de la alerta si no asignó una) y
/// pasar lista al llegar. Debajo, si en su grupo hay alguien que necesita apoyo
/// para salir, quién lo acompaña: es lo que un docente no puede improvisar.
class TeacherAlertTask extends StatefulWidget {
  const TeacherAlertTask({required this.alert, required this.teacher, super.key});

  final Alert alert;
  final TeacherEnrollment teacher;

  @override
  State<TeacherAlertTask> createState() => _TeacherAlertTaskState();
}

class _TeacherAlertTaskState extends State<TeacherAlertTask> {
  GroupOverview? _overview;
  bool _started = false;

  String? get _grade => widget.teacher.primaryGroup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final String? grade = _grade;
    final TeacherRepository? teachers = AppScope.of(context).teacherRepository;
    if (grade == null || teachers == null) return;
    try {
      final GroupOverview overview = await teachers.loadGroupOverview(grade);
      if (mounted) setState(() => _overview = overview);
    } catch (error, stack) {
      // Sin el resumen la tarea se ve igual; solo falta la nota de apoyo.
      ErrorReporter.report(error, stack, context: 'apoyo en el grupo');
    }
  }

  List<String> _steps() {
    final EmergencyTask? task = widget.teacher.emergencyTask;
    final String? point = widget.alert.meetingPoint;
    final String grade = _grade ?? 'tu grupo';

    final String move = task != null
        ? <String>[task.title, if (task.detail != null && task.detail!.isNotEmpty) task.detail!]
            .join(' · ')
        : point != null
            ? 'Guía a $grade al punto $point.'
            : 'Mantén a $grade contigo hasta nueva orden.';

    return <String>[
      widget.alert.instructions.first,
      move,
      'Pasa lista en la app apenas lleguen.',
    ];
  }

  static String _names(List<String> names) {
    final List<String> first = names.map(PersonName.firstName).toList();
    if (first.length <= 1) return first.join();
    return '${first.sublist(0, first.length - 1).join(', ')} y ${first.last}';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> steps = _steps();
    final List<SupportedStudent> supported = _overview?.needsSupport ?? const <SupportedStudent>[];
    final String role = widget.teacher.homeroomGroup == _grade ? 'DIRECTOR' : 'DOCENTE';

    return Column(
      children: <Widget>[
        Container(
          key: const Key('tarea-en-alerta'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'TU TAREA · $role DE ${(_grade ?? 'TU GRUPO').toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF8A1C2D),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (int i = 0; i < steps.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.levelRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final SupportedStudent student in supported)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              key: const Key('apoyo-en-el-grupo'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.accessible_forward, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      student.buddies.isEmpty
                          ? '${PersonName.short(student.fullName)} necesita apoyo para salir.'
                          : '${PersonName.short(student.fullName)} necesita apoyo: lo '
                              'acompañan ${_names(student.buddies)}.',
                      style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
