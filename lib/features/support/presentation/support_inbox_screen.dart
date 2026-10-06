import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/shell_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/design/screen_header.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/support_repository.dart';
import 'conversation_view.dart';

/// La bandeja de mensajes del colegio: las conversaciones que le tocan a quien
/// mira. Coordinación ve todas; un docente, las que le asignaron.
class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({this.canAssign = false, super.key});

  /// Coordinación puede pasarle una conversación a un docente.
  final bool canAssign;

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  List<SupportThread> _threads = <SupportThread>[];
  StreamSubscription<LiveChange>? _live;
  bool _loading = true;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange change) => change == LiveChange.chat)
          .listen((_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<SupportThread> threads =
          await AppScope.of(context).supportRepository!.loadThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _loading = false;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'bandeja de mensajes');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = _threads.isEmpty;
        });
      }
    }
  }

  Future<void> _open(SupportThread thread) async {
    final ShellScope? shell = ShellScope.maybeOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SupportThreadScreen(
          thread: thread,
          canAssign: widget.canAssign,
        ),
      ),
    );
    shell?.refreshChatUnread();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final int unread = _threads.where((SupportThread t) => t.unread > 0).length;

    return Column(
      children: <Widget>[
        AppScreenHeader(
          title: 'Mensajes',
          subtitle: unread == 0
              ? 'Estudiantes y acudientes que te escriben'
              : '$unread ${unread == 1 ? 'conversación' : 'conversaciones'} sin leer',
          showHelp: false,
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          child: const Text('No pudimos cargar los mensajes. Reintentar'),
        ),
      );
    }
    if (_threads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Todavía no hay mensajes. Cuando un estudiante o un acudiente '
            'escriba, aparece aquí.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        itemCount: _threads.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) =>
            _ThreadTile(thread: _threads[index], onTap: () => _open(_threads[index])),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final SupportThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool unread = thread.unread > 0;
    final String initials = _initials(thread.personName ?? '');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: unread ? AppColors.brandSoft : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: unread ? AppColors.brand : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        thread.personName ?? 'Sin nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                    ),
                    if (thread.lastMessageAt != null)
                      Text(_when(thread.lastMessageAt!), style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${thread.lastFromStaff ? 'Tú: ' : ''}${thread.lastPreview ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    color: unread ? AppColors.ink : AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    Pill(_role(thread.personRole)),
                    if (thread.personGrade != null) Pill(thread.personGrade!),
                    if (thread.urgent)
                      const Pill('PIDE AYUDA', tone: PillTone.brand, icon: Icons.priority_high),
                    if (thread.assignedTo == null)
                      const Pill('Sin asignar', tone: PillTone.warning),
                  ],
                ),
              ],
            ),
          ),
          if (unread) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts =
        name.split(' ').where((String part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  static String _role(String? role) => switch (role) {
        'estudiante' => 'Estudiante',
        'acudiente' => 'Acudiente',
        _ => 'Persona',
      };

  static String _when(DateTime at) {
    final Duration ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'ahora';
    if (ago.inHours < 1) return 'hace ${ago.inMinutes} min';
    if (ago.inDays < 1) return 'hace ${ago.inHours} h';
    return 'hace ${ago.inDays} d';
  }
}

/// Una conversación abierta desde la bandeja.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({
    required this.thread,
    this.canAssign = false,
    super.key,
  });

  final SupportThread thread;
  final bool canAssign;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late SupportThread _thread = widget.thread;

  Future<void> _assign() async {
    final SupportRepository repository = AppScope.of(context).supportRepository!;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    List<SupportAssignee> teachers;
    try {
      teachers = await repository.loadAssignees();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'docentes para asignar');
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos traer a los docentes.')),
      );
      return;
    }
    if (!mounted) return;

    final ({bool picked, String? id})? choice =
        await showModalBottomSheet<({bool picked, String? id})>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('¿Quién atiende esta conversación?', style: AppTextStyles.itemTitle),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Solo coordinación'),
              selected: _thread.assignedTo == null,
              onTap: () => Navigator.of(context).pop((picked: true, id: null)),
            ),
            for (final SupportAssignee teacher in teachers)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(teacher.fullName),
                selected: _thread.assignedTo?.id == teacher.id,
                onTap: () => Navigator.of(context).pop((picked: true, id: teacher.id)),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !choice.picked) return;

    try {
      final SupportThread updated = await repository.assign(_thread.id, choice.id);
      if (mounted) setState(() => _thread = _merge(updated));
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'asignar conversación');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo asignar. Intenta otra vez.')),
      );
    }
  }

  /// La respuesta de asignar no trae de quién es la conversación: se conserva lo
  /// que ya se sabía.
  SupportThread _merge(SupportThread updated) => SupportThread(
        id: updated.id,
        unread: updated.unread,
        assignedTo: updated.assignedTo,
        lastPreview: updated.lastPreview ?? _thread.lastPreview,
        lastFromStaff: updated.lastFromStaff,
        lastMessageAt: updated.lastMessageAt ?? _thread.lastMessageAt,
        personId: updated.personId ?? _thread.personId,
        personName: updated.personName ?? _thread.personName,
        personRole: updated.personRole ?? _thread.personRole,
        personGrade: updated.personGrade ?? _thread.personGrade,
      );

  @override
  Widget build(BuildContext context) {
    final SupportRepository repository = AppScope.of(context).supportRepository!;
    final String grade = _thread.personGrade == null ? '' : ' · ${_thread.personGrade}';
    final String who = _thread.assignedTo?.fullName ?? 'solo coordinación';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          AppScreenHeader(
            title: _thread.personName ?? 'Conversación',
            subtitle: 'Atiende: $who$grade',
            onBack: () => Navigator.of(context).maybePop(),
            showHelp: false,
            actions: <Widget>[
              // Asignar es de coordinación: el servidor lo exige, y la bandeja del
              // docente no lo ofrece.
              if (widget.canAssign)
                IconButton(
                  key: const Key('asignar-conversacion'),
                  tooltip: 'Asignar',
                  onPressed: _assign,
                  icon: const Icon(Icons.swap_horiz),
                ),
            ],
          ),
          Expanded(
            child: ConversationView(
              load: () => repository.loadThread(_thread.id),
              send: (String body) => repository.reply(_thread.id, body),
              onLoaded: (SupportThread thread) {
                if (mounted) setState(() => _thread = _merge(thread));
              },
              emptyTitle: 'Sin mensajes',
              emptyHint: 'Escribe para empezar la conversación.',
            ),
          ),
        ],
      ),
    );
  }
}
