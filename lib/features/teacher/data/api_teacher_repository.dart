import '../../../core/network/api_client.dart';
import '../../alerts/data/alert_mapper.dart';
import '../../alerts/domain/alert.dart';
import '../../alerts/domain/safety_report.dart';
import '../domain/teacher_repository.dart';

/// Lo que el docente le pide al colegio, contra la API real.
///
/// Los errores del servidor llegan como [ApiException] con el mensaje ya escrito
/// para quien lo lee: «Ya hay una alerta activa», «Ese estudiante no es de tus
/// grupos». Las pantallas lo muestran tal cual, porque dice qué hacer.
class ApiTeacherRepository implements TeacherRepository {
  const ApiTeacherRepository(this._api);

  final ApiClient _api;

  @override
  Future<Alert> issueAlert(AlertDraft draft) async {
    final Map<String, dynamic> response = await _api.post(
      '/alerts',
      body: <String, dynamic>{
        'level': draft.level.wire,
        'hazard': draft.hazard.wire,
        'title': draft.title.trim(),
        'scope': draft.scope.trim(),
        'instructions': draft.instructions,
        // Solo si hay punto de encuentro: el servidor lo exige en la roja y
        // rechaza una cadena vacía.
        if (draft.meetingPoint != null && draft.meetingPoint!.isNotEmpty)
          'meetingPoint': draft.meetingPoint,
        if (draft.incidentId != null) 'incidentId': draft.incidentId,
      },
    );

    // El servidor confirma con la alerta tal como quedó guardada. Si no se puede
    // leer, no se finge que salió bien: la persona tiene que saber que no está
    // segura de haber avisado a 1.248 personas.
    final Alert? alert = AlertMapper.parse(response['alert']);
    if (alert == null) {
      throw const ApiException(
        'El colegio recibió la alerta pero no pudimos confirmarla. Revisa el '
        'tablero antes de volver a emitirla.',
      );
    }
    return alert;
  }

  @override
  Future<void> endAlert(String alertId) async {
    await _api.post('/alerts/${Uri.encodeComponent(alertId)}/end');
  }

  @override
  Future<List<RosterEntry>> loadRoster(String alertId, String grade) async {
    // El grupo lleva grado y símbolo (`10° B`): sin codificar rompería la URL.
    final Map<String, dynamic> response = await _api.get(
      '/alerts/${Uri.encodeComponent(alertId)}/roster'
      '?grade=${Uri.encodeQueryComponent(grade)}',
    );

    final Object? raw = response['students'];
    if (raw is! List<Object?>) {
      return const <RosterEntry>[];
    }

    return <RosterEntry>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) _entry(item),
    ];
  }

  @override
  Future<void> markSafe(String alertId, String personId) async {
    await _api.post(
      '/alerts/${Uri.encodeComponent(alertId)}/roster/'
      '${Uri.encodeComponent(personId)}/safe',
    );
  }

  @override
  Future<int?> loadReach() async {
    final Map<String, dynamic> response = await _api.get('/alerts/reach');
    final Object? people = response['people'];
    return people is num ? people.toInt() : null;
  }

  RosterEntry _entry(Map<String, dynamic> item) {
    return RosterEntry(
      personId: item['personId'] as String? ?? '',
      fullName: item['fullName'] as String? ?? '',
      status: _status(item['status'] as String?),
      location: _location(item['location'] as String?),
      reportedAt: DateTime.tryParse(item['reportedAt'] as String? ?? '')?.toLocal(),
    );
  }

  static SafetyStatus? _status(String? wire) {
    for (final SafetyStatus status in SafetyStatus.values) {
      if (status.wire == wire) return status;
    }
    return null;
  }

  static ReportedLocation? _location(String? wire) {
    for (final ReportedLocation location in ReportedLocation.values) {
      if (location.wire == wire) return location;
    }
    return null;
  }
}
