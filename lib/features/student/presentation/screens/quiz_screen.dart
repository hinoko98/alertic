import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../domain/quiz.dart';

/// Pantalla 29: «Pon a prueba lo que sabes».
///
/// Cinco preguntas de una en una. Al contestar se dice si estuvo bien **y por
/// qué**, porque lo que se quiere es que la persona se lleve la regla, no una
/// nota. No se guarda ni se le cuenta al colegio: es para practicar.
class QuizScreen extends StatefulWidget {
  const QuizScreen({this.questions = SismoQuiz.questions, super.key});

  final List<QuizQuestion> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const List<String> _letters = <String>['A', 'B', 'C', 'D', 'E', 'F'];

  int _index = 0;
  int? _picked;
  int _hits = 0;
  bool _finished = false;

  QuizQuestion get _question => widget.questions[_index];
  bool get _answered => _picked != null;
  bool get _isLast => _index == widget.questions.length - 1;

  void _pick(int option) {
    if (_answered) return;
    setState(() {
      _picked = option;
      if (option == _question.correct) _hits++;
    });
  }

  void _next() {
    if (_isLast) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _picked = null;
    });
  }

  void _restart() => setState(() {
        _index = 0;
        _picked = null;
        _hits = 0;
        _finished = false;
      });

  @override
  Widget build(BuildContext context) {
    final int total = widget.questions.length;

    return AppPage(
      title: 'Pon a prueba lo que sabes',
      subtitle: _finished
          ? '${SismoQuiz.title} · resultado'
          : '${SismoQuiz.title} · pregunta ${_index + 1} de $total',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      bottom: _finished
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                  AppSpacing.screenGutter,
                  AppSpacing.md,
                ),
                child: PrimaryButton(
                  key: const Key('siguiente-pregunta'),
                  label: _isLast ? 'Ver mi resultado' : 'Siguiente pregunta',
                  icon: null,
                  onPressed: _answered ? _next : null,
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: _finished ? _result(total) : _questionView(total),
      ),
    );
  }

  List<Widget> _questionView(int total) {
    final QuizQuestion q = _question;
    final bool right = _picked == q.correct;

    return <Widget>[
      Row(
        children: <Widget>[
          for (int i = 0; i < total; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  // Las ya contestadas en verde, la actual en el color de marca.
                  color: i < _index || (i == _index && _answered)
                      ? AppColors.success
                      : i == _index
                          ? AppColors.brand
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(q.text, key: const Key('pregunta'), style: AppTextStyles.screenTitle.copyWith(fontSize: 24)),
      const SizedBox(height: AppSpacing.lg),
      for (int i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _Option(
            key: Key('opcion-$i'),
            letter: _letters[i],
            text: q.options[i],
            state: !_answered
                ? _OptionState.idle
                : i == q.correct
                    ? _OptionState.correct
                    : i == _picked
                        ? _OptionState.wrong
                        : _OptionState.idle,
            onTap: _answered ? null : () => _pick(i),
          ),
        ),
      if (_answered) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: const Key('retroalimentacion'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: right ? AppColors.successSoft : AppColors.warningSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: right ? const Color(0xFFBFDCCB) : const Color(0xFFF1D9A6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    right ? Icons.check : Icons.info_outline,
                    size: 20,
                    color: right ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    right ? '¡Correcto!' : 'No era esa',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: right ? const Color(0xFF133F29) : const Color(0xFF5E3D00),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                q.explanation,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: right ? const Color(0xFF2E5A43) : const Color(0xFF5E3D00),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _result(int total) {
    final bool great = _hits == total;
    return <Widget>[
      const SizedBox(height: AppSpacing.xl),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: great ? AppColors.successSoft : AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            great ? Icons.emoji_events_outlined : Icons.menu_book_outlined,
            size: 44,
            color: great ? AppColors.success : AppColors.brand,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Acertaste $_hits de $total',
        key: const Key('resultado-quiz'),
        textAlign: TextAlign.center,
        style: AppTextStyles.screenTitle,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        great
            ? 'Te sabes la regla. Cuando tiemble, hazla sin pensar.'
            : 'Repasa la guía de sismo y vuelve a intentarlo: lo importante es que '
                'la regla te salga sola.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.xl),
      PrimaryButton(
        key: const Key('repetir-quiz'),
        label: 'Intentar de nuevo',
        icon: Icons.refresh,
        onPressed: _restart,
      ),
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        label: 'Volver a las guías',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ];
  }
}

enum _OptionState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color background, Color badge, Color badgeText) = switch (state) {
      _OptionState.correct => (
          AppColors.success,
          AppColors.successSoft,
          AppColors.success,
          Colors.white,
        ),
      _OptionState.wrong => (
          AppColors.brand,
          AppColors.brandSoft,
          AppColors.brand,
          Colors.white,
        ),
      _OptionState.idle => (
          AppColors.border,
          AppColors.surface,
          const Color(0xFFE7EAEE),
          AppColors.inkMuted,
        ),
    };

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        side: BorderSide(color: border, width: state == _OptionState.idle ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
                  child: Text(
                    letter,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: badgeText),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
