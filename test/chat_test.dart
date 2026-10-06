import 'package:alertic/features/assistant/domain/risk_assistant.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_support_repository.dart';
import 'support/test_app.dart';

/// El chat con el soporte del colegio y el asistente de riesgos.
void main() {
  late FakeAlertRepository alerts;
  late FakeSupportRepository support;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    support = FakeSupportRepository();
  });

  tearDown(() {
    alerts.dispose();
    support.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        supportRepository: support,
        liveUpdates: support,
      ),
    );
  }

  Future<void> signInWithCode(WidgetTester tester, String code) async {
    await pumpApp(tester);
    await tester.tap(find.text('Empezar'));
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
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> signInTeacher(WidgetTester tester) async {
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
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openChat(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('abrir-chat')));
    await tester.pumpAndSettle();
  }

  Future<void> writeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('escribir-mensaje')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('enviar-mensaje')));
    await tester.pumpAndSettle();
  }

  group('estudiante', () {
    testWidgets('abre el chat desde la cabecera y ve que está vacío', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openChat(tester);

      expect(find.text('Soporte del colegio'), findsOneWidget);
      expect(find.text('Escríbele al colegio'), findsOneWidget);
      expect(find.textContaining('Línea 123'), findsOneWidget);
    });

    testWidgets('escribe y su mensaje queda en la conversación', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openChat(tester);

      await writeAndSend(tester, '  ¿A qué hora es el simulacro?  ');

      expect(find.text('¿A qué hora es el simulacro?'), findsOneWidget);
      expect(support.sent, 1);
      // La caja se vació: lo escrito ya salió.
      final TextField box = tester.widget(find.byKey(const Key('escribir-mensaje')));
      expect(box.controller!.text, isEmpty);
    });

    testWidgets('un mensaje vacío no se envía', (WidgetTester tester) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openChat(tester);

      await tester.enterText(find.byKey(const Key('escribir-mensaje')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('enviar-mensaje')));
      await tester.pumpAndSettle();

      expect(support.sent, 0);
    });

    testWidgets('si no llega, lo escrito se queda y dice por qué', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openChat(tester);

      support.failNextSend = true;
      await writeAndSend(tester, 'Necesito hablar con coordinación');

      expect(find.byKey(const Key('error-envio')), findsOneWidget);
      final TextField box = tester.widget(find.byKey(const Key('escribir-mensaje')));
      expect(box.controller!.text, 'Necesito hablar con coordinación');
      expect(find.text('Necesito hablar con coordinación'), findsOneWidget);

      // Reintenta y esta vez sí sale.
      await tester.tap(find.byKey(const Key('enviar-mensaje')));
      await tester.pumpAndSettle();
      expect(support.sent, 1);
    });

    testWidgets('la respuesta del colegio aparece sola y la insignia la cuenta', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB7K4P');

      // En el inicio, sin abrir el chat: llega una respuesta.
      support.staffSays('Es el jueves a las 10.');
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets); // la insignia de la cabecera

      await openChat(tester);
      expect(find.text('Es el jueves a las 10.'), findsOneWidget);
      expect(find.text('Carlos Jaimes'), findsOneWidget);

      // Con el chat abierto, otra respuesta entra en vivo.
      support.staffSays('Trae tu carné.');
      await tester.pumpAndSettle();
      expect(find.text('Trae tu carné.'), findsOneWidget);
    });

    testWidgets('al volver del chat, la insignia ya no cuenta lo leído', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB7K4P');
      support.staffSays('Hola');
      await tester.pumpAndSettle();

      await openChat(tester);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('sin leer')),
        findsNothing,
        reason: 'ya leyó el mensaje',
      );
    });
  });

  group('docente', () {
    testWidgets('ve las conversaciones y responde', (WidgetTester tester) async {
      support.personSays('¿Puedo salir antes el viernes?');

      await signInTeacher(tester);
      await tester.tap(find.text('Mensajes'));
      await tester.pumpAndSettle();

      expect(find.text('Laura Camila Pérez Gómez'), findsOneWidget);
      expect(find.textContaining('salir antes'), findsOneWidget);

      await tester.tap(find.text('Laura Camila Pérez Gómez'));
      await tester.pumpAndSettle();

      expect(find.text('¿Puedo salir antes el viernes?'), findsOneWidget);
      await writeAndSend(tester, 'Sí, con permiso de tu acudiente.');
      expect(find.text('Sí, con permiso de tu acudiente.'), findsOneWidget);
    });

    testWidgets('sin conversaciones lo dice, no deja la lista vacía', (
      WidgetTester tester,
    ) async {
      await signInTeacher(tester);
      await tester.tap(find.text('Mensajes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Todavía no hay mensajes'), findsOneWidget);
    });
  });

  group('asistente de riesgos', () {
    Future<void> openAssistant(WidgetTester tester) async {
      await tester.tap(find.text('Ayuda'));
      await tester.pumpAndSettle();
    }

    testWidgets('responde con el protocolo del colegio', (WidgetTester tester) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openAssistant(tester);

      expect(find.text('Asistente de riesgos'), findsOneWidget);
      expect(find.textContaining('¿Emergencia real?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Sismo'));
      await tester.pumpAndSettle();

      // Los pasos «durante» del protocolo de sismo, numerados.
      expect(find.textContaining('1. '), findsOneWidget);
      expect(find.textContaining('Cuando estés a salvo'), findsOneWidget);
    });

    testWidgets('entiende una pregunta escrita', (WidgetTester tester) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openAssistant(tester);

      await tester.enterText(
        find.byKey(const Key('pregunta-asistente')),
        '¿Qué hago si tiembla en clase?',
      );
      await tester.tap(find.byKey(const Key('enviar-pregunta')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cuando estés a salvo'), findsOneWidget);
    });

    testWidgets('«hablar con una persona» abre el chat', (WidgetTester tester) async {
      await signInWithCode(tester, 'IICB7K4P');
      await openAssistant(tester);

      final Finder person = find.widgetWithText(ActionChip, 'Hablar con una persona');
      await tester.ensureVisible(person);
      await tester.pumpAndSettle();
      await tester.tap(person);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Soporte del colegio'), findsOneWidget);
    });
  });

  group('lógica del asistente', () {
    const Protocol sismo = Protocol(
      hazard: Hazard.sismo,
      beforeSteps: <String>['Identifica zonas seguras'],
      duringSteps: <String>['Agáchate', 'Cúbrete', 'Sujétate'],
      afterSteps: <String>['Evacúa'],
    );
    const RiskAssistant assistant = RiskAssistant(<Protocol>[sismo]);

    test('un temblor es un sismo', () {
      expect(assistant.answer('está temblando').text, contains('1. Agáchate'));
      expect(assistant.answer('SISMO').text, contains('3. Sujétate'));
    });

    test('«serio» no se confunde con el río', () {
      final AssistantReply reply = assistant.answer('esto es muy serio');
      expect(reply.text, contains('No estoy seguro'));
    });

    test('sin protocolo publicado lo dice y manda a una persona', () {
      final AssistantReply reply = assistant.answer('hay un incendio');
      expect(reply.text, contains('todavía no publicó'));
      expect(reply.action, AssistantAction.talkToSomeone);
    });

    test('reportar y hablar con alguien llevan a su pantalla', () {
      expect(assistant.answer('quiero reportar una grieta').action, AssistantAction.reportRisk);
      expect(assistant.answer('hablar con coordinación').action, AssistantAction.talkToSomeone);
    });
  });
}
