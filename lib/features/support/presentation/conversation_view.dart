import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/support_repository.dart';

/// Una conversación con sus mensajes y la caja para escribir.
///
/// La usan los dos lados del chat: la persona (su única conversación con el
/// colegio) y el colegio (la conversación que abrió de una lista). Lo que cambia
/// entre uno y otro es de dónde se carga y a dónde se envía, que llega como
/// funciones; el resto —burbujas, caja, reintento, avisos en vivo— es igual.
class ConversationView extends StatefulWidget {
  const ConversationView({
    required this.load,
    required this.send,
    required this.emptyTitle,
    required this.emptyHint,
    this.onLoaded,
    super.key,
  });

  final Future<SupportConversation> Function() load;
  final Future<SupportMessage> Function(String body) send;

  /// Lo que se ve mientras no hay mensajes.
  final String emptyTitle;
  final String emptyHint;

  /// Se llama cada vez que la conversación se carga, para que la pantalla de
  /// arriba ponga al día su cabecera (quién atiende).
  final void Function(SupportThread thread)? onLoaded;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  static const int maxLength = 1000;

  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<SupportMessage> _messages = <SupportMessage>[];
  StreamSubscription<LiveChange>? _live;
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange change) => change == LiveChange.chat)
          .listen((_) => _refresh());
      _refresh();
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final SupportConversation conversation = await widget.load();
      if (!mounted) return;
      final bool grew = conversation.messages.length != _messages.length;
      setState(() {
        _messages = conversation.messages;
        _loading = false;
        _failed = false;
      });
      widget.onLoaded?.call(conversation.thread);
      if (grew) _scrollToEnd();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'chat');
      if (mounted) {
        setState(() {
          _loading = false;
          // Con mensajes ya en pantalla, un fallo al refrescar no los borra.
          _failed = _messages.isEmpty;
        });
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _canSend => !_sending && _text.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    final String body = _text.text.trim();

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      final SupportMessage sent = await widget.send(body);
      if (!mounted) return;
      // El texto se borra solo cuando el servidor lo recibió: si falla, lo
      // escrito se queda para reintentar y no se pierde.
      _text.clear();
      setState(() => _messages = <SupportMessage>[..._messages, sent]);
      _scrollToEnd();
    } on ApiException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'enviar mensaje');
      if (mounted) {
        setState(
          () => _sendError = 'No se envió. Revisa tu conexión e intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(child: _body()),
        _composer(),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'No pudimos abrir la conversación.',
                style: AppTextStyles.itemTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _refresh();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_outlined, color: AppColors.brand),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.emptyTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.emptyHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('mensajes'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.lg,
      ),
      itemCount: _messages.length,
      itemBuilder: (BuildContext context, int index) {
        final SupportMessage message = _messages[index];
        final SupportMessage? previous = index == 0 ? null : _messages[index - 1];
        return Column(
          children: <Widget>[
            if (previous == null || !_sameDay(previous.createdAt, message.createdAt))
              _DayLabel(message.createdAt),
            _Bubble(message: message),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _composer() {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      _sendError!,
                      key: const Key('error-envio'),
                      style: const TextStyle(fontSize: 12, color: AppColors.brand),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('escribir-mensaje'),
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje…',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                      color: _canSend ? AppColors.brand : AppColors.border,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const Key('enviar-mensaje'),
                        customBorder: const CircleBorder(),
                        onTap: _canSend ? _send : null,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(13),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onBrand,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: AppColors.onBrand,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final bool mine = !message.fromStaff;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (message.urgent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.priority_high,
                        size: 13,
                        color: mine ? AppColors.onBrand : AppColors.brand,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'PIDE AYUDA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: mine ? AppColors.onBrand : AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!mine && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: mine ? AppColors.onBrand : AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _hour(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hour(DateTime at) {
    final int hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final String minutes = at.minute.toString().padLeft(2, '0');
    return '$hour:$minutes ${at.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.day);

  final DateTime day;

  static const List<String> _months = <String>[
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool today =
        now.year == day.year && now.month == day.month && now.day == day.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        today ? 'Hoy' : '${day.day} de ${_months[day.month - 1]}',
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
