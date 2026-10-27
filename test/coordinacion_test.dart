import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/coordination/domain/coordination_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_coordination_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'support/fakes/fake_teacher_repository.dart';
import 'support/test_app.dart';

/// Coordinación conectada a la API: actualizaciones, brigadistas, listas
/// entregadas y lo que se deja preparado en la ficha de cada persona.
void main() {
  late FakeAlertRepository alerts;
  late FakeCoordinationRepository coordination;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    coordination = FakeCoordinationRepository();
  });
  tearDown(() => alerts.dispose());

  Future<void> signInAsAdmin(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        teacherRepository: FakeTeacherRepository(alerts, latency: Duration.zero),
        panelRepository: FakePanelRepository(alerts, latency: Duration.zero),
        coordinationRepository: coordination,
      ),
    );
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Administras ALERTIC en tu colegio?'));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, 'coordinacion@iic.edu.co');
    await tester.enterText(fields.last, 'Barbosa2026Riesgo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar al panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir y continuar'));
    await tester.pumpAndSettle();
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openTracking(WidgetTester tester) async {
    await signInAsAdmin(tester);
    alerts.simulate(AlertLevel.roja);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-alerta-en-curso')));
    await tester.pumpAndSettle();
  }

  group('durante la alerta', () {
    testWidgets('coordinación manda una actualización a todo el colegio', (WidgetTester tester) async {
      await openTracking(tester);

      await tester.tap(find.byKey(const Key('seguimiento-actualizacion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('actualizacion-texto')), 'El bloque B ya está despejado.');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('actualizacion-enviar')));
      await tester.pumpAndSettle();

      expect(coordination.notes, <String>['El bloque B ya está despejado.']);
      expect(find.text('Actualización enviada a todo el colegio.'), findsOneWidget);
    });

    testWidgets('manda a alguien por quien pidió ayuda y se ve quién va', (WidgetTester tester) async {
      await openTracking(tester);

      await tester.scrollUntilVisible(find.byKey(const Key('ayuda-asignar-1')), 200);
      await tester.tap(find.byKey(const Key('ayuda-asignar-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿A quién mandas por'), findsOneWidget);

      await tester.tap(find.byKey(const Key('responder-carlos')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ayuda-asignada-1')), findsOneWidget);
      expect(find.text('Va Carlos'), findsOneWidget);
      expect((await coordination.loadHelpAssignments('x')).single.assigneeId, 'carlos');
    });

    testWidgets('las listas que entregaron los docentes aparecen en el seguimiento', (WidgetTester tester) async {
      coordination.rosters.add(
        DeliveredRoster(
          grade: '10° B',
          teacher: 'Carlos Jaimes Duarte',
          safe: 30,
          needHelp: 1,
          pending: 1,
          submittedAt: DateTime(2026, 10, 26, 10, 50),
        ),
      );
      await openTracking(tester);

      await tester.scrollUntilVisible(find.byKey(const Key('seguimiento-listas')), 200);
      expect(find.text('10° B · Carlos Jaimes'), findsOneWidget);
      expect(find.text('30 a salvo · 1 con ayuda · 1 sin respuesta'), findsOneWidget);
    });

    testWidgets('el tablero también manda actualizaciones', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tablero'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENVIAR ACTUALIZACIÓN'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar actualización'), findsOneWidget);
    });
  });

  group('lo que se deja preparado', () {
    Future<void> openPerson(WidgetTester tester, String name) async {
      // Un celular: la comunidad se ve como tarjetas y la ficha como hoja.
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(400, 860);
      addTearDown(tester.view.reset);
      await signInAsAdmin(tester);
      await tester.tap(find.text('Comunidad'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, name.split(' ').first);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).first);
      await tester.pumpAndSettle();
    }

    testWidgets('a un docente se le escribe su tarea en una emergencia', (WidgetTester tester) async {
      await openPerson(tester, 'Carlos Jaimes Duarte');

      final Finder section = find.byKey(const Key('preparacion-docente'));
      await tester.scrollUntilVisible(section, 200, scrollable: find.byType(Scrollable).last);
      final Finder fields = find.descendant(of: section, matching: find.byType(TextField));
      await tester.enterText(fields.first, 'Guiar a 10° B al Punto A');
      await tester.enterText(fields.last, 'Por la escalera sur');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('GUARDAR TAREA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GUARDAR TAREA'));
      await tester.pumpAndSettle();

      expect(coordination.tasks.values.single.title, 'Guiar a 10° B al Punto A');
      expect(coordination.tasks.values.single.detail, 'Por la escalera sur');
      expect(find.textContaining('Tarea guardada'), findsOneWidget);
    });

    testWidgets('a un estudiante se le asigna un compañero de apoyo', (WidgetTester tester) async {
      await openPerson(tester, 'Laura Camila Pérez Gómez');

      final Finder add = find.text('AGREGAR COMPAÑERO');
      // La lista de la hoja (la ficha), no las de los selectores de grupo.
      final Finder sheetList = find
          .ancestor(of: find.text('DATOS'), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(add, 200, scrollable: sheetList);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final Finder option = find.byWidgetPredicate(
        (Widget w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('elegir-companero-'),
      );
      expect(option, findsWidgets);
      await tester.tap(option.first);
      await tester.pumpAndSettle();

      expect(coordination.buddies.values.single, hasLength(1));
    });
  });
}
