@Tags(<String>['integracion'])
library;

import 'dart:io';

import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/features/alerts/data/api_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/meeting_point.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:alertic/features/guardian/data/api_guardian_repository.dart';
import 'package:alertic/features/guardian/domain/guardian_repository.dart';
import 'package:alertic/features/incidents/data/api_incident_repository.dart';
import 'package:alertic/features/incidents/domain/incident.dart';
import 'package:alertic/features/onboarding/data/api_credentials_repository.dart';
import 'package:alertic/features/panel/data/api_panel_repository.dart';
import 'package:alertic/features/panel/domain/community_admin.dart';
import 'package:alertic/features/panel/domain/panel_repository.dart';
import 'package:alertic/features/teacher/data/api_teacher_repository.dart';
import 'package:alertic/features/onboarding/data/api_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:alertic/core/session/user_role.dart';
import 'package:alertic/features/session/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prueba que el front y la API se entienden de verdad.
///
/// Necesita el servidor corriendo con la matrícula de prueba:
///
/// ```bash
/// cd ../alerticapi && DATABASE_FILE=./data/demo.db npm run seed:demo && DATABASE_FILE=./data/demo.db npm start
/// flutter test test/integration/api_test.dart
/// ```
///
/// Si el servidor no está, las pruebas se saltan en vez de fallar: no tiene
/// sentido romper la construcción de la app porque alguien no levantó el
/// backend en su equipo.
void main() {
  const String baseUrl = String.fromEnvironment(
    'ALERTIC_API',
    defaultValue: 'http://localhost:3000',
  );

  late ApiClient api;
  bool serverUp = false;

  setUpAll(() async {
    // `flutter test` intercepta las peticiones de red. Aquí se quita ese
    // interceptor porque justo lo que se quiere probar es la red real.
    HttpOverrides.global = null;

    api = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 3));
    try {
      await api.get('/health');
      serverUp = true;
    } on ApiException {
      serverUp = false;
    }
  });

  tearDownAll(() => api.close());

  test('el registro de un estudiante llega completo desde la API', () async {
    if (!serverUp) {
      markTestSkipped('La API no está corriendo en $baseUrl');
      return;
    }

    final ApiEnrollmentRepository repository = ApiEnrollmentRepository(api);
    final Enrollment profile = await repository.findByCode(
      PersonalCode.tryParse('IICB-7K4P')!,
    );

    expect(profile, isA<StudentEnrollment>());
    expect(profile.fullName, 'Laura Camila Pérez Gómez');

    final StudentEnrollment student = profile as StudentEnrollment;
    expect(student.grade, '10° B');
    expect(student.meetingPoint.code, 'P1');
    expect(student.meetingPoint.name, 'Cancha central');
    expect(student.guardians, hasLength(2));
  });

  test('un código que no está en la matrícula se traduce a CodeNotFound', () async {
    if (!serverUp) {
      markTestSkipped('La API no está corriendo en $baseUrl');
      return;
    }

    final ApiEnrollmentRepository repository = ApiEnrollmentRepository(api);

    await expectLater(
      repository.findByCode(PersonalCode.tryParse('ZZZZ9999')!),
      throwsA(isA<CodeNotFound>()),
    );
  });

  test('confirmar identidad abre sesión y el rol lo pone el servidor', () async {
    if (!serverUp) {
      markTestSkipped('La API no está corriendo en $baseUrl');
      return;
    }

    final ApiEnrollmentRepository repository = ApiEnrollmentRepository(api);

    // Los códigos son de un solo uso de verdad, así que esta prueba solo corre
    // sobre una matrícula recién sembrada (`npm run seed`). Que falle por
    // «código ya usado» significa que el servidor está haciendo su trabajo.
    late final Session session;
    try {
      session = await repository.confirmIdentity(
        PersonalCode.tryParse('IICB-8JK3')!,
      );
    } on CodeAlreadyUsed {
      markTestSkipped(
        'El código ya se usó. Vuelve a sembrar la matrícula: npm run seed',
      );
      return;
    }

    expect(session.token, isNotEmpty);
    expect(session.role.wire, 'estudiante');
    expect(session.isExpired(), isFalse);
    // El token nunca sale en el texto del objeto.
    expect(session.toString(), isNot(contains(session.token)));
  });

  test('los protocolos y el historial llegan listos para la app', () async {
    if (!serverUp) {
      markTestSkipped('La API no está corriendo en $baseUrl');
      return;
    }

    // Se necesita sesión: estas rutas no son públicas.
    try {
      await ApiEnrollmentRepository(api)
          .confirmIdentity(PersonalCode.tryParse('IICB-3HW8')!);
    } on CodeAlreadyUsed {
      markTestSkipped(
        'El código ya se usó. Vuelve a sembrar la matrícula: npm run seed',
      );
      return;
    }

    final ApiAlertRepository alerts = ApiAlertRepository(api);

    final List<Protocol> protocols = await alerts.loadProtocols();
    expect(protocols, isNotEmpty);
    expect(
      protocols.map((Protocol p) => p.hazard.wire),
      contains('sismo'),
    );

    final List<Alert> history = await alerts.loadHistory();
    expect(history, isA<List<Alert>>());
  });

  group('«ya tengo cuenta»: docentes y administradores', () {
    Credentials credentials(String email, String password) {
      final (Credentials? built, String? problem) = Credentials.tryBuild(
        email: email,
        password: password,
      );
      if (built == null) {
        throw StateError('credenciales de prueba inválidas: $problem');
      }
      return built;
    }

    test('un docente entra con correo y el servidor le pone el rol', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final Session session = await ApiCredentialsRepository(api).signIn(
        credentials('carlos.jaimes@iic.edu.co', 'Contabilidad2026'),
      );

      expect(session.role, UserRole.docente);
      expect(session.profile, isA<TeacherEnrollment>());
      expect((session.profile as TeacherEnrollment).groups, isNotEmpty);
      // A diferencia del código, esta sesión se puede abrir cuantas veces haga
      // falta: no hay nada que quemar.
      expect(session.token, isNotEmpty);
    });

    test('un administrador entra y su perfil dice hasta dónde llega', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final Session session = await ApiCredentialsRepository(api).signIn(
        credentials('coordinacion@iic.edu.co', 'Barbosa2026Riesgo'),
      );

      expect(session.role, UserRole.administrador);
      expect(session.profile, isA<AdminEnrollment>());
      expect((session.profile as AdminEnrollment).scope, isNotEmpty);
    });

    test('una contraseña mala no dice si la cuenta existe', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      // El mismo error para una cuenta real con clave mala y para una que no
      // existe: si se distinguieran, se podría averiguar qué correos del
      // colegio son reales probando.
      await expectLater(
        ApiCredentialsRepository(api).signIn(
          credentials('carlos.jaimes@iic.edu.co', 'equivocada123'),
        ),
        throwsA(isA<InvalidCredentials>()),
      );
      await expectLater(
        ApiCredentialsRepository(api).signIn(
          credentials('fantasma@iic.edu.co', 'equivocada123'),
        ),
        throwsA(isA<InvalidCredentials>()),
      );
    });
  });

  group('docente, acudiente y panel contra el servidor', () {
    /// Un cliente propio por prueba: el token vive en el cliente, y compartirlo
    /// haría que una prueba entrara con la sesión de otra.
    Future<ApiClient> signedInAs(String email, String password) async {
      final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 5));
      final (Credentials? built, String? problem) = Credentials.tryBuild(
        email: email,
        password: password,
      );
      if (built == null) throw StateError('credenciales de prueba inválidas: $problem');
      await ApiCredentialsRepository(client).signIn(built);
      return client;
    }

    test('el docente trae las cifras REALES de su grupo, no 34 y 32', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final Session session = await ApiCredentialsRepository(api).signIn(
        Credentials.tryBuild(
          email: 'carlos.jaimes@iic.edu.co',
          password: 'Contabilidad2026',
        ).$1!,
      );

      final TeacherEnrollment teacher = session.profile as TeacherEnrollment;
      final GroupSummary? group = teacher.summaryFor('10° B');
      expect(group, isNotNull);
      expect(group!.enrolled, greaterThan(0));
      expect(group.classroom, contains('Aula'));
    });

    test('el alcance de una alerta es el total de la matrícula', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await signedInAs('carlos.jaimes@iic.edu.co', 'Contabilidad2026');
      final int? reach = await ApiTeacherRepository(client).loadReach();

      expect(reach, isNotNull);
      expect(reach, isNot(1248), reason: 'ya no es una cifra escrita en la app');
    });

    test('coordinación ve la comunidad y los reportes reales', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await signedInAs('coordinacion@iic.edu.co', 'Barbosa2026Riesgo');
      final PanelRepository panel = ApiPanelRepository(client, ApiAlertRepository(client));

      final CommunityStats stats = await panel.loadStats();
      expect(stats.total, greaterThan(0));

      final List<CommunityMember> everyone = await panel.loadCommunity();
      expect(everyone, isNotEmpty);
      // Docentes y coordinación no tienen código: el panel lo dice con honestidad.
      final CommunityMember carlos =
          everyone.firstWhere((CommunityMember m) => m.fullName.startsWith('Carlos'));
      expect(carlos.codeHint, isNull);

      final List<Incident> open = await ApiIncidentRepository(client).loadOpen();
      expect(open, isA<List<Incident>>());
    });

    test('un docente NO puede ver la comunidad: el servidor dice 403', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await signedInAs('carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      await expectLater(
        ApiPanelRepository(client, ApiAlertRepository(client)).loadStats(),
        throwsA(isA<ApiException>().having((ApiException e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('el acudiente ve a sus hijos en calma, sin que haya alerta', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 5));
      try {
        await ApiEnrollmentRepository(client)
            .confirmIdentity(PersonalCode.tryParse('IICB-5BN6')!);
      } on CodeAlreadyUsed {
        markTestSkipped('El código ya se usó. Vuelve a sembrar la matrícula: npm run seed');
        return;
      }

      final GuardianRepository guardian = ApiGuardianRepository(client);
      final List<ChildStatus> children = await guardian.loadChildren(null);

      expect(children, hasLength(2));
      expect(children.every((ChildStatus c) => c.isPending && c.note == null), isTrue,
          reason: 'en calma nadie «espera confirmación»');
      expect(children.first.meetingPoint, contains('Cancha'));

      // Sin SCHOOL_PHONE configurado el servidor no inventa un teléfono.
      expect(await guardian.loadSchoolPhone(), isNull);
    });
  });

  group('administración de la comunidad contra el servidor', () {
    Future<ApiClient> adminClient() async {
      final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
      await ApiCredentialsRepository(client).signIn(
        Credentials.tryBuild(
          email: 'coordinacion@iic.edu.co',
          password: 'Barbosa2026Riesgo',
        ).$1!,
      );
      return client;
    }

    test('los grupos vienen del servidor, en orden, con su director', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await adminClient();
      final PanelRepository panel = ApiPanelRepository(client, ApiAlertRepository(client));

      final List<GroupInfo> groups = await panel.loadGroups();
      final List<String> names = groups.map((GroupInfo g) => g.grade).toList();

      expect(names.indexOf('6° A'), lessThan(names.indexOf('10° A')));
      expect(groups.firstWhere((GroupInfo g) => g.grade == '10° B').director, isNotNull);
    });

    test('cambiar a un estudiante de grupo y devolverlo, con lo que el servidor responde', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await adminClient();
      final PanelRepository panel = ApiPanelRepository(client, ApiAlertRepository(client));

      final CommunityMember sofia = (await panel.loadCommunity(query: 'Sofía')).first;
      final PersonDetail before = await panel.loadPerson(sofia.id);
      final String home = before.grade!;
      final String other = home == '6° A' ? '7° B' : '6° A';

      final PersonUpdate moved = await panel.updatePerson(sofia.id, PersonChanges(grade: other));
      expect(moved.person.grade, other);

      final PersonUpdate back = await panel.updatePerson(
        sofia.id,
        PersonChanges(grade: home, classroom: before.classroom),
      );
      expect(back.person.grade, home);
    });

    test('un cambio inválido llega como el mensaje del servidor, no como un error de red', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await adminClient();
      final PanelRepository panel = ApiPanelRepository(client, ApiAlertRepository(client));
      final CommunityMember sofia = (await panel.loadCommunity(query: 'Sofía')).first;

      await expectLater(
        panel.updatePerson(sofia.id, const PersonChanges(grade: '12° Z')),
        throwsA(isA<PanelActionFailure>()),
      );
    });

    test('un docente nuevo entra con la contraseña temporal y la cambia por una suya', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await adminClient();
      final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));

      final String email = 'integracion.${DateTime.now().millisecondsSinceEpoch}@iic.edu.co';
      final CreatedTeacher created = await panel.createTeacher(
        NewTeacher(
          fullName: 'Prueba Integración Docente',
          email: email,
          subject: 'Pruebas',
          groups: const <String>['7° B'],
        ),
      );
      expect(created.temporaryPassword, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));

      // Entra como ese docente, desde un cliente propio.
      final ApiClient teacherClient = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
      final ApiCredentialsRepository credentials = ApiCredentialsRepository(teacherClient);
      final Session session = await credentials.signIn(
        Credentials.tryBuild(email: email, password: created.temporaryPassword).$1!,
      );
      expect((session.profile as TeacherEnrollment).groups, <String>['7° B']);

      // Su sesión sigue valiendo después de cambiar la contraseña (token nuevo).
      await credentials.changePassword(
        currentPassword: created.temporaryPassword,
        newPassword: 'Una-Contrasena-Mia-2026',
      );
      expect(await teacherClient.get('/auth/me'), contains('profile'));

      // La temporal ya no sirve; la nueva sí.
      await expectLater(
        ApiCredentialsRepository(ApiClient(baseUrl: baseUrl)).signIn(
          Credentials.tryBuild(email: email, password: created.temporaryPassword).$1!,
        ),
        throwsA(isA<InvalidCredentials>()),
      );

      // Coordinación la restablece: la sesión abierta se cierra sola.
      final String reset = await panel.resetTeacherPassword(created.person.id);
      expect(reset, isNot(created.temporaryPassword));
      await expectLater(
        teacherClient.get('/auth/me'),
        throwsA(isA<ApiException>().having((ApiException e) => e.isUnauthorized, 'sin sesión', isTrue)),
      );

      // Y se da de baja: ya no entra.
      await panel.deactivateTeacher(created.person.id);
      await expectLater(
        ApiCredentialsRepository(ApiClient(baseUrl: baseUrl)).signIn(
          Credentials.tryBuild(email: email, password: reset).$1!,
        ),
        throwsA(isA<InvalidCredentials>()),
      );
    });

    test('equivocarse en la contraseña actual no saca al docente de su sesión', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
      var kickedOut = false;
      client.onUnauthorized = () => kickedOut = true;
      final ApiCredentialsRepository credentials = ApiCredentialsRepository(client);
      await credentials.signIn(
        Credentials.tryBuild(email: 'nubia.silva@iic.edu.co', password: 'Matematicas2026').$1!,
      );

      await expectLater(
        credentials.changePassword(
          currentPassword: 'no-es-esta-1234',
          newPassword: 'Otra-Contrasena-2026',
        ),
        throwsA(isA<WrongCurrentPassword>()),
      );
      expect(kickedOut, isFalse);
      expect(await client.get('/auth/me'), contains('profile'));
    });

    test('dar de alta, vincular, editar y eliminar: el ciclo completo contra el servidor', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await adminClient();
      final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));
      final String stamp = '${DateTime.now().millisecondsSinceEpoch}';

      // Alta de un estudiante: recibe un código de verdad, que abre su app.
      final CreatedPerson student = await panel.createStudent(
        NewStudent(fullName: 'Prueba Integración Estudiante', grade: '8° B', document: 'I$stamp'),
      );
      expect(student.code, matches(RegExp(r'^IICB-[A-Z0-9]{4}$')));
      expect(student.person.meetingPoint, isNotNull);

      final ApiClient studentClient = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
      final Session studentSession = await ApiEnrollmentRepository(studentClient)
          .confirmIdentity(PersonalCode.tryParse(student.code)!);
      expect((studentSession.profile as StudentEnrollment).grade, '8° B');

      // Alta de un acudiente vinculado a ese estudiante.
      final CreatedPerson guardian = await panel.createGuardian(
        NewGuardian(
          fullName: 'Prueba Integración Acudiente',
          phone: '3001112233',
          children: <ChildLink>[ChildLink(studentId: student.person.id, relationship: 'Madre')],
        ),
      );
      expect(guardian.person.children.single.fullName, 'Prueba Integración Estudiante');
      expect((await panel.loadPerson(student.person.id)).guardians.single.relationship, 'Madre');

      // Editar: cambiar el celular y quitar el vínculo.
      final PersonUpdate edited = await panel.updatePerson(
        guardian.person.id,
        PersonChanges(phone: '3009998877', children: const <ChildLink>[]),
      );
      expect(edited.person.phone, '3009998877');
      expect(edited.person.children, isEmpty);

      // Un documento repetido llega como el motivo del servidor.
      await expectLater(
        panel.createStudent(NewStudent(fullName: 'Otro Estudiante Más', grade: '8° B', document: 'I$stamp')),
        throwsA(isA<PanelActionFailure>()),
      );

      // Eliminar: dejan de existir.
      await panel.deletePerson(guardian.person.id);
      await panel.deletePerson(student.person.id);
      await expectLater(panel.loadPerson(student.person.id), throwsA(isA<ApiException>()));
    });

    test('cargar un grupo en bloque y reemplazar sus códigos sin usar, contra el servidor', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await adminClient();
      final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));
      final String stamp = '${DateTime.now().millisecondsSinceEpoch}';

      // Una lista con una fila mala no carga ninguna y dice cuál.
      await expectLater(
        panel.importStudents(<NewStudent>[
          NewStudent(fullName: 'Lote Uno Prueba', grade: '7° C', document: 'L1$stamp'),
          const NewStudent(fullName: 'X', grade: '7° C'),
        ]),
        throwsA(isA<PanelActionFailure>().having((e) => e.message, 'mensaje', contains('Fila 2'))),
      );

      final CodeBatch batch = await panel.importStudents(<NewStudent>[
        NewStudent(fullName: 'Lote Uno Prueba', grade: '7° C', document: 'L1$stamp'),
        NewStudent(fullName: 'Lote Dos Prueba', grade: '7° C', document: 'L2$stamp'),
      ]);
      expect(batch.codes, hasLength(2));
      for (final IssuedCode issued in batch.codes) {
        expect(issued.code, matches(RegExp(r'^IICB-[A-Z0-9]{4}$')));
      }
      // Cada código abre la cuenta de su estudiante.
      final ApiClient studentClient = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
      final Session session = await ApiEnrollmentRepository(studentClient)
          .confirmIdentity(PersonalCode.tryParse(batch.codes.first.code)!);
      expect((session.profile as StudentEnrollment).grade, '7° C');

      // Reemplazar los del grupo: el que ya entró no se toca; el otro recibe uno nuevo.
      final CodeBatch again = await panel.generateCodes(grades: <String>['7° C'], reissue: true);
      expect(again.alreadyRegistered, 1);
      expect(again.codes.map((c) => c.personId), <String>[batch.codes.last.personId]);
      expect(again.codes.single.code, isNot(batch.codes.last.code));

      for (final IssuedCode issued in batch.codes) {
        await panel.deletePerson(issued.personId);
      }
    });

    test('la carga trae al acudiente por documento y coordinación ve el código vigente', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await adminClient();
      final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));
      final String stamp = '${DateTime.now().millisecondsSinceEpoch}';

      final CodeBatch batch = await panel.importStudents(<NewStudent>[
        NewStudent(
          fullName: 'Lote Tres Prueba',
          grade: '7° D',
          guardianName: 'Acudiente Lote Prueba',
          guardianDocument: 'G$stamp',
        ),
        NewStudent(
          fullName: 'Lote Cuatro Prueba',
          grade: '7° D',
          guardianName: 'Acudiente Lote Prueba',
          guardianDocument: 'G$stamp',
        ),
      ]);
      expect(batch.codes.map((c) => c.role).toList()..sort(), <String>['acudiente', 'estudiante', 'estudiante']);

      // Coordinación lo ve en la lista mientras está vigente.
      final List<CommunityMember> members = await panel.loadCommunity(query: 'Lote Tres');
      expect(members.single.code, batch.codes.firstWhere((c) => c.fullName == 'Lote Tres Prueba').code);

      for (final IssuedCode issued in batch.codes) {
        await panel.deletePerson(issued.personId);
      }
    });

    test('puntos de encuentro: crear, cambiar y quitar; y editar un protocolo y dejarlo como estaba', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await adminClient();
      final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));

      final String code = await panel.createMeetingPoint(
        const MeetingPointDraft(name: 'Punto de prueba', routeHint: 'Por el corredor', walkMinutes: 2),
      );
      await panel.updateMeetingPoint(
        code,
        const MeetingPointDraft(name: 'Punto de prueba 2', routeHint: 'Por el corredor', walkMinutes: 3),
      );
      final MeetingPoint saved =
          (await panel.loadMeetingPoints()).firstWhere((MeetingPoint p) => p.code == code);
      expect(saved.name, 'Punto de prueba 2');
      expect(saved.walkMinutes, 3);
      await panel.deleteMeetingPoint(code);
      expect((await panel.loadMeetingPoints()).any((MeetingPoint p) => p.code == code), isFalse);

      final Protocol original = (await panel.loadProtocols()).first;
      await panel.saveProtocol(
        Protocol(
          hazard: original.hazard,
          beforeSteps: original.beforeSteps,
          duringSteps: <String>['Paso de prueba de integración'],
          afterSteps: original.afterSteps,
        ),
      );
      expect(
        (await panel.loadProtocols()).firstWhere((Protocol p) => p.hazard == original.hazard).duringSteps,
        <String>['Paso de prueba de integración'],
      );
      await panel.saveProtocol(original);
    });
  });
}
