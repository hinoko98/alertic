import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_scope.dart';
import '../../../app/shell_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/design/screen_header.dart';
import '../../alerts/domain/protocol.dart';
import '../../support/presentation/support_chat_screen.dart';
import '../domain/risk_assistant.dart';

/// El asistente de riesgos: el botón «Ayuda» de la cabecera.
///
/// Responde con los protocolos del colegio y manda a reportar un riesgo o a
/// hablar con una persona. La línea 123 está siempre arriba: si es una emergencia
/// de verdad, no hay que escribirle a nadie.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Turn {
  const _Turn(this.text, {required this.mine});

  final String text;
  final bool mine;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = <_Turn>[const _Turn(RiskAssistant.greeting, mine: false)];

  RiskAssistant _assistant = const RiskAssistant(<Protocol>[]);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadProtocols();
    }
  }

  Future<void> _loadProtocols() async {
    try {
      final List<Protocol> protocols =
          await AppScope.of(context).alertRepository.loadProtocols();
      if (mounted) setState(() => _assistant = RiskAssistant(protocols));
    } catch (error, stack) {
      // Sin protocolos el asistente sigue sirviendo para reportar y para hablar
      // con alguien; solo no sabe qué hacer ante cada amenaza.
      ErrorReporter.report(error, stack, context: 'protocolos del asistente');
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final String clean = question.trim();
    if (clean.isEmpty) return;

    final AssistantReply reply = _assistant.answer(clean);
    setState(() {
      _turns
        ..add(_Turn(clean, mine: true))
        ..add(_Turn(reply.text, mine: false));
      _text.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });

    if (reply.action != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _go(reply.action!);
      });
    }
  }

  void _go(AssistantAction action) {
    final ShellScope? shell = ShellScope.maybeOf(context);
    final NavigatorState navigator = Navigator.of(context);

    switch (action) {
      case AssistantAction.reportRisk:
        navigator.pop();
        shell?.openTab('Reportar');
      case AssistantAction.talkToSomeone:
        if (shell == null || shell.chatInHeader) {
          navigator.pushReplacement<void, void>(
            MaterialPageRoute<void>(builder: (_) => const SupportChatScreen()),
          );
        } else {
          navigator.pop();
          shell.openTab('Mensajes');
        }
    }
  }

  Future<void> _call123() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool opened = await launchUrl(Uri(scheme: 'tel', path: '123'));
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No pudimos abrir el teléfono. Marca el 123.')),
        );
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'llamar al 123');
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el teléfono. Marca el 123.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          AppScreenHeader(
            title: 'Asistente de riesgos',
            subtitle: 'Responde con los protocolos del colegio',
            onBack: () => Navigator.of(context).maybePop(),
            showHelp: false,
          ),
          _EmergencyBar(onCall: _call123),
          Expanded(
            child: ListView.builder(
              key: const Key('turnos-asistente'),
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              itemCount: _turns.length,
              itemBuilder: (BuildContext context, int index) =>
                  _TurnBubble(turn: _turns[index]),
            ),
          ),
          _QuickReplies(onPick: _ask),
          _Composer(controller: _text, onSend: _ask),
        ],
      ),
    );
  }
}

class _EmergencyBar extends StatelessWidget {
  const _EmergencyBar({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.phone_in_talk_outlined, size: 18, color: AppColors.onBrand),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              '¿Emergencia real? Llama a la Línea 123',
              style: TextStyle(fontSize: 12, color: AppColors.onBrand),
            ),
          ),
          Material(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: const Key('llamar-123'),
              borderRadius: BorderRadius.circular(999),
              onTap: onCall,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  'Llamar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBrand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: turn.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: turn.mine ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(turn.mine ? 16 : 4),
              bottomRight: Radius.circular(turn.mine ? 4 : 16),
            ),
            border: turn.mine ? null : Border.all(color: AppColors.border),
          ),
          child: Text(
            turn.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: turn.mine ? AppColors.onBrand : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    // Seis botones: una fila que se desplaza, no una lista perezosa. Así todos
    // existen aunque no quepan en pantalla.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
        child: Row(
          children: <Widget>[
            for (final String label in RiskAssistant.quickReplies) ...<Widget>[
              ActionChip(
                label: Text(label),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                onPressed: () => onPick(label),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('pregunta-asistente'),
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                  decoration: InputDecoration(
                    hintText: 'Pregunta sobre un riesgo…',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.brand,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('enviar-pregunta'),
                  customBorder: const CircleBorder(),
                  onTap: () => onSend(controller.text),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.send_rounded, size: 20, color: AppColors.onBrand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
