import '../../../core/network/api_client.dart';
import '../../alerts/data/alert_mapper.dart';
import '../../alerts/domain/alert.dart';
import '../../onboarding/domain/enrollment.dart';
import '../domain/coordination_repository.dart';

/// Coordinación contra la API del colegio.
class ApiCoordinationRepository implements CoordinationRepository {
  ApiCoordinationRepository(this._api);

  final ApiClient _api;

  static String _enc(String value) => Uri.encodeComponent(value);

  /// El servidor guarda `YYYY-MM-DD HH:MM:SS` en UTC y a veces lo manda ya en
  /// ISO; se aceptan los dos.
  static DateTime _date(Object? raw) =>
      DateTime.tryParse(raw as String? ?? '')?.toLocal() ?? DateTime.now();

  static List<Map<String, dynamic>> _maps(Object? raw) => <Map<String, dynamic>>[
        if (raw is List<Object?>)
          for (final Object? item in raw)
            if (item is Map<String, dynamic>) item,
      ];

  @override
  Future<Alert?> sendAlertNote(String alertId, String note) async {
    final Map<String, dynamic> raw =
        await _api.post('/alerts/${_enc(alertId)}/note', body: <String, dynamic>{'note': note});
    return AlertMapper.parse(raw['alert']);
  }

  @override
  Future<List<Responder>> loadResponders() async {
    final Map<String, dynamic> raw = await _api.get('/alerts/responders');
    return <Responder>[
      for (final Map<String, dynamic> item in _maps(raw['responders']))
        Responder(
          id: item['id'] as String? ?? '',
          fullName: item['fullName'] as String? ?? '',
          isCoordination: item['role'] == 'administrador',
        ),
    ];
  }

  @override
  Future<void> assignHelp(String alertId, String personId, String assigneeId) async {
    await _api.post(
      '/alerts/${_enc(alertId)}/help/${_enc(personId)}/assign',
      body: <String, dynamic>{'assigneeId': assigneeId},
    );
  }

  @override
  Future<List<HelpAssignment>> loadHelpAssignments(String alertId) async {
    final Map<String, dynamic> raw = await _api.get('/alerts/${_enc(alertId)}/help-assignments');
    return <HelpAssignment>[
      for (final Map<String, dynamic> item in _maps(raw['assignments']))
        HelpAssignment(
          personId: item['personId'] as String? ?? '',
          assigneeId: item['assigneeId'] as String? ?? '',
          assignee: item['assignee'] as String? ?? '',
          assignedAt: _date(item['assignedAt']),
        ),
    ];
  }

  @override
  Future<List<DeliveredRoster>> loadDeliveredRosters(String alertId) async {
    final Map<String, dynamic> raw = await _api.get('/alerts/${_enc(alertId)}/roster-submissions');
    int count(Map<String, dynamic> item, String key) => (item[key] as num?)?.toInt() ?? 0;
    return <DeliveredRoster>[
      for (final Map<String, dynamic> item in _maps(raw['submissions']))
        DeliveredRoster(
          grade: item['grade'] as String? ?? '',
          teacher: item['teacher'] as String? ?? '',
          safe: count(item, 'safe'),
          needHelp: count(item, 'needHelp'),
          pending: count(item, 'pending'),
          submittedAt: _date(item['submittedAt']),
        ),
    ];
  }

  @override
  Future<EmergencyTask?> loadEmergencyTask(String teacherId) async {
    final Map<String, dynamic> raw = await _api.get('/community/${_enc(teacherId)}/emergency-task');
    final Object? task = raw['task'];
    if (task is! Map<String, dynamic>) return null;
    final String title = (task['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;
    final String? detail = (task['detail'] as String?)?.trim();
    return EmergencyTask(title: title, detail: detail == null || detail.isEmpty ? null : detail);
  }

  @override
  Future<void> saveEmergencyTask(String teacherId, EmergencyTask task) async {
    await _api.put(
      '/community/${_enc(teacherId)}/emergency-task',
      body: <String, dynamic>{'title': task.title, 'detail': task.detail ?? ''},
    );
  }

  @override
  Future<void> clearEmergencyTask(String teacherId) async {
    await _api.delete('/community/${_enc(teacherId)}/emergency-task');
  }

  @override
  Future<SupportPlan> loadSupportPlan(String studentId) async {
    final Map<String, dynamic> raw = await _api.get('/community/${_enc(studentId)}/support-buddies');
    return SupportPlan(
      need: raw['need'] as String?,
      buddies: <SupportBuddy>[
        for (final Map<String, dynamic> item in _maps(raw['buddies']))
          SupportBuddy(
            id: item['id'] as String? ?? '',
            fullName: item['fullName'] as String? ?? '',
            grade: item['grade'] as String?,
          ),
      ],
    );
  }

  @override
  Future<void> addSupportBuddy(String studentId, String buddyId) async {
    await _api.post(
      '/community/${_enc(studentId)}/support-buddies',
      body: <String, dynamic>{'buddyId': buddyId},
    );
  }

  @override
  Future<void> removeSupportBuddy(String studentId, String buddyId) async {
    await _api.delete('/community/${_enc(studentId)}/support-buddies/${_enc(buddyId)}');
  }
}
