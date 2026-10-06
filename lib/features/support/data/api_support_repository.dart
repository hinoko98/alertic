import '../../../core/network/api_client.dart';
import '../domain/support_repository.dart';

/// El chat con el soporte del colegio, contra la API.
class ApiSupportRepository implements SupportRepository {
  const ApiSupportRepository(this._api);

  final ApiClient _api;

  @override
  Future<SupportConversation> loadMine() async =>
      _conversation(await _api.get('/support/me'));

  @override
  Future<SupportMessage> sendMine(String body, {bool urgent = false}) async => _message(
        (await _api.post(
          '/support/me/messages',
          body: <String, dynamic>{'body': body, if (urgent) 'urgent': true},
        ))['message'],
      );

  @override
  Future<int> unreadCount() async {
    final Map<String, dynamic> raw = await _api.get('/support/unread');
    return (raw['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<SupportThread>> loadThreads() async {
    final Map<String, dynamic> raw = await _api.get('/support/threads');
    final Object? items = raw['threads'];
    return <SupportThread>[
      if (items is List<Object?>)
        for (final Object? item in items)
          if (item is Map<String, dynamic>) _thread(item),
    ];
  }

  @override
  Future<SupportConversation> loadThread(String id) async =>
      _conversation(await _api.get('/support/threads/${Uri.encodeComponent(id)}'));

  @override
  Future<SupportMessage> reply(String threadId, String body) async => _message(
        (await _api.post(
          '/support/threads/${Uri.encodeComponent(threadId)}/messages',
          body: <String, dynamic>{'body': body},
        ))['message'],
      );

  @override
  Future<SupportThread> assign(String threadId, String? teacherId) async {
    final Map<String, dynamic> raw = await _api.patch(
      '/support/threads/${Uri.encodeComponent(threadId)}',
      body: <String, dynamic>{'assignedTo': teacherId},
    );
    return _thread(raw['thread'] as Map<String, dynamic>);
  }

  @override
  Future<List<SupportAssignee>> loadAssignees() async {
    final Map<String, dynamic> raw = await _api.get('/support/assignees');
    final Object? items = raw['teachers'];
    return <SupportAssignee>[
      if (items is List<Object?>)
        for (final Object? item in items)
          if (item is Map<String, dynamic>)
            SupportAssignee(
              id: item['id'] as String? ?? '',
              fullName: item['fullName'] as String? ?? '',
            ),
    ];
  }

  static SupportConversation _conversation(Map<String, dynamic> raw) {
    final Object? messages = raw['messages'];
    return SupportConversation(
      thread: _thread(raw['thread'] as Map<String, dynamic>),
      messages: <SupportMessage>[
        if (messages is List<Object?>)
          for (final Object? item in messages)
            if (item is Map<String, dynamic>) _message(item),
      ],
    );
  }

  static SupportMessage _message(Object? raw) {
    final Map<String, dynamic> item = raw as Map<String, dynamic>;
    return SupportMessage(
      id: item['id'] as String? ?? '',
      fromStaff: item['fromStaff'] as bool? ?? false,
      urgent: item['urgent'] as bool? ?? false,
      senderName: item['senderName'] as String?,
      body: item['body'] as String? ?? '',
      createdAt: DateTime.tryParse(item['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  static SupportThread _thread(Map<String, dynamic> raw) {
    final Object? assigned = raw['assignedTo'];
    final Object? last = raw['lastMessage'];
    final Object? person = raw['person'];

    return SupportThread(
      id: raw['id'] as String? ?? '',
      unread: (raw['unread'] as num?)?.toInt() ?? 0,
      urgent: raw['urgent'] as bool? ?? false,
      assignedTo: assigned is Map<String, dynamic>
          ? SupportAssignee(
              id: assigned['id'] as String? ?? '',
              fullName: assigned['fullName'] as String? ?? '',
            )
          : null,
      lastPreview: last is Map<String, dynamic> ? last['preview'] as String? : null,
      lastFromStaff: last is Map<String, dynamic> && (last['fromStaff'] as bool? ?? false),
      lastMessageAt: DateTime.tryParse(raw['lastMessageAt'] as String? ?? '')?.toLocal(),
      personId: person is Map<String, dynamic> ? person['id'] as String? : null,
      personName: person is Map<String, dynamic> ? person['fullName'] as String? : null,
      personRole: person is Map<String, dynamic> ? person['role'] as String? : null,
      personGrade: person is Map<String, dynamic> ? person['grade'] as String? : null,
    );
  }
}
