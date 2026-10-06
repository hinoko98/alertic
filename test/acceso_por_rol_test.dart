import 'package:alertic/core/session/user_role.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_guardian_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'support/fakes/fake_risk_repository.dart';
import 'package:alertic/features/risks/domain/risk_repository.dart';
import 'package:alertic/features/session/domain/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Las dos puertas de entrada de ALERTIC.
///
/// La regla que se comprueba aquí es la que sostiene todo lo demás: **quien
/// puede evacuar el colegio no entra con un papel impreso**. Un código de carné
/// se queda sobre un escritorio, se fotografía y no se puede cambiar.
void main() {
  late FakeAlertRepository alerts;

  setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
  tearDown(() => alerts.dispose());

  /// Pone la pantalla del tamaño de un celular.
  ///
  /// Sin esto, las pruebas corren en 800×600, que para [PanelLayout] es un
  /// escritorio: se probaría la tabla ancha del computador creyendo que se
  /// prueba el celular. Justo lo que hay que comprobar es lo contrario.
  void useAPhoneScreen(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester, {FakeRiskRepository? risks}) async {
    useAPhoneScreen(tester);
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository:
            FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        guardianRepository: FakeGuardianRepository(latency: Duration.zero),
        panelRepository: FakePanelRepository(alerts),
        riskRepository: risks,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSignIn(WidgetTester tester, {FakeRiskRepository? risks}) async {
    await pumpApp(tester, risks: risks);
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
  }

  Future<void> typeCredentials(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, email);
    await tester.enterText(fields.last, password);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  group('los dos caminos no se cruzan', () {
    test('cada rol tiene una sola puerta', () {
      // Es la regla, escrita una sola vez. Si alguien agrega un rol sin decidir
      // por dónde entra, esta prueba lo obliga a decidirlo.
      for (final UserRole role in UserRole.values) {
        expect(
          role.usesCode != role.usesPassword,
          isTrue,
          reason: '${role.wire} tiene que entrar por exactamente un camino',
        );
      }

      expect(UserRole.estudiante.usesCode, isTrue);
      expect(UserRole.acudiente.usesCode, isTrue);
      expect(UserRole.docente.usesPassword, isTrue);
      expect(UserRole.administrador.usesPassword, isTrue);
    });

    test('el código del docente ya no existe en la matrícula', () async {
      // El código que Carlos tenía antes de este cambio. Si siguiera sirviendo,
      // bastaría con una foto de su viejo carné para emitir una alerta.
      await expectLater(
        FakeEnrollmentRepository(latency: Duration.zero).findByCode(
          PersonalCode.tryParse('IICB4F7H')!,
        ),
        throwsA(isA<CodeNotFound>()),
      );
    });

    test('el perfil de un docente no puede traer código', () async {
      // No es una prueba de comportamiento sino de tipos: `CodeEnrollment` es
      // una categoría sellada, y el compilador impide pedirle el código a quien
      // no lo tiene. Esto lo deja escrito para quien lea las pruebas.
      const TeacherEnrollment teacher = TeacherEnrollment(
        fullName: 'Carlos Jaimes Duarte',
        subject: 'Contabilidad',
        groups: <String>['10° B'],
      );
      expect(teacher, isNot(isA<CodeEnrollment>()));

      final Enrollment student = await FakeEnrollmentRepository(
        latency: Duration.zero,
      ).findByCode(PersonalCode.tryParse('IICB7K4P')!);
      expect(student, isA<CodeEnrollment>());
    });
  });

  group('«ya tengo cuenta»', () {
    testWidgets('un docente entra con su correo y llega a su app', (
      WidgetTester tester,
    ) async {
      await openSignIn(tester);
      await typeCredentials(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );

      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();
      if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Terminar y entrar'));
        await tester.pumpAndSettle();
      }

      expect(find.text('GENERAR ALERTA'), findsOneWidget);
      expect(find.text('Contabilidad'), findsOneWidget);
    });

    testWidgets('el correo con mayúsculas del teclado del celular sirve igual', (
      WidgetTester tester,
    ) async {
      // El teclado de Android pone mayúscula en la primera letra. Sin
      // normalizar, nadie entraría y nadie sabría por qué.
      await openSignIn(tester);
      await typeCredentials(
        tester,
        '  Carlos.Jaimes@IIC.edu.co ',
        'Contabilidad2026',
      );

      expect(find.text('Permitir y continuar'), findsOneWidget);
    });

    testWidgets('una contraseña mala no dice si el correo existe', (
      WidgetTester tester,
    ) async {
      // Los dos intentos van en la misma pantalla, que es lo que hace una
      // persona: se equivoca, corrige y vuelve a intentar.
      await openSignIn(tester);

      await typeCredentials(tester, 'carlos.jaimes@iic.edu.co', 'equivocada');
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      await typeCredentials(tester, 'fantasma@iic.edu.co', 'tampoco123');
      expect(
        find.text('Correo o contraseña incorrectos.'),
        findsOneWidget,
        reason: 'el mismo mensaje: distinguirlos revelaría qué cuentas existen',
      );
    });

    testWidgets('un correo sin arroba se frena antes de salir a la red', (
      WidgetTester tester,
    ) async {
      await openSignIn(tester);
      await typeCredentials(tester, 'carlos.jaimes', 'Contabilidad2026');
      expect(find.textContaining('@'), findsWidgets);
      expect(find.text('Permitir y continuar'), findsNothing);
    });

    testWidgets('la contraseña no se ve hasta que la persona lo pide', (
      WidgetTester tester,
    ) async {
      await openSignIn(tester);

      final Finder password = find.byType(TextField).last;
      expect(tester.widget<TextField>(password).obscureText, isTrue);

      await tester.tap(find.byTooltip('Mostrar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
    });
  });

  group('el administrador lleva el panel en el celular', () {
    testWidgets('entra y ve las cuatro pestañas del panel', (
      WidgetTester tester,
    ) async {
      await openSignIn(tester);
      await typeCredentials(
        tester,
        'coordinacion@iic.edu.co',
        'Barbosa2026Riesgo',
      );

      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();
      if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Terminar y entrar'));
        await tester.pumpAndSettle();
      }

      for (final String tab in <String>[
        'Emergencia',
        'Comunidad',
        'Más',
      ]) {
        expect(find.text(tab), findsOneWidget, reason: 'falta la pestaña $tab');
      }
    });

    testWidgets('«Más» lleva a los reportes de riesgo y coordinación los atiende', (
      WidgetTester tester,
    ) async {
      final FakeRiskRepository risks = FakeRiskRepository();
      // Se siembra directo: `report` espera un `Future.delayed`, que dentro de la
      // prueba (reloj simulado) no avanza solo.
      risks.reports.add(
        RiskReport(
          id: 'r1',
          kind: RiskKind.grieta,
          place: 'Bloque B, 2.º piso',
          status: RiskStatus.nuevo,
          createdAt: DateTime.now(),
        ),
      );
      await openSignIn(tester, risks: risks);
      await typeCredentials(
        tester,
        'coordinacion@iic.edu.co',
        'Barbosa2026Riesgo',
      );
      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();
      if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Terminar y entrar'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Simulacros'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Protocolos'), findsOneWidget);

      await tester.tap(find.text('Reportes de riesgo'));
      await tester.pumpAndSettle();
      expect(find.text('Grieta o daño'), findsOneWidget);
      expect(find.textContaining('Bloque B, 2.º piso'), findsOneWidget);

      await tester.tap(find.byKey(const Key('riesgo-r1-atendido')));
      await tester.pumpAndSettle();
      expect(risks.reports.single.status, RiskStatus.atendido);
    });

    testWidgets('la comunidad se ve como tarjetas, no como tabla', (
      WidgetTester tester,
    ) async {
      await openSignIn(tester);
      await typeCredentials(
        tester,
        'coordinacion@iic.edu.co',
        'Barbosa2026Riesgo',
      );
      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();
      if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Terminar y entrar'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Comunidad'));
      await tester.pumpAndSettle();

      expect(find.text('COMUNIDAD'), findsOneWidget);
      // La cabecera de la tabla del computador no aparece en un celular: seis
      // columnas ahí dejarían cuatro caracteres por campo.
      expect(find.text('VINCULADO CON'), findsNothing);
    });

    test('la sesión trae el rol que decidió el servidor', () async {
      final Session session = await FakeCredentialsRepository(
        latency: Duration.zero,
      ).signIn(_credentials('coordinacion@iic.edu.co', 'Barbosa2026Riesgo'));

      expect(session.role, UserRole.administrador);
      expect(session.profile, isA<AdminEnrollment>());
      expect((session.profile as AdminEnrollment).scope, 'Todo el instituto');
    });
  });

  group('lo que no se muestra', () {
    test('las credenciales no imprimen la contraseña', () {
      final Credentials credentials =
          _credentials('carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      expect(credentials.toString(), contains('carlos.jaimes@iic.edu.co'));
      expect(
        credentials.toString(),
        isNot(contains('Contabilidad2026')),
        reason: 'una contraseña en un log es una contraseña filtrada',
      );
    });
  });
}

Credentials _credentials(String email, String password) {
  final (Credentials? credentials, String? problem) = Credentials.tryBuild(
    email: email,
    password: password,
  );
  if (credentials == null) {
    throw StateError('credenciales de prueba inválidas: $problem');
  }
  return credentials;
}
