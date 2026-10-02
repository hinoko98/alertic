import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/sign_out.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/presentation/widgets/identity_card.dart';

/// Perfil: quién es la persona para el colegio, y qué alertas ha habido.
///
/// El historial vive aquí y no en una pestaña propia: se consulta en frío, no
/// durante una emergencia, y así la barra inferior se queda con las tres cosas
/// que sí se usan con la alarma sonando.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.student, super.key});

  final StudentEnrollment student;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<List<Alert>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= _loadHistory();
  }

  Future<List<Alert>> _loadHistory() async {
    try {
      return await AppScope.of(context).alertRepository.loadHistory();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cargar historial');
      rethrow;
    }
  }

  Future<void> _signOut() => confirmAndSignOut(
        context,
        message: SignOutMessages.withCode,
      );

  @override
  Widget build(BuildContext context) {
    final StudentEnrollment student = widget.student;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: <Widget>[
            const Text('TU PERFIL', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.lg),
            IdentityCard(
              children: <Widget>[
                IdentityHeader(
                  role: student.roleLabel,
                  fullName: student.fullName,
                ),
                const Divider(height: 1),
                DetailRow(
                  label: 'Grado',
                  value: '${student.grade} · ${student.shift}',
                ),
                const Divider(height: 1),
                DetailRow(label: 'Salón', value: student.classroom),
                const Divider(height: 1),
                DetailRow(
                  label: 'Punto de encuentro',
                  value: '${student.meetingPoint.code} · '
                      '${student.meetingPoint.name}',
                ),
                const Divider(height: 1),
                const _SectionLabel('Acudientes vinculados'),
                for (final GuardianLink guardian in student.guardians)
                  LinkedPersonRow(
                    name: guardian.fullName,
                    detail: guardian.relationship,
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const LockedDataNote(
              message: 'El colegio registró estos datos. Si algo está mal, '
                  'avisa en secretaría.',
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('HISTORIAL DE ALERTAS', style: AppTextStyles.eyebrow),
            const SizedBox(height: AppSpacing.sm),
            _History(future: _history),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.border),
                shape: const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              ),
              child: Text('CERRAR SESIÓN', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.future});

  final Future<List<Alert>>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Alert>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
        if (snapshot.hasError) {
          return Text(
            'No pudimos cargar el historial.',
            style: AppTextStyles.caption,
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }

        final List<Alert> alerts = snapshot.data!;
        if (alerts.isEmpty) {
          return Text(
            'Todavía no ha habido alertas este año.',
            style: AppTextStyles.caption,
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < alerts.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                _HistoryRow(alert: alerts[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(alert.level);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(width: 6, height: 36, color: style.headerColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(alert.title, style: AppTextStyles.itemTitle),
                const SizedBox(height: 2),
                Text(
                  '${alert.level.label} · ${_dateLabel(alert.issuedAt)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const List<String> months = <String>[
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(label.toUpperCase(), style: AppTextStyles.eyebrow),
    );
  }
}
