import 'package:alertic/app/role_experience.dart';
import 'package:alertic/core/session/user_role.dart';
import 'package:alertic/features/account/domain/account_repository.dart';
import 'package:alertic/features/account/presentation/account_screen.dart';
import 'package:alertic/features/account/domain/alert_preferences.dart';
import 'package:alertic/features/account/domain/evacuation_support.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/risks/domain/risk_repository.dart';
import 'package:alertic/features/alerts/domain/evacuation_rating.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/safety_report.dart';
import 'package:alertic/features/drills/domain/drill_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes/fake_account_repository.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_drill_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_risk_repository.dart';
import 'support/fakes/fake_support_repository.dart';
import 'support/test_app.dart';

/// Recorrido del estudiante: entrar, ver su inicio, recibir una alerta y
/// responderla, y las pestañas que usa en calma.
void main() {
  late FakeAlertRepository alerts;
  late FakeAccountRepository account;
  late FakeDrillRepository drills;
  late FakeRiskRepository risks;
  late FakeSupportRepository support;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    account = FakeAccountRepository();
    drills = FakeDrillRepository();
    risks = FakeRiskRepository();
    support = FakeSupportRepository();
  });

  tearDown(() {
    alerts.dispose();
    risks.dispose();
    support.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Un celular alto: las pantallas son listas y lo que queda más abajo no se
    // construye hasta que entra en pantalla.
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(411, 1100);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        accountRepository: account,
        drillRepository: drills,
        riskRepository: risks,
        supportRepository: support,
        liveUpdates: risks,
      ),
    );
  }

  /// Hace el registro completo con el código que se le pase y deja la app
  /// abierta en el inicio del rol correspondiente.
  Future<void> signIn(WidgetTester tester, String code) async {
    await pumpApp(tester);
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, code.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.enterText(fields.last, code.substring(4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sí, soy yo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir y continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar y entrar'));
    await tester.pumpAndSettle();
  }

  group('la app que abre cada rol', () {
    testWidgets('el estudiante entra a su app con las cinco pestañas', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      expect(find.text('Sin alertas activas'), findsOneWidget);
      expect(find.text('Hola, Laura'), findsOneWidget);
      expect(find.textContaining('Instituto Integrado de Comercio'), findsOneWidget);
      expect(find.text('Cancha central'), findsOneWidget);
      for (final String tab in <String>['Inicio', 'Mapa', 'Guías', 'Reportar', 'Perfil']) {
        expect(find.text(tab), findsWidgets);
      }
      // Y el chat y la ayuda, siempre a mano en la cabecera.
      expect(find.byKey(const Key('abrir-chat')), findsOneWidget);
      expect(find.text('Ayuda'), findsOneWidget);
    });

    testWidgets('los permisos que eligió se guardan en el colegio', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.first, 'IICB');
      await tester.pumpAndSettle();
      await tester.enterText(fields.last, '7K4P');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, soy yo'));
      await tester.pumpAndSettle();

      // Apaga la ubicación y continúa.
      await tester.tap(find.byKey(const Key('permiso-ubicacion')));
      await tester.pump();
      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();

      expect(account.settings.shareLocation, isFalse);
      expect(account.settings.criticalAlerts, isTrue);
    });

    testWidgets('el docente entra a su propia app, no a la del estudiante', (
      WidgetTester tester,
    ) async {
      // Por correo y contraseña: es la única forma que tiene un docente. El
      // código del carné es solo para estudiantes y acudientes.
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya tengo cuenta'));
      await tester.pumpAndSettle();

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.first, 'carlos.jaimes@iic.edu.co');
      await tester.enterText(fields.last, 'Contabilidad2026');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Permitir y continuar'));
      await tester.pumpAndSettle();

      expect(find.text('GENERAR ALERTA'), findsOneWidget);
      // No ve las pestañas del estudiante ni su punto de encuentro.
      expect(find.text('Mapa'), findsNothing);
      expect(find.text('Necesito ayuda'), findsNothing);
    });

    test('la fábrica de roles arma una app distinta por rol', () {
      expect(RoleExperiences.forRole(UserRole.estudiante), isA<StudentExperience>());
      expect(RoleExperiences.forRole(UserRole.docente), isA<TeacherExperience>());
      expect(RoleExperiences.forRole(UserRole.acudiente), isA<GuardianExperience>());
      expect(RoleExperiences.forRole(UserRole.administrador), isA<AdminExperience>());
    });
  });

  group('la alerta entra por encima de todo', () {
    testWidgets('al terminar una alerta roja dice que es seguro regresar y pregunta cómo le fue', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      alerts.clear();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('es-seguro-regresar')), findsOneWidget);
      expect(find.text('Terminó la alerta de sismo. Regresa al salón con tu docente.'),
          findsOneWidget);
      // No respondió desde el celular: no se inventa una hora ni un tiempo.
      expect(find.text('Confirmaste a salvo'), findsNothing);

      await tester.tap(find.byKey(const Key('opinion-regular')));
      await tester.pumpAndSettle();
      expect(alerts.feedback, <EvacuationRating>[EvacuationRating.fair]);
      expect(find.textContaining('Gracias.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('volver-al-inicio')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('es-seguro-regresar')), findsNothing);
    });

    testWidgets('una alerta amarilla que termina se apaga sin pantalla de despedida', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.amarilla);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      alerts.clear();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('es-seguro-regresar')), findsNothing);
    });

    testWidgets('en amarilla se puede reportar algo peligroso sin salir de la alerta', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.amarilla);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reportar-peligro')));
      await tester.pumpAndSettle();

      expect(find.text('Reportar un riesgo'), findsOneWidget);
    });

    testWidgets('una alerta amarilla se lee y se cierra con «entendido»', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.amarilla);
      await tester.pumpAndSettle();

      expect(find.text('LLUVIA FUERTE'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // Vuelve al inicio, pero la alerta sigue visible como estado del colegio.
      expect(find.text('Entendido'), findsNothing);
      expect(find.textContaining('LLUVIA FUERTE'), findsOneWidget);
    });

    testWidgets('la alerta roja no se cierra: ofrece ruta, «a salvo» y «ayuda»', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      expect(find.text('SISMO'), findsOneWidget);
      expect(find.text('QUÉ HACER AHORA'), findsOneWidget);
      expect(find.byKey(const Key('ver-mi-ruta')), findsOneWidget);
      expect(find.byKey(const Key('estoy-a-salvo')), findsOneWidget);
      expect(find.byKey(const Key('necesito-ayuda-alerta')), findsOneWidget);

      // El botón de atrás no la quita.
      final NavigatorState navigator = tester.state(find.byType(Navigator).first);
      navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estoy-a-salvo')), findsOneWidget);
    });

    testWidgets('«estoy a salvo» pregunta dónde, lo envía y confirma a quién avisó', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('estoy-a-salvo')));
      await tester.pumpAndSettle();

      expect(find.text('¿Dónde estás?'), findsOneWidget);
      expect(find.textContaining('En el punto P1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('enviar-a-salvo')));
      await tester.pumpAndSettle();

      expect(alerts.submitted.single.status, SafetyStatus.safe);
      expect(alerts.submitted.single.location, ReportedLocation.atMeetingPoint);

      // La confirmación dice a quién se le avisó, sin prometer de más.
      expect(find.byKey(const Key('estas-a-salvo')), findsOneWidget);
      expect(find.textContaining('Martha Gómez'), findsOneWidget);
      expect(find.text('Aviso enviado'), findsNWidgets(2));
      expect(find.textContaining('La alerta sigue activa'), findsOneWidget);

      // Volver al inicio: la alerta ya no pide respuesta.
      await tester.tap(find.byKey(const Key('volver-al-inicio')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estoy-a-salvo')), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets('si la persona apagó el aviso a su familia, la confirmación lo dice', (
      WidgetTester tester,
    ) async {
      account.settings = account.settings.copyWith(notifyFamily: false);
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estoy-a-salvo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('enviar-a-salvo')));
      await tester.pumpAndSettle();

      expect(find.text('Apagaste el aviso a tu familia'), findsNWidgets(2));
      expect(find.text('Aviso enviado'), findsNothing);
    });

    testWidgets('«necesito ayuda» manda qué pasa y dónde, y confirma', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('necesito-ayuda-alerta')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Estoy atrapado'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('detalles-ayuda')), 'Puerta trabada');
      await tester.tap(find.byKey(const Key('enviar-ayuda')));
      await tester.pumpAndSettle();

      final SafetyReport sent = alerts.submitted.single;
      expect(sent.status, SafetyStatus.needsHelp);
      expect(sent.helpKind, HelpKind.trapped);
      expect(sent.helpDetails, 'Puerta trabada');

      expect(find.byKey(const Key('ayuda-enviada')), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      // Ya respondió: la alerta deja de taparle la app.
      expect(find.byKey(const Key('necesito-ayuda-alerta')), findsNothing);
    });

    testWidgets('la ruta guiada lleva al punto y, al llegar, confirma a salvo', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ver-mi-ruta')));
      await tester.pumpAndSettle();

      // Los pasos salen del salón y de lo que el colegio escribió del punto.
      expect(find.byKey(const Key('paso-actual')), findsOneWidget);
      expect(find.textContaining('Sal del salón Aula 7 · Bloque A'), findsWidgets);
      expect(find.textContaining('Llega al punto P1 · Cancha central'), findsOneWidget);

      await tester.tap(find.byKey(const Key('siguiente-paso')));
      await tester.pump();
      expect(find.textContaining('Paso 2 de'), findsOneWidget);

      await tester.tap(find.byKey(const Key('llegue-al-punto')));
      await tester.pumpAndSettle();
      expect(find.text('Llegaste al punto P1'), findsOneWidget);
      expect(find.textContaining('No regreses a los salones'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmar-a-salvo')));
      await tester.pumpAndSettle();

      expect(alerts.submitted.single.status, SafetyStatus.safe);
      expect(find.byKey(const Key('estas-a-salvo')), findsOneWidget);
    });

    testWidgets('si la ruta está bloqueada, coordinación lo recibe como reporte', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('iniciar-ruta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ruta-bloqueada')));
      await tester.pumpAndSettle();

      expect(risks.reports, hasLength(1));
      expect(risks.reports.single.place, contains('P1'));
      expect(find.textContaining('Avisamos a coordinación'), findsOneWidget);
    });
  });

  group('«necesito ayuda» sin alerta', () {
    testWidgets('sale como un mensaje urgente en el chat con el colegio', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.byKey(const Key('necesito-ayuda')));
      await tester.pumpAndSettle();
      expect(find.text('Necesito ayuda'), findsWidgets);
      expect(find.text('¿QUÉ PASA?'), findsOneWidget);
      // Tu salón se comparte, y se dice.
      expect(find.text('Aula 7 · Bloque A'), findsOneWidget);

      await tester.tap(find.text('Estoy herido'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('detalles-ayuda')), 'Me torcí el tobillo');
      await tester.tap(find.byKey(const Key('enviar-ayuda')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ayuda-enviada')), findsOneWidget);
      final message = support.messages.single;
      expect(message.urgent, isTrue);
      expect(message.body, contains('estoy herido'));
      expect(message.body, contains('Aula 7 · Bloque A'));
      expect(message.body, contains('Me torcí el tobillo'));
    });

    testWidgets('si no llega, lo dice y no confirma nada', (WidgetTester tester) async {
      await signIn(tester, 'IICB7K4P');
      support.failNextSend = true;

      await tester.tap(find.byKey(const Key('necesito-ayuda')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('enviar-ayuda')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ayuda-enviada')), findsNothing);
      expect(find.byKey(const Key('error-ayuda')), findsOneWidget);
      expect(find.textContaining('Línea 123'), findsWidgets);
    });
  });

  group('las pestañas del estudiante', () {
    testWidgets('el inicio muestra el próximo simulacro si hay uno', (
      WidgetTester tester,
    ) async {
      drills.upcoming.add(
        Drill(
          id: 'd1',
          hazard: Hazard.sismo,
          scheduledAt: DateTime.now().add(const Duration(days: 3)),
          scope: 'Todo el colegio',
        ),
      );
      await signIn(tester, 'IICB7K4P');

      expect(find.byKey(const Key('proximo-simulacro')), findsOneWidget);
      expect(find.textContaining('Próximo simulacro de sismos'), findsOneWidget);
    });

    testWidgets('el mapa muestra la ruta al punto de encuentro', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();

      expect(find.text('Mapa de evacuación'), findsOneWidget);
      // El punto de la persona sale de su perfil...
      expect(find.text('Punto P1 · Cancha central'), findsOneWidget);
      expect(find.text('Salón → P1 · Cancha central'), findsOneWidget);
      // ...y los demás, de los que definió el colegio. Sin un plano dibujado con
      // bloques inventados.
      expect(find.text('Placa alta'), findsOneWidget);
      expect(find.text('Bloque A'), findsNothing);
    });

    testWidgets('la guía trae los protocolos guardados y se abre por pestañas', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Guías'));
      await tester.pumpAndSettle();

      expect(find.text('Qué hacer si…'), findsOneWidget);
      expect(find.text('Sismos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('guia-sismo')));
      await tester.pumpAndSettle();
      // Abre en «Durante», lo que más se busca.
      expect(find.text('Cúbrete bajo el pupitre hasta que pare'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pestana-Antes')));
      await tester.pump();
      expect(find.text('Ubica la salida más cercana a tu salón'), findsOneWidget);
      expect(find.text('Cúbrete bajo el pupitre hasta que pare'), findsNothing);
    });

    testWidgets('reportar un riesgo: exige tipo y lugar, envía y muestra el estado', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Sin elegir qué se vio ni dónde, no se puede enviar.
      final Finder send = find.byKey(const Key('enviar-reporte'));
      await tester.tap(send);
      await tester.pump();
      expect(risks.reports, isEmpty);

      await tester.tap(find.byKey(const Key('riesgo-grieta')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('riesgo-lugar')), 'Bloque A, 2.° piso');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(risks.reports, hasLength(1));
      // Se abre «Reporte enviado» con su número y el seguimiento.
      expect(find.byKey(const Key('reporte-enviado')), findsOneWidget);
      expect(find.text('Reporte n.º 128'), findsOneWidget);
      expect(find.text('Grieta o daño'), findsOneWidget);
      expect(find.text('Bloque A, 2.° piso'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);

      // «Ver mis reportes» abre la lista con sus contadores.
      await tester.tap(find.byKey(const Key('ver-mis-reportes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reporte-enviado')), findsNothing);
      expect(find.text('Lo que has avisado al colegio'), findsOneWidget);
      expect(find.text('Grieta o daño · Bloque A, 2.° piso'), findsOneWidget);
      expect(find.text('Enviado'), findsWidgets);
    });

    testWidgets('«Mis reportes» cuenta enviados, en revisión y resueltos', (
      WidgetTester tester,
    ) async {
      RiskReport report(String id, RiskStatus status) => RiskReport(
            id: id,
            number: 100,
            kind: RiskKind.cable,
            place: 'Patio central',
            status: status,
            createdAt: DateTime.now(),
          );
      risks.reports.addAll(<RiskReport>[
        report('a', RiskStatus.nuevo),
        report('b', RiskStatus.enRevision),
        report('c', RiskStatus.atendido),
        report('d', RiskStatus.atendido),
      ]);
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('abrir-mis-reportes')));
      await tester.pumpAndSettle();

      Text countOf(String key) => tester.widget<Text>(
            find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first,
          );
      expect(countOf('cuenta-enviados').data, '4');
      expect(countOf('cuenta-revision').data, '1');
      expect(countOf('cuenta-resueltos').data, '2');
      expect(find.text('Tus reportes ayudaron a corregir 2 riesgos este año.'), findsOneWidget);

      // «Nuevo reporte» vuelve al formulario.
      await tester.tap(find.byKey(const Key('nuevo-reporte')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('enviar-reporte')), findsOneWidget);
    });

    testWidgets('«Mis reportes» sin reportes lo dice y no presume de nada', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('abrir-mis-reportes')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-reportes')), findsOneWidget);
      expect(find.byKey(const Key('riesgos-corregidos')), findsNothing);
    });

    testWidgets('si el reporte no llega, no dice «enviado»', (WidgetTester tester) async {
      await signIn(tester, 'IICB7K4P');
      risks.failNext = true;

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('riesgo-cable')));
      await tester.enterText(find.byKey(const Key('riesgo-lugar')), 'Laboratorio 2');
      await tester.pump();
      await tester.tap(find.byKey(const Key('enviar-reporte')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reporte-enviado')), findsNothing);
      expect(find.byKey(const Key('error-reporte')), findsOneWidget);
    });

    testWidgets('el perfil guarda los ajustes y permite cerrar sesión', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Laura Camila Pérez Gómez'), findsWidgets);
      expect(find.text('Aula 7 · Bloque A'), findsOneWidget);
      expect(find.text('1 contacto'), findsOneWidget);

      // Apagar la ubicación se guarda en el colegio.
      await tester.tap(find.byKey(const Key('ajuste-ubicacion')));
      await tester.pumpAndSettle();
      expect(account.settings.shareLocation, isFalse);

      // La información médica se anota y se puede borrar.
      await tester.tap(find.byKey(const Key('informacion-medica')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('texto-medico')), 'Asma');
      await tester.tap(find.byKey(const Key('guardar-medico')));
      await tester.pumpAndSettle();
      expect(account.medical, 'Asma');

      // Cerrar sesión va al final de la lista, lejos de lo que se toca a diario.
      await tester.scrollUntilVisible(
        find.byKey(const Key('cerrar-sesion')),
        300,
        scrollable: find.descendant(
          of: find.byType(AccountScreen),
          matching: find.byType(Scrollable),
        ),
      );
      // Estar construido no es estar a la vista: la lista construye un poco de lo
      // que queda fuera de pantalla.
      await tester.ensureVisible(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      // Cancelar deja todo como estaba.
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);

      // Confirmar borra la sesión y devuelve al registro: para volver a entrar
      // hace falta un código nuevo.
      await tester.tap(find.byKey(const Key('cerrar-sesion')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'CERRAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsNothing);
      expect(find.text('Saltar'), findsOneWidget);
    });

    testWidgets('«Cómo te avisamos» guarda la vibración y la letra en el celular', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await signIn(tester, 'IICB7K4P');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('como-te-avisamos')));
      await tester.tap(find.byKey(const Key('como-te-avisamos')));
      await tester.pumpAndSettle();
      expect(find.text('Sonar aunque esté en silencio'), findsOneWidget);

      await tester.tap(find.byKey(const Key('aviso-vibracion')));
      await tester.tap(find.byKey(const Key('letra-grande')));
      await tester.tap(find.byKey(const Key('guardar-avisos')));
      await tester.pumpAndSettle();

      final AlertPreferences saved = await AlertPreferencesStore.load();
      expect(saved.strongVibration, isTrue);
      expect(saved.textSize, AlertTextSize.large);
      // Guardar vuelve al perfil.
      expect(find.byKey(const Key('guardar-avisos')), findsNothing);
    });

    testWidgets('«Apoyo para evacuar» muestra los compañeros y guarda lo que se pide', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('apoyo-para-evacuar')));
      await tester.tap(find.byKey(const Key('apoyo-para-evacuar')));
      await tester.pumpAndSettle();

      // Sin pedir nada todavía: se ven los compañeros que asignó el colegio.
      expect(find.text('Mateo Pinzón'), findsOneWidget);
      expect(account.support, isNull);

      await tester.tap(find.byKey(const Key('apoyo-movilidad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apoyo-voz')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guardar-apoyo')));
      await tester.pumpAndSettle();

      expect(account.support?.need, SupportNeed.mobility);
      expect(account.support?.readAloud, isTrue);
      expect(account.support?.vibrate, isTrue);
    });

    testWidgets('«Ya no necesito apoyo» lo quita y deja a los compañeros', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');
      account.support = const SupportSettings(need: SupportNeed.temporary);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('apoyo-para-evacuar')));
      await tester.tap(find.byKey(const Key('apoyo-para-evacuar')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('quitar-apoyo')), 200);
      await tester.tap(find.byKey(const Key('quitar-apoyo')));
      await tester.pumpAndSettle();

      expect(account.support, isNull);
      expect(find.text('Mateo Pinzón'), findsOneWidget);
      expect(find.byKey(const Key('quitar-apoyo')), findsNothing);
    });

    testWidgets('los contactos de familia: se suma uno, se quita, y el del colegio no', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('contactos-de-familia')));
      await tester.pumpAndSettle();
      expect(find.text('Martha Gómez Rueda'), findsOneWidget);
      expect(find.text('Vinculado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('agregar-contacto')));
      await tester.pumpAndSettle();
      // Incompleto: lo dice y no cierra.
      await tester.tap(find.byKey(const Key('guardar-contacto')));
      await tester.pump();
      expect(find.textContaining('nombre de tu contacto'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('contacto-nombre')), 'Rosa Pérez');
      await tester.enterText(find.byKey(const Key('contacto-parentesco')), 'Tía');
      await tester.enterText(find.byKey(const Key('contacto-celular')), '3151234567');
      await tester.tap(find.byKey(const Key('guardar-contacto')));
      await tester.pumpAndSettle();

      expect(find.text('Rosa Pérez'), findsOneWidget);
      expect(find.text('Agregado'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Rosa Pérez'), findsNothing);
      // El acudiente del colegio no tiene botón de quitar.
      expect(find.byTooltip('Quitar'), findsNothing);
    });

    testWidgets('desde el inicio se llega al mapa y a la guía', (
      WidgetTester tester,
    ) async {
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Cancha central'));
      await tester.pumpAndSettle();
      expect(find.text('Mapa de evacuación'), findsOneWidget);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qué hacer si…'));
      await tester.pumpAndSettle();
      expect(find.text('Sismos'), findsOneWidget);
    });

    testWidgets('«alertas y avisos» junta lo que pasó y los reportes de la persona', (
      WidgetTester tester,
    ) async {
      account.feed = <FeedItem>[
        FeedItem(
          id: '1',
          kind: 'alerta',
          title: 'Alerta de sismo',
          at: DateTime.now().subtract(const Duration(days: 1)),
          myStatus: 'a_salvo',
          mySeconds: 190,
        ),
        FeedItem(
          id: '2',
          kind: 'reporte_riesgo',
          title: 'Bloque A',
          at: DateTime.now().subtract(const Duration(days: 2)),
          riskStatus: 'atendido',
        ),
      ];
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.byKey(const Key('alertas-y-avisos')));
      await tester.pumpAndSettle();

      expect(find.text('Alerta de sismo · finalizada'), findsOneWidget);
      expect(find.textContaining('Confirmaste a salvo en 3:10'), findsOneWidget);
      expect(find.text('Tu reporte fue atendido'), findsOneWidget);

      // El filtro «Mis reportes» deja solo lo suyo.
      await tester.tap(find.text('Mis reportes'));
      await tester.pump();
      expect(find.text('Alerta de sismo · finalizada'), findsNothing);
      expect(find.text('Tu reporte fue atendido'), findsOneWidget);
    });

    testWidgets('simulacros: próximo y último resultado con el tiempo de la persona', (
      WidgetTester tester,
    ) async {
      drills.upcoming.add(
        Drill(
          id: 'd1',
          hazard: Hazard.sismo,
          scheduledAt: DateTime.now().add(const Duration(days: 2)),
          scope: 'Todo el colegio',
        ),
      );
      drills.history.add(
        DrillResult(
          alertId: 'a1',
          hazard: Hazard.sismo,
          at: DateTime.now().subtract(const Duration(days: 30)),
          mySeconds: 190,
          onTime: true,
          schoolPercent: 94,
        ),
      );
      await signIn(tester, 'IICB7K4P');

      await tester.tap(find.text('Simulacros'));
      await tester.pumpAndSettle();

      expect(find.text('Próximo'), findsOneWidget);
      expect(find.text('Repasar mi ruta'), findsOneWidget);
      expect(find.byKey(const Key('mi-tiempo')), findsOneWidget);
      expect(find.text('3:10'), findsOneWidget);
      expect(find.textContaining('El 94 % del colegio'), findsOneWidget);
    });
  });
}
