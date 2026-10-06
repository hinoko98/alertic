import 'dart:convert';

import 'package:alertic/app/app_scope.dart';
import 'package:alertic/app/role_experience.dart';
import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/session/user_role.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'package:alertic/features/account/presentation/account_screen.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'package:alertic/features/onboarding/data/api_credentials_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:alertic/features/panel/data/api_panel_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'package:alertic/features/panel/domain/community_admin.dart';
import 'package:alertic/features/panel/domain/group_name.dart';
import 'package:alertic/features/panel/presentation/screens/community_tab.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:alertic/features/session/domain/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Lo que coordinación cambia desde el panel, y la pantalla de cuenta que le
/// faltaba a docentes, acudientes y coordinación.
void main() {
  group('nombre de un grupo', () {
    test('lo que se escribe a mano queda en el formato del servidor', () {
      expect(GroupName.normalize('10b'), '10° B');
      expect(GroupName.normalize(' 9 c '), '9° C');
      expect(GroupName.normalize('11° a'), '11° A');
      expect(GroupName.normalize('6° A'), '6° A');
    });

    test('lo que no es un grupo no pasa', () {
      expect(GroupName.normalize(''), isNull);
      expect(GroupName.normalize('12° A'), isNull);
      expect(GroupName.normalize('0° A'), isNull);
      expect(GroupName.normalize('10° BB'), isNull);
      expect(GroupName.normalize('<script>'), isNull);
    });

    test('se ordena por número: 6° A va antes que 10° A', () {
      final List<String> groups = <String>['10° B', '6° A', '11° A', '10° A', '7° B']
        ..sort(GroupName.compare);
      expect(groups, <String>['6° A', '7° B', '10° A', '10° B', '11° A']);
    });
  });

  group('lo que se manda al servidor', () {
    test('solo viaja lo que cambió', () {
      expect(const PersonChanges(grade: '6° A').toJson(), <String, Object?>{'grade': '6° A'});
      expect(const PersonChanges().isEmpty, isTrue);
    });

    test('dejar de ser director se manda como null explícito, no se omite', () {
      // Omitirlo significaría «no tocar», que es lo contrario.
      expect(
        const PersonChanges(removeHomeroom: true).toJson(),
        <String, Object?>{'homeroomGroup': null},
      );
    });
  });

  group('el panel contra la API', () {
    late List<http.Request> sent;

    ApiPanelRepository repositoryAnswering(
      http.Response Function(http.Request request) answer,
    ) {
      sent = <http.Request>[];
      final ApiClient api = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((http.Request request) async {
          sent.add(request);
          return answer(request);
        }),
      );
      return ApiPanelRepository(api, FakeAlertRepository(latency: Duration.zero));
    }

    http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: <String, String>{'content-type': 'application/json'},
        );

    test('guardar manda un PATCH a esa persona, solo con lo cambiado', () async {
      final ApiPanelRepository repository = repositoryAnswering(
        (_) => json(<String, Object?>{
          'person': <String, Object?>{
            'id': 'abc',
            'fullName': 'Nubia Silva Castro',
            'role': 'docente',
            'access': 'con_cuenta',
            'homeroomGroup': '10° B',
            'groups': <String>['10° B', '6° A'],
          },
          'replacedDirector': <String, Object?>{
            'id': 'xyz',
            'fullName': 'Carlos Jaimes Duarte',
            'group': '10° B',
          },
        }),
      );

      final PersonUpdate update = await repository.updatePerson(
        'abc',
        const PersonChanges(homeroomGroup: '10° B'),
      );

      expect(sent.single.method, 'PATCH');
      expect(sent.single.url.path, '/community/abc');
      expect(jsonDecode(sent.single.body), <String, Object?>{'homeroomGroup': '10° B'});
      expect(update.person.homeroomGroup, '10° B');
      expect(update.replacedDirector!.person.fullName, 'Carlos Jaimes Duarte');
      expect(update.replacedDirector!.group, '10° B');
    });

    test('si el servidor lo rechaza, coordinación ve SU motivo', () async {
      final ApiPanelRepository repository = repositoryAnswering(
        (_) => json(<String, Object?>{
          'error': 'conflicto',
          'message': 'Ese correo ya lo usa otra cuenta.',
        }, 409),
      );

      expect(
        () => repository.updatePerson('abc', const PersonChanges(email: 'x@iic.edu.co')),
        throwsA(
          isA<PanelActionFailure>().having(
            (PanelActionFailure f) => f.message,
            'mensaje',
            'Ese correo ya lo usa otra cuenta.',
          ),
        ),
      );
    });

    test('un código emitido sin credencial en la respuesta es un error, no un diálogo vacío', () async {
      final ApiPanelRepository repository = repositoryAnswering((_) => json(<String, Object?>{}));

      expect(() => repository.renewCode('abc'), throwsA(isA<PanelActionFailure>()));
    });

    test('la contraseña temporal de un docente nuevo llega y se manda sin rol', () async {
      final ApiPanelRepository repository = repositoryAnswering(
        (_) => json(<String, Object?>{
          'person': <String, Object?>{
            'id': 'n1',
            'fullName': 'Ana María Torres Ruiz',
            'role': 'docente',
            'access': 'con_cuenta',
            'email': 'ana@iic.edu.co',
            'groups': <String>['7° B'],
          },
          'temporaryPassword': 'ABCD-EFGH-JKMN',
        }, 201),
      );

      final CreatedTeacher created = await repository.createTeacher(
        const NewTeacher(
          fullName: 'Ana María Torres Ruiz',
          email: 'ana@iic.edu.co',
          subject: 'Inglés',
          groups: <String>['7° B'],
        ),
      );

      expect(created.temporaryPassword, 'ABCD-EFGH-JKMN');
      // El rol lo decide el servidor: la app no puede pedir ser coordinación.
      expect(jsonDecode(sent.single.body), isNot(contains('role')));
      expect(sent.single.url.path, '/community/teachers');
    });

    test('un identificador raro no escapa de su ruta', () async {
      final ApiPanelRepository repository = repositoryAnswering((_) => json(<String, Object?>{}));

      await repository.closeSessions('../auth/login');

      expect(sent.single.url.path, isNot(contains('/auth/login')));
      expect(sent.single.url.toString(), contains('%2F'));
    });
  });

  group('cambiar la contraseña contra la API', () {
    http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: <String, String>{'content-type': 'application/json'},
        );

    test('el token nuevo reemplaza al viejo: la sesión no se cae sola', () async {
      final List<http.Request> sent = <http.Request>[];
      final ApiClient api = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((http.Request request) async {
          sent.add(request);
          return request.url.path == '/auth/password'
              ? json(<String, Object?>{'token': 'token-nuevo'})
              : json(<String, Object?>{});
        }),
      )..useToken('token-viejo');

      await ApiCredentialsRepository(api).changePassword(
        currentPassword: 'la-de-antes-123',
        newPassword: 'la-de-ahora-456',
      );
      await api.get('/auth/me');

      expect(sent.first.headers['authorization'], 'Bearer token-viejo');
      // Sin guardar el token nuevo, esta petición saldría con el viejo, que el
      // servidor acaba de invalidar, y la sesión se cerraría sola.
      expect(sent.last.headers['authorization'], 'Bearer token-nuevo');
    });

    test('equivocarse en la actual no es «sesión vencida»', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((_) async => json(<String, Object?>{
              'error': 'contrasena_actual_incorrecta',
              'message': 'La contraseña actual no es correcta.',
            }, 400)),
      );
      bool kickedOut = false;
      api.onUnauthorized = () => kickedOut = true;

      await expectLater(
        ApiCredentialsRepository(api).changePassword(
          currentPassword: 'mal',
          newPassword: 'la-de-ahora-456',
        ),
        throwsA(isA<WrongCurrentPassword>()),
      );
      expect(kickedOut, isFalse);
    });
  });

  group('cada rol puede cerrar sesión', () {
    Session sessionOf(Enrollment profile) => Session(
          token: 't',
          profile: profile,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

    test('docente, acudiente y coordinación tienen la pestaña Cuenta', () {
      const TeacherEnrollment teacher = TeacherEnrollment(
        fullName: 'Carlos Jaimes Duarte',
        subject: 'Contabilidad',
        groups: <String>['10° B'],
      );
      const AdminEnrollment admin = AdminEnrollment(
        fullName: 'Gloria Amparo Rueda Sánchez',
        scope: 'Todo el instituto',
      );

      for (final (UserRole role, Enrollment profile) in <(UserRole, Enrollment)>[
        (UserRole.docente, teacher),
        (UserRole.administrador, admin),
      ]) {
        final List<String> labels = RoleExperiences.forRole(role)
            .buildDestinations(sessionOf(profile))
            .map((AppDestination d) => d.label)
            .toList();
        expect(labels.last, 'Cuenta', reason: 'el rol ${role.wire} no podía salir');
      }
    });
  });

  group('pantalla de cuenta', () {
    Future<FakeCredentialsRepository> pumpAccount(
      WidgetTester tester,
      Enrollment enrollment, {
      String? signedInAs,
      InMemorySessionStore? store,
    }) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(400, 860);
      addTearDown(tester.view.reset);

      final FakeCredentialsRepository credentials =
          FakeCredentialsRepository(latency: Duration.zero);
      if (signedInAs != null) {
        // Fuera del reloj falso de `testWidgets`: el `Future.delayed` del doble
        // solo avanza al bombear, y aquí no hay nada que bombear todavía.
        await tester.runAsync(
          () => credentials.signIn(
            Credentials.tryBuild(
              email: signedInAs,
              password: signedInAs.startsWith('carlos')
                  ? 'Contabilidad2026'
                  : 'Barbosa2026Riesgo',
            ).$1!,
          ),
        );
      }

      await tester.pumpWidget(
        AppScope(
          enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
          credentialsRepository: credentials,
          alertRepository: FakeAlertRepository(latency: Duration.zero),
          sessionStore: store ?? InMemorySessionStore(),
          notifications: SilentNotificationService(),
          deviceRegistrar: const NoDeviceRegistrar(),
          child: MaterialApp(
            theme: AppTheme.build(),
            initialRoute: '/cuenta',
            routes: <String, WidgetBuilder>{
              '/': (_) => const Scaffold(body: Text('PANTALLA DE BIENVENIDA')),
              '/cuenta': (_) => AccountScreen(enrollment: enrollment),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return credentials;
    }

    const TeacherEnrollment carlos = TeacherEnrollment(
      fullName: 'Carlos Jaimes Duarte',
      subject: 'Contabilidad',
      groups: <String>['10° A', '10° B'],
      homeroomGroup: '10° B',
      email: 'carlos.jaimes@iic.edu.co',
    );

    testWidgets('un docente ve sus datos y puede salir', (WidgetTester tester) async {
      await pumpAccount(tester, carlos);

      expect(find.text('Carlos Jaimes Duarte'), findsOneWidget);
      expect(find.text('carlos.jaimes@iic.edu.co'), findsOneWidget);
      expect(find.text('10° A, 10° B'), findsOneWidget);
      expect(find.byKey(const Key('cambiar-contrasena')), findsOneWidget);
      expect(find.byKey(const Key('cerrar-sesion')), findsOneWidget);
    });

    testWidgets('salir pregunta primero, y cancelar no cierra nada', (
      WidgetTester tester,
    ) async {
      await pumpAccount(tester, carlos);

      await tester.tap(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      // A un docente se le dice con qué vuelve a entrar, no que necesita un código.
      expect(find.textContaining('correo y tu contraseña'), findsOneWidget);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(find.text('PANTALLA DE BIENVENIDA'), findsNothing);
      expect(find.text('Tu cuenta'), findsOneWidget);
    });

    testWidgets('confirmar borra la sesión y vuelve al inicio', (
      WidgetTester tester,
    ) async {
      final InMemorySessionStore store = InMemorySessionStore();
      await store.save(
        Session(
          token: 't',
          profile: carlos,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await pumpAccount(tester, carlos, store: store);

      await tester.tap(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'CERRAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.text('PANTALLA DE BIENVENIDA'), findsOneWidget);
      expect(await store.read(), isNull, reason: 'la sesión guardada no se borró');
    });

    testWidgets('un acudiente no tiene contraseña que cambiar y sale con su mensaje', (
      WidgetTester tester,
    ) async {
      await pumpAccount(
        tester,
        GuardianEnrollment(
          code: PersonalCode.tryParse('IICB-3HW8')!,
          fullName: 'Martha Gómez Ardila',
          maskedPhone: '310 ••• 4521',
          children: <LinkedStudent>[
            LinkedStudent(fullName: 'Laura Camila Pérez Gómez', grade: '10° B', shift: 'Mañana'),
          ],
        ),
      );

      expect(find.byKey(const Key('cambiar-contrasena')), findsNothing);
      expect(find.text('310 ••• 4521'), findsOneWidget);
      expect(find.text('Laura Camila Pérez Gómez'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('código nuevo'),
        ),
        findsOneWidget,
      );
    });

    group('cambiar la contraseña', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(find.byKey(const Key('cambiar-contrasena')));
        await tester.pumpAndSettle();
      }

      Future<void> fill(
        WidgetTester tester, {
        String current = '',
        String next = '',
        String confirm = '',
      }) async {
        await tester.enterText(find.widgetWithText(TextField, 'Contraseña actual'), current);
        await tester.enterText(find.widgetWithText(TextField, 'Contraseña nueva'), next);
        await tester.enterText(
          find.widgetWithText(TextField, 'Repite la contraseña nueva'),
          confirm,
        );
        await tester.tap(find.widgetWithText(InkWell, 'CAMBIAR CONTRASEÑA').last);
        await tester.pumpAndSettle();
      }

      testWidgets('avisa de lo que falta antes de molestar al servidor', (
        WidgetTester tester,
      ) async {
        await pumpAccount(tester, carlos, signedInAs: 'carlos.jaimes@iic.edu.co');
        await openSheet(tester);

        await fill(tester, current: 'Contabilidad2026', next: 'corta', confirm: 'corta');
        expect(find.textContaining('al menos 10 caracteres'), findsOneWidget);

        await fill(
          tester,
          current: 'Contabilidad2026',
          next: 'Una-Clave-Larga-1',
          confirm: 'Otra-Distinta-22',
        );
        expect(find.textContaining('no coincide'), findsOneWidget);

        await fill(
          tester,
          current: 'Contabilidad2026',
          next: 'Contabilidad2026',
          confirm: 'Contabilidad2026',
        );
        expect(find.textContaining('distinta de la actual'), findsOneWidget);
      });

      testWidgets('una contraseña actual equivocada se dice con claridad', (
        WidgetTester tester,
      ) async {
        await pumpAccount(tester, carlos, signedInAs: 'carlos.jaimes@iic.edu.co');
        await openSheet(tester);

        await fill(
          tester,
          current: 'no-es-esta-123',
          next: 'Una-Clave-Larga-1',
          confirm: 'Una-Clave-Larga-1',
        );

        expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
        // Sigue abierta: quien se equivocó puede corregir sin volver a empezar.
        expect(find.byType(BottomSheet), findsOneWidget);
      });

      testWidgets('al lograrlo se cierra la hoja y se avisa', (WidgetTester tester) async {
        await pumpAccount(tester, carlos, signedInAs: 'carlos.jaimes@iic.edu.co');
        await openSheet(tester);

        await fill(
          tester,
          current: 'Contabilidad2026',
          next: 'Una-Clave-Larga-1',
          confirm: 'Una-Clave-Larga-1',
        );

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.textContaining('Contraseña cambiada'), findsOneWidget);
      });
    });
  });

  group('comunidad: administrar personas', () {
    Future<void> pumpCommunity(WidgetTester tester, {Size size = const Size(400, 2600)}) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = size;
      addTearDown(tester.view.reset);

      final FakeAlertRepository alerts = FakeAlertRepository(latency: Duration.zero);
      addTearDown(alerts.dispose);

      await tester.pumpWidget(
        AppScope(
          enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
          credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
          alertRepository: alerts,
          sessionStore: InMemorySessionStore(),
          notifications: SilentNotificationService(),
          deviceRegistrar: const NoDeviceRegistrar(),
          panelRepository: FakePanelRepository(alerts),
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const Scaffold(body: CommunityTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openPerson(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    /// Una opción de grupo **dentro de la hoja**. En el computador el listado de
    /// atrás también tiene el texto «10° B» (la columna GRADO), y un buscador sin
    /// acotar toca la fila escondida detrás de la hoja.
    Finder chip(String label, {bool last = false}) {
      final Finder found = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(InkWell, label),
      );
      return last ? found.last : found.first;
    }

    /// Deja correr lo que el servidor tarda. `pumpAndSettle` solo espera cuadros
    /// animados, y una llamada que no anima nada se quedaría a medias.
    Future<void> flush(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await flush(tester);
    }

    testWidgets('tocar a alguien abre su hoja con lo que se puede cambiar', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester);
      await openPerson(tester, 'Laura Camila Pérez Gómez');

      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
      expect(find.text('EMITIR CÓDIGO NUEVO'), findsOneWidget);
      expect(find.text('CERRAR SESIONES'), findsOneWidget);
      // Un estudiante no tiene contraseña: no se le ofrece restablecerla.
      expect(find.text('RESTABLECER CONTRASEÑA'), findsNothing);
    });

    testWidgets('cambiar a un estudiante de grupo se ve en el listado', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester);
      await openPerson(tester, 'Laura Camila Pérez Gómez');

      // Los grupos vienen del servidor: se elige, no se escribe.
      await tester.tap(chip('11° A'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(find.text('Cambios guardados.'), findsOneWidget);
      await closeSheet(tester);

      expect(
        find.textContaining('Estudiante · 11° A'),
        findsOneWidget,
        reason: 'el listado debía recargarse con el grupo nuevo',
      );
    });

    testWidgets('sin cambios no hay nada que guardar', (WidgetTester tester) async {
      await pumpCommunity(tester);
      await openPerson(tester, 'Laura Camila Pérez Gómez');

      await save(tester);

      expect(find.text('No hay cambios que guardar.'), findsOneWidget);
    });

    testWidgets('quien toma la dirección de un grupo lo dice, y el anterior la pierde', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));
      await openPerson(tester, 'Nubia Silva Castro');

      // Director de grupo: se elige 10° B, que hoy dirige Carlos.
      await tester.tap(chip('10° B'));
      await tester.pumpAndSettle();

      // Antes de guardar, se le avisa de lo que va a pasar.
      expect(
        find.text('Hoy lo dirige Carlos Jaimes Duarte. Al guardar, dejará de dirigirlo.'),
        findsOneWidget,
      );

      await save(tester);

      expect(
        find.textContaining('Carlos Jaimes dejó de dirigir 10° B.'),
        findsOneWidget,
      );

      // Y el aviso de antes ya no vale: el grupo ahora es de ella. Con la lista de
      // grupos vieja, la hoja seguía diciendo «hoy lo dirige Carlos» después de
      // quitárselo.
      expect(find.textContaining('Hoy lo dirige'), findsNothing);
    });

    testWidgets('un correo repetido se rechaza con el motivo del servidor, dentro de la hoja', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));
      await openPerson(tester, 'Nubia Silva Castro');

      await tester.enterText(
        find.widgetWithText(TextField, 'Correo con el que entra'),
        'carlos.jaimes@iic.edu.co',
      );
      await save(tester);

      // Dentro de la hoja: un SnackBar quedaría detrás y no se vería.
      expect(find.text('Ese correo ya lo usa otra cuenta.'), findsOneWidget);
    });

    testWidgets('un código nuevo se muestra una sola vez y el diálogo no se cierra por accidente', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester);
      await openPerson(tester, 'Laura Camila Pérez Gómez');

      await tester.tap(find.text('EMITIR CÓDIGO NUEVO'));
      await tester.pumpAndSettle();
      expect(find.text('¿Emitir un código nuevo?'), findsOneWidget);
      await tester.tap(find.text('EMITIR'));
      await flush(tester);

      expect(find.text('CÓDIGO NUEVO'), findsOneWidget);
      expect(find.byKey(const Key('secreto-emitido')), findsOneWidget);
      expect(find.textContaining('Se muestra una sola vez'), findsOneWidget);

      // Un toque fuera no lo cierra: perder el código recién creado obligaría a
      // emitir otro y a dejar el anterior revocado en vano.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('secreto-emitido')), findsOneWidget);

      await tester.tap(find.text('LISTO'));
      await flush(tester);
      expect(find.byKey(const Key('secreto-emitido')), findsNothing);
    });

    testWidgets('crear un docente muestra su contraseña temporal y lo agrega al listado', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));

      await tester.tap(find.text('NUEVO DOCENTE'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana María Torres Ruiz',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo con el que entra'),
        'ana.torres@iic.edu.co',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Materia'), 'Inglés');

      // Grupos que dicta: el segundo selector de grupos de la hoja.
      await tester.tap(chip('7° B', last: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CREAR CUENTA'));
      await flush(tester);

      expect(find.text('CONTRASEÑA TEMPORAL'), findsOneWidget);
      expect(find.text('DEMO-AB23-XY45'), findsOneWidget);
      expect(find.textContaining('Entra con ana.torres@iic.edu.co'), findsOneWidget);

      await tester.tap(find.text('LISTO'));
      await flush(tester);

      expect(find.text('Nuevo docente'), findsNothing, reason: 'la hoja debía cerrarse');
      expect(find.text('Ana María Torres Ruiz'), findsOneWidget);
    });

    testWidgets('crear un docente sin grupo se frena antes de ir al servidor', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));

      await tester.tap(find.text('NUEVO DOCENTE'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana María Torres Ruiz',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo con el que entra'),
        'ana.torres@iic.edu.co',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Materia'), 'Inglés');
      await tester.tap(find.text('CREAR CUENTA'));
      await tester.pumpAndSettle();

      expect(find.text('Elige al menos un grupo.'), findsOneWidget);
      expect(find.text('CONTRASEÑA TEMPORAL'), findsNothing);
    });

    testWidgets('dar de baja a un docente pide confirmar y deja su cuenta sin acceso', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));
      await openPerson(tester, 'Nubia Silva Castro');

      await tester.tap(find.text('DAR DE BAJA'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Su historial se conserva'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'DAR DE BAJA'));
      await flush(tester);

      expect(find.textContaining('ya no tiene acceso'), findsOneWidget);
      // Ya no se le puede dar de baja otra vez; se le ofrece volver a darle acceso.
      expect(find.text('DAR DE BAJA'), findsNothing);
      expect(find.text('DAR ACCESO (CONTRASEÑA NUEVA)'), findsOneWidget);
    });

    testWidgets('restablecer la contraseña de un docente entrega una temporal', (
      WidgetTester tester,
    ) async {
      await pumpCommunity(tester, size: const Size(1280, 2000));
      await openPerson(tester, 'Carlos Jaimes Duarte');

      await tester.tap(find.text('RESTABLECER CONTRASEÑA'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'RESTABLECER'));
      await flush(tester);

      expect(find.text('CONTRASEÑA TEMPORAL'), findsOneWidget);
      expect(find.text('DEMO-RS37-KM92'), findsOneWidget);
    });
  });
}
