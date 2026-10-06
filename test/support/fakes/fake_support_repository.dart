import 'dart:async';

import 'package:alertic/features/alerts/domain/live_updates.dart';
import 'package:alertic/features/support/domain/support_repository.dart';

/// Chat con el colegio en memoria, solo para pruebas.
///
/// Una sola conversación: la de quien usa la app, y desde «el colegio» se le
/// puede responder con [staffSays]. Avisa por [changes] como lo haría el canal en
/// vivo del servidor.
class FakeSupportRepository implements SupportRepository, LiveUpdates {
  FakeSupportRepository({this.latency = Duration.zero, this.assignedTo});

  final Duration latency;
  SupportAssignee? assignedTo;

  final List<SupportMessage> messages = <SupportMessage>[];
  final StreamController<LiveChange> _changes =
      StreamController<LiveChange>.broadcast();

  int _next = 1;
  int _unreadForPerson = 0;
  int _unreadForStaff = 0;
  bool failNextSend = false;

  /// Cuántas veces la persona escribió.
  int sent = 0;

  @override
  Stream<LiveChange> get changes => _changes.stream;

  /// El colegio responde.
  void staffSays(String body, {String from = 'Carlos Jaimes'}) {
    messages.add(
      SupportMessage(
        id: '${_next++}',
        fromStaff: true,
        senderName: from,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    _unreadForPerson++;
    _changes.add(LiveChange.chat);
  }

  /// La persona escribió antes de que el colegio abriera la bandeja.
  void personSays(String body) {
    messages.add(
      SupportMessage(
        id: '${_next++}',
        fromStaff: false,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    _unreadForStaff++;
  }

  SupportThread _thread({bool forStaff = false}) => SupportThread(
        id: 't1',
        unread: forStaff ? _unreadForStaff : _unreadForPerson,
        assignedTo: assignedTo,
        lastPreview: messages.isEmpty ? null : messages.last.body,
        lastFromStaff: messages.isNotEmpty && messages.last.fromStaff,
        lastMessageAt: messages.isEmpty ? null : messages.last.createdAt,
        personId: 'p1',
        personName: 'Laura Camila Pérez Gómez',
        personRole: 'estudiante',
        personGrade: '10° B',
      );

  @override
  Future<SupportConversation> loadMine() async {
    await Future<void>.delayed(latency);
    final SupportThread thread = _thread();
    _unreadForPerson = 0;
    return SupportConversation(
      thread: thread,
      messages: List<SupportMessage>.of(messages),
    );
  }

  @override
  Future<SupportMessage> sendMine(String body, {bool urgent = false}) async {
    await Future<void>.delayed(latency);
    if (failNextSend) {
      failNextSend = false;
      throw StateError('sin conexión');
    }
    final SupportMessage message = SupportMessage(
      id: '${_next++}',
      fromStaff: false,
      urgent: urgent,
      body: body.trim(),
      createdAt: DateTime.now(),
    );
    messages.add(message);
    sent++;
    _unreadForStaff++;
    return message;
  }

  @override
  Future<int> unreadCount() async => _unreadForPerson;

  @override
  Future<List<SupportThread>> loadThreads() async {
    await Future<void>.delayed(latency);
    return messages.isEmpty ? <SupportThread>[] : <SupportThread>[_thread(forStaff: true)];
  }

  @override
  Future<SupportConversation> loadThread(String id) async {
    await Future<void>.delayed(latency);
    final SupportThread thread = _thread(forStaff: true);
    _unreadForStaff = 0;
    return SupportConversation(
      thread: thread,
      messages: List<SupportMessage>.of(messages),
    );
  }

  @override
  Future<SupportMessage> reply(String threadId, String body) async {
    await Future<void>.delayed(latency);
    final SupportMessage message = SupportMessage(
      id: '${_next++}',
      fromStaff: true,
      senderName: 'Coordinación',
      body: body.trim(),
      createdAt: DateTime.now(),
    );
    messages.add(message);
    _unreadForPerson++;
    return message;
  }

  @override
  Future<SupportThread> assign(String threadId, String? teacherId) async {
    await Future<void>.delayed(latency);
    assignedTo = teacherId == null
        ? null
        : const SupportAssignee(id: 'd1', fullName: 'Nubia Silva');
    return _thread(forStaff: true);
  }

  @override
  Future<List<SupportAssignee>> loadAssignees() async => const <SupportAssignee>[
        SupportAssignee(id: 'd1', fullName: 'Nubia Silva'),
        SupportAssignee(id: 'd2', fullName: 'Carlos Jaimes'),
      ];

  void dispose() => _changes.close();
}
