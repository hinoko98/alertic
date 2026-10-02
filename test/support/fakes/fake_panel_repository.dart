import 'fake_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/meeting_point.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:alertic/features/panel/domain/community_admin.dart';
import 'package:alertic/features/panel/domain/group_name.dart';
import 'package:alertic/features/panel/domain/panel_repository.dart';

/// Datos de prueba del panel, con las cifras del diseño.
///
/// Sirve para mostrar el tablero sin backend ni una emergencia real.
class FakePanelRepository implements PanelRepository {
  FakePanelRepository(
    this._alerts, {
    this.latency = const Duration(milliseconds: 300),
    bool empty = false,
  }) : _people = empty ? <_FakePerson>[] : _sample();

  final FakeAlertRepository _alerts;
  final Duration latency;

  final Set<String> _dismissed = <String>{};

  @override
  Future<EmergencyBoard> loadBoard(String alertId) async {
    await Future<void>.delayed(latency);

    const List<({String grade, int safe, int help, int total})> grades =
        <({String grade, int safe, int help, int total})>[
      (grade: '6°', safe: 150, help: 1, total: 168),
      (grade: '7°', safe: 142, help: 0, total: 160),
      (grade: '8°', safe: 139, help: 1, total: 155),
      (grade: '9°', safe: 131, help: 0, total: 150),
      (grade: '10°', safe: 129, help: 1, total: 142),
      (grade: '11°', safe: 121, help: 1, total: 137),
      (grade: 'Docentes', safe: 46, help: 0, total: 48),
    ];

    int safe = 0;
    int help = 0;
    int total = 0;
    final List<GradeProgress> byGrade = <GradeProgress>[];

    for (final ({String grade, int safe, int help, int total}) row in grades) {
      safe += row.safe;
      help += row.help;
      total += row.total;
      byGrade.add(
        GradeProgress(
          grade: row.grade,
          safe: row.safe,
          needHelp: row.help,
          noResponse: row.total - row.safe - row.help,
          total: row.total,
        ),
      );
    }

    final DateTime now = DateTime.now();

    return EmergencyBoard(
      safe: safe,
      needHelp: help,
      noResponse: total - safe - help,
      total: total,
      byGrade: byGrade,
      needHelpList: <HelpRequest>[
        HelpRequest(
          personId: '1',
          fullName: 'Juan Diego Rincón',
          grade: '10° B',
          location: 'Aula 7, Bloque A',
          reportedAt: now.subtract(const Duration(minutes: 12)),
        ),
        HelpRequest(
          personId: '2',
          fullName: 'Camila Torres Peña',
          grade: '7° A',
          location: 'Baño 2.º piso, Bloque B',
          reportedAt: now.subtract(const Duration(minutes: 10)),
        ),
        HelpRequest(
          personId: '3',
          fullName: 'Luis Otero Ramírez',
          grade: 'Docentes',
          location: 'Laboratorio · reporta estudiante herido',
          reportedAt: now.subtract(const Duration(minutes: 9)),
        ),
        HelpRequest(
          personId: '4',
          fullName: 'Esteban Ruiz Gómez',
          grade: '11° A',
          location: 'Sin ubicación (sin GPS)',
          reportedAt: now.subtract(const Duration(minutes: 7)),
        ),
      ],
      byMeetingPoint: const <MeetingPointCount>[
        MeetingPointCount(code: 'P1', count: 986),
        MeetingPointCount(code: 'P2', count: 120),
      ],
    );
  }

  @override
  Future<List<CommunityMember>> loadCommunity({
    String? role,
    String query = '',
  }) async {
    await Future<void>.delayed(latency);

    final String needle = query.trim().toLowerCase();

    return <CommunityMember>[
      for (final _FakePerson person in _people)
        if ((role == null || person.role == role) &&
            (needle.isEmpty || person.fullName.toLowerCase().contains(needle)))
          _memberOf(person),
    ];
  }

  @override
  Future<CommunityStats> loadStats() async {
    await Future<void>.delayed(latency);
    return const CommunityStats(
      total: 1248,
      byRole: <String, int>{
        'estudiante': 912,
        'acudiente': 284,
        'docente': 48,
      },
      activeCodes: 1031,
      pendingCodes: 217,
    );
  }

  @override
  Future<List<HazardSignal>> loadSignals() async {
    await Future<void>.delayed(latency);

    return <HazardSignal>[
      HazardSignal(
        id: 'demo-usgs',
        source: 'USGS',
        hazard: Hazard.sismo,
        headline: 'Sismo M4.2 a 86 km',
        detail: '18 km al noreste de Los Santos, Santander',
        magnitude: 4.2,
        distanceKm: 86,
        occurredAt: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      HazardSignal(
        id: 'demo-meteo',
        source: 'Open-Meteo',
        hazard: Hazard.lluvia,
        headline: 'Lluvia fuerte: 34 mm en las próximas 6 horas',
        detail: 'Pico de 12 mm/h. Revisar el nivel de la quebrada.',
        occurredAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
    ].where((HazardSignal signal) => !_dismissed.contains(signal.id)).toList();
  }

  @override
  Future<void> dismissSignal(String signalId) async {
    await Future<void>.delayed(latency);
    _dismissed.add(signalId);
  }

  @override
  Future<List<Alert>> loadHistory() => _alerts.loadHistory();

  @override
  Future<List<Protocol>> loadProtocols() => _alerts.loadProtocols();

  // --- Administración de la comunidad ---------------------------------------
  //
  // Las mismas reglas que el servidor, en memoria, para que el modo demo no
  // enseñe algo que luego no pasa de verdad: un grupo con un solo director, un
  // correo que no se repite, un docente con acceso y al menos un grupo.

  final List<_FakePerson> _people;

  static List<_FakePerson> _sample() => <_FakePerson>[
    _FakePerson(
      id: '1',
      fullName: 'Laura Camila Pérez Gómez',
      role: 'estudiante',
      grade: '10° B',
      shift: 'Mañana',
      classroom: 'Aula 7 · Bloque A',
      codeHint: 'IICB-7K',
      access: 'usado',
      linkedTo: 'Martha Gómez, Jorge Pérez',
    ),
    _FakePerson(
      id: '2',
      fullName: 'Martha Gómez Ardila',
      role: 'acudiente',
      codeHint: 'IICB-3H',
      access: 'usado',
      linkedTo: 'Laura (10° B), Andrés (6° A)',
      phone: '3105554521',
      children: const <LinkedPerson>[
        LinkedPerson(id: '1', fullName: 'Laura Camila Pérez Gómez', relationship: 'Madre', grade: '10° B'),
        LinkedPerson(id: '3', fullName: 'Andrés Felipe Pérez Gómez', relationship: 'Madre', grade: '6° A'),
      ],
    ),
    _FakePerson(
      id: '3',
      fullName: 'Andrés Felipe Pérez Gómez',
      role: 'estudiante',
      grade: '6° A',
      shift: 'Mañana',
      classroom: 'Aula 2 · Bloque A',
      codeHint: 'IICB-9R',
      access: 'pendiente',
      linkedTo: 'Martha Gómez, Jorge Pérez',
    ),
    _FakePerson(
      id: '4',
      fullName: 'Jorge Pérez Rueda',
      role: 'acudiente',
      codeHint: 'IICB-5B',
      access: 'entregado',
      linkedTo: 'Laura (10° B), Andrés (6° A)',
      children: const <LinkedPerson>[
        LinkedPerson(id: '1', fullName: 'Laura Camila Pérez Gómez', relationship: 'Padre', grade: '10° B'),
        LinkedPerson(id: '3', fullName: 'Andrés Felipe Pérez Gómez', relationship: 'Padre', grade: '6° A'),
      ],
    ),
    _FakePerson(
      id: '5',
      fullName: 'Carlos Jaimes Duarte',
      role: 'docente',
      email: 'carlos.jaimes@iic.edu.co',
      subject: 'Contabilidad',
      homeroomGroup: '10° B',
      groups: <String>['10° A', '10° B', '11° A'],
      access: 'con_cuenta',
      hasHistory: true,
    ),
    _FakePerson(
      id: '6',
      fullName: 'Sofía Arenas Villamizar',
      role: 'estudiante',
      grade: '10° B',
      shift: 'Mañana',
      classroom: 'Aula 7 · Bloque A',
      codeHint: 'IICB-8J',
      access: 'usado',
      linkedTo: 'Luz Villamizar',
    ),
    _FakePerson(
      id: '7',
      fullName: 'Nubia Silva Castro',
      role: 'docente',
      email: 'nubia.silva@iic.edu.co',
      subject: 'Matemáticas',
      homeroomGroup: '6° A',
      groups: <String>['6° A', '7° B'],
      access: 'con_cuenta',
    ),
  ];

  int _nextId = 100;
  int _codeSeed = 1;

  _FakePerson _find(String id) {
    for (final _FakePerson person in _people) {
      if (person.id == id) return person;
    }
    throw const PanelActionFailure('No encontramos a esa persona.');
  }

  @override
  Future<List<GroupInfo>> loadGroups() async {
    await Future<void>.delayed(latency);

    final Set<String> names = <String>{
      for (final _FakePerson person in _people) ...<String>[
        if (person.role == 'estudiante' && person.grade != null) person.grade!,
        ...person.groups,
        if (person.homeroomGroup != null) person.homeroomGroup!,
      ],
    };
    final List<String> sorted = names.toList()..sort(GroupName.compare);

    return <GroupInfo>[
      for (final String grade in sorted)
        GroupInfo(
          grade: grade,
          enrolled: _people
              .where((_FakePerson p) => p.role == 'estudiante' && p.grade == grade)
              .length,
          classroom: _classroomOf(grade),
          director: _directorOf(grade)?.toRef(),
        ),
    ];
  }

  String? _classroomOf(String grade) {
    for (final _FakePerson person in _people) {
      if (person.role == 'estudiante' &&
          person.grade == grade &&
          person.classroom != null) {
        return person.classroom;
      }
    }
    return null;
  }

  _FakePerson? _directorOf(String grade) {
    for (final _FakePerson person in _people) {
      if (person.role == 'docente' && person.homeroomGroup == grade) return person;
    }
    return null;
  }

  @override
  Future<PersonDetail> loadPerson(String id) async {
    await Future<void>.delayed(latency);
    return _detailOf(_find(id));
  }

  @override
  Future<PersonUpdate> updatePerson(String id, PersonChanges changes) async {
    await Future<void>.delayed(latency);

    final _FakePerson person = _find(id);
    if (person.role == 'administrador') {
      throw const PanelActionFailure(
        'Las cuentas de coordinación no se administran desde aquí.',
      );
    }

    final String? email = changes.email?.trim().toLowerCase();
    if (email != null &&
        _people.any((_FakePerson p) => p.id != id && p.email == email)) {
      throw const PanelActionFailure('Ese correo ya lo usa otra cuenta.');
    }

    ReplacedDirector? replaced;
    final String? newHomeroom = changes.homeroomGroup;
    if (newHomeroom != null) {
      final _FakePerson? previous = _directorOf(newHomeroom);
      if (previous != null && previous.id != id) {
        previous.homeroomGroup = null;
        replaced = ReplacedDirector(person: previous.toRef(), group: newHomeroom);
      }
    }

    final String? homeroom = changes.removeHomeroom
        ? null
        : (newHomeroom ?? person.homeroomGroup);
    final List<String> groups = <String>{
      ...(changes.groups ?? person.groups),
      ?homeroom,
    }.toList()
      ..sort(GroupName.compare);

    if (person.role == 'docente' &&
        person.access == 'con_cuenta' &&
        homeroom == null &&
        groups.isEmpty) {
      throw const PanelActionFailure(
        'Un docente necesita al menos un grupo. Para quitarle el acceso usa '
        '«Dar de baja».',
      );
    }

    if (changes.fullName != null) person.fullName = changes.fullName!.trim();
    if (email != null) person.email = email;
    if (changes.subject != null) person.subject = changes.subject;
    if (changes.shift != null) person.shift = changes.shift;
    if (changes.classroom != null) person.classroom = changes.classroom;
    if (changes.grade != null && changes.grade != person.grade) {
      person.grade = changes.grade;
      // El salón del grupo al que llega, o ninguno: nunca el del grupo anterior.
      person.classroom = changes.classroom ?? _classroomOf(changes.grade!);
    }
    if (person.role == 'docente') {
      person
        ..homeroomGroup = homeroom
        ..groups = groups;
    }

    if (person.role == 'estudiante') {
      if (changes.document != null) _checkDocument(changes.document!, id);
      if (changes.meetingPoint != null) person.meetingPoint = changes.meetingPoint;
    }
    if (changes.document != null && person.role != 'estudiante') {
      _checkDocument(changes.document!, id);
    }
    if (changes.document != null) person.document = changes.document;
    if (changes.phone != null) person.phone = changes.phone;
    final List<ChildLink>? links = changes.children;
    if (links != null && person.role == 'acudiente') {
      person.children = _linksFor(links);
    }

    return PersonUpdate(person: _detailOf(person), replacedDirector: replaced);
  }

  @override
  Future<CreatedTeacher> createTeacher(NewTeacher teacher) async {
    await Future<void>.delayed(latency);

    final String email = teacher.email.trim().toLowerCase();
    if (_people.any((_FakePerson p) => p.email == email)) {
      throw const PanelActionFailure('Ese correo ya lo usa otra cuenta.');
    }
    if (teacher.homeroomGroup == null && teacher.groups.isEmpty) {
      throw const PanelActionFailure('Elige al menos un grupo para el docente.');
    }

    ReplacedDirector? replaced;
    final String? homeroom = teacher.homeroomGroup;
    if (homeroom != null) {
      final _FakePerson? previous = _directorOf(homeroom);
      if (previous != null) {
        previous.homeroomGroup = null;
        replaced = ReplacedDirector(person: previous.toRef(), group: homeroom);
      }
    }

    final _FakePerson created = _FakePerson(
      id: '${_nextId++}',
      fullName: teacher.fullName.trim(),
      role: 'docente',
      email: email,
      subject: teacher.subject.trim(),
      homeroomGroup: homeroom,
      groups: <String>{...teacher.groups, ?homeroom}.toList()..sort(GroupName.compare),
      access: 'con_cuenta',
    );
    _people.add(created);

    return CreatedTeacher(
      person: created.toDetail(),
      temporaryPassword: 'DEMO-AB23-XY45',
      replacedDirector: replaced,
    );
  }

  @override
  Future<String> resetTeacherPassword(String id) async {
    await Future<void>.delayed(latency);

    final _FakePerson person = _find(id);
    if (person.role != 'docente') {
      throw const PanelActionFailure('Solo los docentes entran con contraseña.');
    }
    if (person.groups.isEmpty && person.homeroomGroup == null) {
      throw const PanelActionFailure(
        'Asígnale al menos un grupo antes de darle acceso.',
      );
    }
    person.access = 'con_cuenta';
    return 'DEMO-RS37-KM92';
  }

  @override
  Future<PersonDetail> deactivateTeacher(String id) async {
    await Future<void>.delayed(latency);

    final _FakePerson person = _find(id);
    if (person.role != 'docente') {
      throw const PanelActionFailure(
        'Solo se da de baja a docentes. A un estudiante o acudiente se le '
        'revoca el código.',
      );
    }
    person
      ..access = 'sin_acceso'
      ..homeroomGroup = null
      ..groups = <String>[];
    return person.toDetail();
  }

  @override
  Future<String> renewCode(String id) async {
    await Future<void>.delayed(latency);

    final _FakePerson person = _find(id);
    if (person.role != 'estudiante' && person.role != 'acudiente') {
      throw const PanelActionFailure(
        'Los docentes entran con contraseña, no con código.',
      );
    }
    person
      ..access = 'pendiente'
      ..codeHint = 'IIC-${(1000 + _codeSeed++).toString().padLeft(4, '0')}';
    return '${person.codeHint}-DEMO';
  }

  @override
  Future<void> closeSessions(String id) async {
    await Future<void>.delayed(latency);
    _find(id);
  }

  void _checkDocument(String document, String exceptId) {
    if (_people.any((_FakePerson p) => p.id != exceptId && p.document == document)) {
      throw const PanelActionFailure('Ese documento ya está registrado en otra persona.');
    }
  }

  List<LinkedPerson> _linksFor(List<ChildLink> links) {
    return <LinkedPerson>[
      for (final ChildLink link in links)
        if (_people.any((_FakePerson p) => p.id == link.studentId && p.role == 'estudiante'))
          LinkedPerson(
            id: link.studentId,
            fullName: _find(link.studentId).fullName,
            relationship: link.relationship,
            grade: _find(link.studentId).grade,
          )
        else
          throw const PanelActionFailure('Uno de los estudiantes vinculados no existe.'),
    ];
  }

  /// Los acudientes de un estudiante, vistos desde los vínculos de cada acudiente.
  List<LinkedPerson> _guardiansOf(String studentId) {
    return <LinkedPerson>[
      for (final _FakePerson g in _people)
        for (final LinkedPerson child in g.children)
          if (child.id == studentId)
            LinkedPerson(id: g.id, fullName: g.fullName, relationship: child.relationship),
    ];
  }

  PersonDetail _detailOf(_FakePerson person) => person.toDetail(
        guardians: person.role == 'estudiante' ? _guardiansOf(person.id) : const <LinkedPerson>[],
      );

  CommunityMember _memberOf(_FakePerson person) {
    final CommunityMember base = person.toMember();
    final String? linked = switch (person.role) {
      'estudiante' => _guardiansOf(person.id).map((LinkedPerson g) => g.fullName).join(', '),
      'acudiente' => person.children.map((LinkedPerson c) => c.fullName).join(', '),
      _ => base.linkedTo,
    };
    return CommunityMember(
      id: base.id,
      fullName: base.fullName,
      role: base.role,
      grade: base.grade,
      codeHint: base.codeHint,
      codeStatus: base.codeStatus,
      linkedTo: (linked == null || linked.isEmpty) ? base.linkedTo : linked,
    );
  }

  @override
  Future<CreatedPerson> createStudent(NewStudent student) async {
    await Future<void>.delayed(latency);

    if (student.document != null) _checkDocument(student.document!, '');
    final _FakePerson created = _FakePerson(
      id: '${_nextId++}',
      fullName: student.fullName.trim(),
      role: 'estudiante',
      grade: student.grade,
      shift: student.shift,
      classroom: student.classroom ?? _classroomOf(student.grade),
      document: student.document,
      meetingPoint: student.meetingPoint ?? 'P1',
      codeHint: 'IIC-NEW${_codeSeed++}',
      access: 'pendiente',
    );
    _people.add(created);
    return CreatedPerson(person: _detailOf(created), code: '${created.codeHint}-DEMO');
  }

  @override
  Future<CodeBatch> importStudents(List<NewStudent> students) async {
    await Future<void>.delayed(latency);

    final List<IssuedCode> codes = <IssuedCode>[];
    for (final NewStudent student in students) {
      final CreatedPerson created = await createStudent(student);
      codes.add(
        IssuedCode(
          personId: created.person.id,
          fullName: created.person.fullName,
          role: 'estudiante',
          grade: student.grade,
          code: created.code,
        ),
      );
    }
    return CodeBatch(codes: codes);
  }

  @override
  Future<CodeBatch> generateCodes({
    required List<String> grades,
    bool includeGuardians = false,
    bool reissue = false,
  }) async {
    await Future<void>.delayed(latency);

    final List<IssuedCode> codes = <IssuedCode>[];
    int registered = 0;
    for (final _FakePerson person in _people) {
      final bool inGroup = person.role == 'estudiante' && grades.contains(person.grade);
      if (!inGroup) continue;
      if (person.access == 'usado') {
        registered++;
        continue;
      }
      if (person.codeHint != null && !reissue) continue;
      person
        ..access = 'pendiente'
        ..codeHint = 'IICB-${(10 + _codeSeed++).toString().padLeft(2, '0')}';
      codes.add(
        IssuedCode(
          personId: person.id,
          fullName: person.fullName,
          role: person.role,
          grade: person.grade,
          code: '${person.codeHint}XX',
        ),
      );
    }
    return CodeBatch(codes: codes, alreadyRegistered: registered);
  }

  @override
  Future<CreatedPerson> createGuardian(NewGuardian guardian) async {
    await Future<void>.delayed(latency);

    if (guardian.document != null) _checkDocument(guardian.document!, '');
    final _FakePerson created = _FakePerson(
      id: '${_nextId++}',
      fullName: guardian.fullName.trim(),
      role: 'acudiente',
      phone: guardian.phone,
      document: guardian.document,
      children: _linksFor(guardian.children),
      codeHint: 'IIC-NEW${_codeSeed++}',
      access: 'pendiente',
    );
    _people.add(created);
    return CreatedPerson(person: _detailOf(created), code: '${created.codeHint}-DEMO');
  }

  @override
  Future<void> deletePerson(String id) async {
    await Future<void>.delayed(latency);

    final _FakePerson person = _find(id);
    if (person.role == 'administrador') {
      throw const PanelActionFailure('Las cuentas de coordinación no se administran desde aquí.');
    }
    if (person.hasHistory) {
      throw const PanelActionFailure(
        'Tiene historial de alertas o reportes y debe conservarse. Dale de baja '
        'en vez de eliminarlo.',
      );
    }
    _people.remove(person);
    // Sus vínculos se van con él.
    for (final _FakePerson other in _people) {
      other.children = other.children.where((LinkedPerson c) => c.id != id).toList();
    }
  }

  final List<MeetingPoint> _points = <MeetingPoint>[
    const MeetingPoint(
      code: 'P1',
      name: 'Punto de encuentro principal',
      routeHint: 'Sigue las indicaciones de tu docente.',
      distanceMeters: 0,
      walkMinutes: 0,
    ),
  ];
  int _pointSeed = 2;

  @override
  Future<List<MeetingPoint>> loadMeetingPoints() async {
    await Future<void>.delayed(latency);
    return List<MeetingPoint>.of(_points);
  }

  MeetingPoint _pointFrom(String code, MeetingPointDraft d) => MeetingPoint(
        code: code,
        name: d.name,
        routeHint: d.routeHint,
        distanceMeters: d.distanceMeters,
        walkMinutes: d.walkMinutes,
        onlyFor: d.onlyFor,
      );

  @override
  Future<String> createMeetingPoint(MeetingPointDraft point) async {
    await Future<void>.delayed(latency);
    final String code = 'P${_pointSeed++}';
    _points.add(_pointFrom(code, point));
    return code;
  }

  @override
  Future<void> updateMeetingPoint(String code, MeetingPointDraft point) async {
    await Future<void>.delayed(latency);
    final int index = _points.indexWhere((MeetingPoint p) => p.code == code);
    if (index < 0) throw const PanelActionFailure('No encontramos ese punto de encuentro.');
    _points[index] = _pointFrom(code, point);
  }

  @override
  Future<void> deleteMeetingPoint(String code) async {
    await Future<void>.delayed(latency);
    if (_people.any((_FakePerson p) => p.meetingPoint == code)) {
      throw const PanelActionFailure(
        'Hay estudiantes asignados a ese punto. Cámbialos de punto primero.',
      );
    }
    if (_points.where((MeetingPoint p) => p.onlyFor == null && p.code != code).isEmpty) {
      throw const PanelActionFailure(
        'Tiene que quedar al menos un punto de encuentro general: una alerta '
        'roja necesita decir a dónde ir.',
      );
    }
    _points.removeWhere((MeetingPoint p) => p.code == code);
  }

  @override
  Future<void> saveProtocol(Protocol protocol) async {
    await Future<void>.delayed(latency);
    _alerts.replaceProtocol(protocol);
  }
}

/// Una persona de la comunidad en el modo demo. Es mutable a propósito: es lo que
/// permite que editar en el panel de prueba se vea reflejado en el listado.
class _FakePerson {
  _FakePerson({
    required this.id,
    required this.fullName,
    required this.role,
    required this.access,
    this.email,
    this.grade,
    this.shift,
    this.classroom,
    this.subject,
    this.homeroomGroup,
    this.groups = const <String>[],
    this.codeHint,
    this.linkedTo,
    this.phone,
    this.document,
    this.meetingPoint,
    this.children = const <LinkedPerson>[],
    this.hasHistory = false,
  });

  final String id;
  String fullName;
  final String role;
  String access;
  String? email;
  String? grade;
  String? shift;
  String? classroom;
  String? subject;
  String? homeroomGroup;
  List<String> groups;
  String? codeHint;
  final String? linkedTo;
  String? phone;
  String? document;
  String? meetingPoint;

  /// Estudiantes a cargo, si es acudiente.
  List<LinkedPerson> children;

  /// Si emitió o atendió alertas: entonces el servidor no deja eliminarlo.
  final bool hasHistory;

  PersonRef toRef() => PersonRef(id: id, fullName: fullName);

  CommunityMember toMember() => CommunityMember(
        id: id,
        fullName: fullName,
        role: role,
        grade: role == 'docente'
            ? (homeroomGroup == null ? null : 'Dir. $homeroomGroup')
            : grade,
        codeHint: codeHint,
        codeStatus: access,
        linkedTo: role == 'docente'
            ? <String>[?subject, if (groups.isNotEmpty) groups.join(', ')].join(' · ')
            : linkedTo,
      );

  PersonDetail toDetail({List<LinkedPerson> guardians = const <LinkedPerson>[]}) => PersonDetail(
        id: id,
        fullName: fullName,
        role: role,
        access: access,
        email: email,
        grade: grade,
        shift: shift,
        classroom: classroom,
        subject: subject,
        homeroomGroup: homeroomGroup,
        groups: List<String>.of(groups),
        codeHint: codeHint,
        phone: phone,
        document: document,
        meetingPoint: meetingPoint,
        children: List<LinkedPerson>.of(children),
        guardians: guardians,
      );
}
