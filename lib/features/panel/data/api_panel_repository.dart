import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../alerts/domain/alert.dart';
import '../../alerts/domain/alert_repository.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/meeting_point.dart';
import '../../alerts/domain/protocol.dart';
import '../domain/community_admin.dart';
import '../domain/panel_repository.dart';

/// El panel del colegio contra la API real.
///
/// Patrón *Adapter*: traduce lo que responde el servidor al modelo del panel, y
/// sus errores HTTP a listas vacías con el motivo en el registro. Las pantallas
/// no saben que existe una red.
///
/// El historial y los protocolos se delegan al [AlertRepository] en vez de
/// duplicar el mapeo: son exactamente los mismos datos que ve la app móvil, y
/// dos mapeos del mismo JSON acaban interpretándolo distinto.
class ApiPanelRepository implements PanelRepository {
  const ApiPanelRepository(this._api, this._alerts);

  final ApiClient _api;
  final AlertRepository _alerts;

  @override
  Future<EmergencyBoard> loadBoard(String alertId) async {
    final Map<String, dynamic> raw = await _api.get('/alerts/$alertId/board');

    return EmergencyBoard(
      safe: _int(raw['safe']),
      needHelp: _int(raw['needHelp']),
      noResponse: _int(raw['noResponse']),
      total: _int(raw['total']),
      byGrade: _list(
        raw['byGrade'],
        (Map<String, dynamic> item) => GradeProgress(
          grade: item['grade'] as String? ?? '',
          safe: _int(item['safe']),
          needHelp: _int(item['needHelp']),
          noResponse: _int(item['noResponse']),
          total: _int(item['total']),
        ),
      ),
      needHelpList: _list(
        raw['needHelpList'],
        (Map<String, dynamic> item) => HelpRequest(
          personId: item['personId'] as String? ?? '',
          fullName: item['fullName'] as String? ?? '',
          grade: item['grade'] as String? ?? '—',
          location: item['location'] as String? ?? 'salon',
          reportedAt:
              DateTime.tryParse(item['reportedAt'] as String? ?? '')?.toLocal() ??
                  DateTime.now(),
          helpKind: item['helpKind'] as String?,
          helpDetails: item['helpDetails'] as String?,
          medicalInfo: item['medicalInfo'] as String?,
        ),
      ),
      byMeetingPoint: _list(
        raw['byMeetingPoint'],
        (Map<String, dynamic> item) => MeetingPointCount(
          code: item['code'] as String? ?? '',
          count: _int(item['count']),
        ),
      ),
    );
  }

  @override
  Future<List<CommunityMember>> loadCommunity({
    String? role,
    String query = '',
  }) async {
    // El texto de búsqueda va codificado: un nombre con tilde o un espacio
    // romperían la URL.
    final String params = <String>[
      if (role != null) 'role=${Uri.encodeQueryComponent(role)}',
      if (query.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(query.trim())}',
    ].join('&');

    final Map<String, dynamic> raw = await _api.get(
      params.isEmpty ? '/community' : '/community?$params',
    );

    return _list(
      raw['people'],
      (Map<String, dynamic> item) => CommunityMember(
        id: item['id'] as String? ?? '',
        fullName: item['fullName'] as String? ?? '',
        role: item['role'] as String? ?? '',
        grade: item['grade'] as String?,
        codeHint: item['codeHint'] as String?,
        code: item['code'] as String?,
        codeStatus: item['codeStatus'] as String? ?? 'sin_generar',
        linkedTo: item['linkedTo'] as String?,
      ),
    );
  }

  @override
  Future<CommunityStats> loadStats() async {
    final Map<String, dynamic> raw = await _api.get('/community/stats');
    final Object? byRole = raw['byRole'];

    return CommunityStats(
      total: _int(raw['total']),
      byRole: <String, int>{
        if (byRole is Map<String, dynamic>)
          for (final MapEntry<String, dynamic> entry in byRole.entries)
            entry.key: _int(entry.value),
      },
      activeCodes: _int(raw['activeCodes']),
      pendingCodes: _int(raw['pendingCodes']),
    );
  }

  @override
  Future<List<HazardSignal>> loadSignals() async {
    final Map<String, dynamic> raw = await _api.get('/hazards/signals');

    return <HazardSignal>[
      for (final Object? item in raw['signals'] as List<Object?>? ?? const <Object?>[])
        if (item is Map<String, dynamic>)
          if (Hazard.tryParse(item['hazard'] as String?) case final Hazard hazard)
            HazardSignal(
              id: item['id'] as String? ?? '',
              source: item['source'] as String? ?? '',
              hazard: hazard,
              headline: item['headline'] as String? ?? '',
              detail: item['detail'] as String? ?? '',
              occurredAt:
                  DateTime.tryParse(item['occurredAt'] as String? ?? '')?.toLocal() ??
                      DateTime.now(),
              magnitude: (item['magnitude'] as num?)?.toDouble(),
              distanceKm: (item['distanceKm'] as num?)?.round(),
            ),
    ];
  }

  @override
  Future<void> dismissSignal(String signalId) async {
    await _api.post('/hazards/signals/$signalId/dismiss');
  }

  @override
  Future<List<Alert>> loadHistory() => _alerts.loadHistory();

  @override
  Future<List<Protocol>> loadProtocols() => _alerts.loadProtocols();

  @override
  Future<List<GroupInfo>> loadGroups() async {
    final Map<String, dynamic> raw = await _api.get('/community/groups');

    return _list(
      raw['groups'],
      (Map<String, dynamic> item) => GroupInfo(
        grade: item['grade'] as String? ?? '',
        enrolled: _int(item['enrolled']),
        classroom: item['classroom'] as String?,
        director: _ref(item['director']),
      ),
    );
  }

  @override
  Future<PersonDetail> loadPerson(String id) async {
    final Map<String, dynamic> raw = await _api.get('/community/${_id(id)}');
    return _detail(raw['person']);
  }

  @override
  Future<PersonUpdate> updatePerson(String id, PersonChanges changes) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.patch('/community/${_id(id)}', body: changes.toJson().cast<String, dynamic>()),
    );
    return PersonUpdate(
      person: _detail(raw['person']),
      replacedDirector: _replaced(raw['replacedDirector']),
    );
  }

  @override
  Future<CreatedTeacher> createTeacher(NewTeacher teacher) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post('/community/teachers', body: teacher.toJson().cast<String, dynamic>()),
    );
    return CreatedTeacher(
      person: _detail(raw['person']),
      temporaryPassword: _secret(raw['temporaryPassword']),
      replacedDirector: _replaced(raw['replacedDirector']),
    );
  }

  @override
  Future<String> resetTeacherPassword(String id) async {
    final Map<String, dynamic> raw =
        await _act(() => _api.post('/community/${_id(id)}/password'));
    return _secret(raw['temporaryPassword']);
  }

  @override
  Future<PersonDetail> deactivateTeacher(String id) async {
    final Map<String, dynamic> raw =
        await _act(() => _api.post('/community/${_id(id)}/deactivate'));
    return _detail(raw['person']);
  }

  @override
  Future<String> renewCode(String id) async {
    final Map<String, dynamic> raw =
        await _act(() => _api.post('/community/${_id(id)}/code'));
    return _secret(raw['code']);
  }

  @override
  Future<void> closeSessions(String id) async {
    await _act(() => _api.post('/community/${_id(id)}/sign-out'));
  }

  @override
  Future<CreatedPerson> createStudent(NewStudent student) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post('/community/students', body: student.toJson().cast<String, dynamic>()),
    );
    return CreatedPerson(person: _detail(raw['person']), code: _secret(raw['code']));
  }

  @override
  Future<CreatedPerson> createGuardian(NewGuardian guardian) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post('/community/guardians', body: guardian.toJson().cast<String, dynamic>()),
    );
    return CreatedPerson(person: _detail(raw['person']), code: _secret(raw['code']));
  }

  @override
  Future<CodeBatch> importStudents(List<NewStudent> students) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post(
        '/community/students/import',
        body: <String, dynamic>{
          'students': <Map<String, Object?>>[
            for (final NewStudent student in students) student.toJson(),
          ],
        },
      ),
    );
    return _batch(raw['created'], role: 'estudiante');
  }

  @override
  Future<CodeBatch> generateCodes({
    required List<String> grades,
    bool includeGuardians = false,
    bool reissue = false,
  }) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post(
        '/community/codes/generate',
        body: <String, dynamic>{
          'grades': grades,
          'includeGuardians': includeGuardians,
          'reissue': reissue,
        },
      ),
    );
    return _batch(
      raw['issued'],
      alreadyRegistered: (raw['alreadyRegistered'] as num?)?.toInt() ?? 0,
    );
  }

  static CodeBatch _batch(Object? raw, {String? role, int alreadyRegistered = 0}) {
    final List<Object?> items = raw is List ? raw.cast<Object?>() : const <Object?>[];
    return CodeBatch(
      alreadyRegistered: alreadyRegistered,
      codes: <IssuedCode>[
        for (final Object? item in items)
          if (item is Map<String, dynamic>)
            IssuedCode(
              personId: item['personId'] as String? ?? '',
              fullName: item['fullName'] as String? ?? '',
              role: item['role'] as String? ?? role ?? '',
              grade: item['grade'] as String?,
              code: _secret(item['code']),
            ),
      ],
    );
  }

  @override
  Future<void> deletePerson(String id) async {
    await _act(() => _api.delete('/community/${_id(id)}'));
  }

  @override
  Future<List<MeetingPoint>> loadMeetingPoints() => _alerts.loadMeetingPoints();

  @override
  Future<String> createMeetingPoint(MeetingPointDraft point) async {
    final Map<String, dynamic> raw = await _act(
      () => _api.post('/meeting-points', body: point.toJson().cast<String, dynamic>()),
    );
    return _secret(raw['code']);
  }

  @override
  Future<void> updateMeetingPoint(String code, MeetingPointDraft point) async {
    await _act(
      () => _api.patch('/meeting-points/${_id(code)}', body: point.toJson().cast<String, dynamic>()),
    );
  }

  @override
  Future<void> deleteMeetingPoint(String code) async {
    await _act(() => _api.delete('/meeting-points/${_id(code)}'));
  }

  @override
  Future<void> saveProtocol(Protocol protocol) async {
    await _act(
      () => _api.put(
        '/protocols/${_id(protocol.hazard.wire)}',
        body: <String, dynamic>{
          'beforeSteps': protocol.beforeSteps,
          'duringSteps': protocol.duringSteps,
          'afterSteps': protocol.afterSteps,
        },
      ),
    );
  }

  /// Hace una operación que cambia algo y traduce su error al mensaje que ve
  /// coordinación.
  ///
  /// A diferencia de las lecturas, que ante un fallo devuelven una lista vacía y
  /// dejan el motivo en el registro, un cambio que no se guardó **tiene** que
  /// decirse: coordinación cree haber cambiado a un docente de grupo y no es así.
  Future<Map<String, dynamic>> _act(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw PanelActionFailure(error.message);
    }
  }

  /// El identificador va dentro de la ruta: se codifica por si alguien lo
  /// manipulara, aunque los del servidor son UUID.
  static String _id(String id) => Uri.encodeComponent(id);

  /// Una credencial recién emitida. Si el servidor no la mandó, se avisa: mostrar
  /// un diálogo vacío haría creer que se emitió una.
  static String _secret(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const PanelActionFailure(
      'El colegio no devolvió la credencial. Intenta otra vez.',
    );
  }

  static PersonRef? _ref(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return PersonRef(
      id: raw['id'] as String? ?? '',
      fullName: raw['fullName'] as String? ?? '',
    );
  }

  static ReplacedDirector? _replaced(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final PersonRef? person = _ref(raw);
    final String? group = raw['group'] as String?;
    return person == null || group == null
        ? null
        : ReplacedDirector(person: person, group: group);
  }

  static PersonDetail _detail(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const PanelActionFailure('El colegio respondió algo que no entendemos.');
    }
    return PersonDetail(
      id: raw['id'] as String? ?? '',
      fullName: raw['fullName'] as String? ?? '',
      role: raw['role'] as String? ?? '',
      access: raw['access'] as String? ?? 'sin_generar',
      email: raw['email'] as String?,
      grade: raw['grade'] as String?,
      shift: raw['shift'] as String?,
      classroom: raw['classroom'] as String?,
      subject: raw['subject'] as String?,
      homeroomGroup: raw['homeroomGroup'] as String?,
      groups: <String>[
        for (final Object? group in raw['groups'] as List<Object?>? ?? const <Object?>[])
          if (group is String) group,
      ],
      codeHint: raw['codeHint'] as String?,
      code: raw['code'] as String?,
      phone: raw['phone'] as String?,
      document: raw['document'] as String?,
      meetingPoint: raw['meetingPoint'] as String?,
      children: _linked(raw['children']),
      guardians: _linked(raw['guardians']),
    );
  }

  static List<LinkedPerson> _linked(Object? raw) {
    if (raw is! List<Object?>) {
      return const <LinkedPerson>[];
    }
    return <LinkedPerson>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>)
          LinkedPerson(
            id: item['id'] as String? ?? '',
            fullName: item['fullName'] as String? ?? '',
            relationship: item['relationship'] as String? ?? 'Acudiente',
            grade: item['grade'] as String?,
          ),
    ];
  }

  /// El servidor manda enteros, pero un `num` de JSON puede llegar como decimal
  /// si alguna suma se hizo en coma flotante. No se deja reventar un tablero por
  /// eso.
  static int _int(Object? value) => (value as num?)?.round() ?? 0;

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) map) {
    if (raw is! List<Object?>) {
      ErrorReporter.trace('el panel esperaba una lista y llegó otra cosa');
      return <T>[];
    }
    return <T>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) map(item),
    ];
  }
}
