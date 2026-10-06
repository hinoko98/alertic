import 'package:alertic/core/network/api_client.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'support/fakes/fake_incident_repository.dart';
import 'package:alertic/features/incidents/domain/incident.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'support/fakes/fake_teacher_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Los reportes de emergencia: del estudiante que ve humo, al docente y a
/// coordinación que tienen que enterarse.
///
/// Antes de esto el botón «REPORTAR EMERGENCIA» mostraba «enviado a tu docente»
/// sin mandar nada: un estudiante que reportara un incendio creería haber
/// avisado y nadie se enteraría. Estas pruebas existen para que no vuelva a
/// pasar.
void main() {
  late FakeAlertRepository alerts;
  late FakeIncidentRepository incidents;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    incidents = FakeIncidentRepository(latency: Duration.zero);
  });

  tearDown(() {
    alerts.dispose();
    incidents.dispose();
  });

  /// Pantalla del tamaño de un celular.
  void usePhone(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    IncidentRepository? override,
    bool phone = true,
  }) async {
    // Las pantallas del registro del estudiante se dibujan en el tamaño estándar
    // de las pruebas: con el tipo de letra de prueba (`Ahem`, más ancho que el
    // real) «Así funciona» se desborda a 400 puntos, y no es un fallo del
    // dispositivo. Docente y coordinación sí se prueban en tamaño de celular.
    if (phone) usePhone(tester);
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        teacherRepository: FakeTeacherRepository(alerts, latency: Duration.zero),
        panelRepository: FakePanelRepository(alerts),
        incidentRepository: override ?? incidents,
        // El mismo objeto avisa en vivo cuando se reporta: así el recorrido
        // estudiante → docente se ve moverse sin servidor.
        liveUpdates: incidents,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signInAsStudent(WidgetTester tester, {IncidentRepository? override}) async {
    await pumpApp(tester, override: override, phone: false);
    await tester.tap(find.text('Empezar'));
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
    await tester.tap(find.text('Permitir y continuar'));
    await tester.pumpAndSettle();
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> signInWithPassword(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, email);
    await tester.enterText(fields.last, password);
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

  Future<void> signInAsTeacher(WidgetTester tester) => signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );

  Future<void> signInAsAdmin(WidgetTester tester) => signInWithPassword(
        tester,
        'coordinacion@iic.edu.co',
        'Barbosa2026Riesgo',
      );

  group('el estudiante reporta', () {
    testWidgets('el reporte llega de verdad al repositorio', (
      WidgetTester tester,
    ) async {
      await signInAsStudent(tester);

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reportar-emergencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INCENDIOS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reporte de incendio enviado'), findsOneWidget);

      // Y lo importante: **salió**. Antes el mensaje aparecía igual sin que
      // existiera nada a donde mandarlo.
      final List<Incident> open = await incidents.loadOpen();
      expect(open, hasLength(1));
      expect(open.single.hazard, Hazard.incendio);
    });

    testWidgets('si no llegó, NO dice «enviado»', (WidgetTester tester) async {
      await signInAsStudent(tester, override: _BrokenIncidents());

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reportar-emergencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SISMOS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('enviado'), findsNothing);
      expect(
        find.textContaining('Avisa a tu docente en persona'),
        findsOneWidget,
        reason: 'si no se pudo, hay que decirle qué hacer: avisar en persona',
      );
    });

    testWidgets('si el servidor responde con un motivo, se muestra ese', (
      WidgetTester tester,
    ) async {
      await signInAsStudent(
        tester,
        override: _BrokenIncidents(
          const ApiException(
            'Ya enviaste varios reportes y coordinación los está viendo.',
            statusCode: 429,
          ),
        ),
      );

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reportar-emergencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LLUVIAS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya enviaste varios reportes'), findsOneWidget);
    });
  });

  group('el docente los recibe', () {
    testWidgets('el contador es el real, no «1» escrito a mano', (
      WidgetTester tester,
    ) async {
      await signInAsTeacher(tester);

      // Sin reportes: el botón no inventa un número.
      expect(find.text('REPORTES'), findsOneWidget);
      expect(find.textContaining('REPORTES ·'), findsNothing);
    });

    testWidgets('un reporte nuevo actualiza el contador en vivo', (
      WidgetTester tester,
    ) async {
      await signInAsTeacher(tester);
      expect(find.text('REPORTES'), findsOneWidget);

      // Un estudiante reporta mientras el docente tiene la pantalla abierta.
      await incidents.report(Hazard.incendio);
      await tester.pumpAndSettle();

      expect(find.text('REPORTES · 1'), findsOneWidget);
    });

    testWidgets('la bandeja dice quién reportó y qué, y se puede atender', (
      WidgetTester tester,
    ) async {
      await incidents.report(Hazard.sismo);
      await signInAsTeacher(tester);

      await tester.tap(find.text('REPORTES · 1'));
      await tester.pumpAndSettle();

      expect(find.text('SISMO'), findsOneWidget);
      expect(find.textContaining('Laura Camila Pérez Gómez'), findsOneWidget);
      expect(find.text('YA LO ATENDÍ'), findsOneWidget);

      await tester.tap(find.text('YA LO ATENDÍ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nadie ha reportado nada'), findsOneWidget);
      expect(await incidents.loadOpen(), isEmpty);
    });

    testWidgets('desde un reporte se puede emitir la alerta', (
      WidgetTester tester,
    ) async {
      await incidents.report(Hazard.incendio);
      await signInAsTeacher(tester);

      await tester.tap(find.text('REPORTES · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMITIR ALERTA'));
      await tester.pumpAndSettle();

      expect(find.text('NUEVA ALERTA'), findsOneWidget);
    });
  });

  group('coordinación los ve en el tablero', () {
    testWidgets('en calma, los reportes y el botón de emitir están a la vista', (
      WidgetTester tester,
    ) async {
      await incidents.report(Hazard.incendio);
      await signInAsAdmin(tester);

      expect(find.text('REPORTES DE LA COMUNIDAD'), findsOneWidget);
      expect(find.text('INCENDIO'), findsOneWidget);
      // Uno para emitir una alerta cualquiera y otro por el reporte.
      expect(find.text('EMITIR ALERTA'), findsNWidgets(2));
      // Una sola bandeja, no dos.
      expect(find.text('YA LO ATENDÍ'), findsOneWidget);
    });

    testWidgets('sin reportes lo dice, no deja un hueco', (
      WidgetTester tester,
    ) async {
      await signInAsAdmin(tester);
      expect(find.textContaining('Nadie ha reportado nada'), findsOneWidget);
    });
  });

  group('finalizar una alerta pide confirmación', () {
    // Lo hace coordinación desde el panel. Al docente, mientras hay una alerta
    // activa, esta le toma la pantalla hasta que responde «estoy a salvo»: ese
    // es otro camino, ya cubierto por las pruebas del estudiante.

    testWidgets('un toque no la termina', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      // Emitirla exige sostener el botón. Terminarla es igual de grave: le dice
      // a todos «ya pasó» en mitad de una evacuación.
      await tester.tap(find.text('FINALIZAR ALERTA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('¿Finalizar la alerta'), findsOneWidget);
      expect(find.textContaining('Confirma solo si ya revisaste'), findsOneWidget);

      await tester.tap(find.text('SEGUIR EN ALERTA'));
      await tester.pumpAndSettle();

      expect(
        find.text('FINALIZAR ALERTA'),
        findsOneWidget,
        reason: 'la alerta debe seguir activa si se cancela',
      );
    });

    testWidgets('confirmando sí se termina', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      await tester.tap(find.text('FINALIZAR ALERTA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SÍ, FINALIZAR'));
      await tester.pumpAndSettle();

      // Vuelve el estado en calma del tablero.
      expect(find.text('SIN ALERTAS'), findsOneWidget);
      expect(find.text('FINALIZAR ALERTA'), findsNothing);
    });
  });
}

/// Un repositorio de reportes que no logra enviar: simula el servidor caído, o
/// uno que rechaza con un motivo.
class _BrokenIncidents implements IncidentRepository {
  _BrokenIncidents([this.error = const ApiException('Sin conexión.')]);

  final ApiException error;

  @override
  Future<void> report(Hazard hazard, {String? details}) async => throw error;

  @override
  Future<List<Incident>> loadOpen() async => const <Incident>[];

  @override
  Future<void> handle(String incidentId, IncidentStatus status) async =>
      throw error;
}
