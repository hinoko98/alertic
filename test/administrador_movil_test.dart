import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/risks/domain/risk_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_incident_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'support/fakes/fake_risk_repository.dart';
import 'support/fakes/fake_teacher_repository.dart';
import 'support/test_app.dart';

/// Pantallas 49 a 54: el administrador del colegio en el celular.
void main() {
  late FakeAlertRepository alerts;
  late FakePanelRepository panel;
  late FakeRiskRepository risks;
  late FakeIncidentRepository incidents;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    panel = FakePanelRepository(alerts, latency: Duration.zero);
    risks = FakeRiskRepository();
    incidents = FakeIncidentRepository(latency: Duration.zero);
  });
  tearDown(() => alerts.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        teacherRepository: FakeTeacherRepository(alerts, latency: Duration.zero),
        panelRepository: panel,
        riskRepository: risks,
        incidentRepository: incidents,
      ),
    );
  }

  /// Entra por la puerta del administrador: «¿Administras ALERTIC?».
  Future<void> signInAsAdmin(WidgetTester tester) async {
    await pumpApp(tester);
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

  group('49 · ingreso del administrador', () {
    testWidgets('tiene su propia puerta, con sus textos', (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Administras ALERTIC en tu colegio?'));
      await tester.pumpAndSettle();

      expect(find.text('Administrador del colegio'), findsOneWidget);
      expect(find.text('Ingreso fijo, sin código de un solo uso.'), findsOneWidget);
      expect(find.text('USUARIO INSTITUCIONAL'), findsOneWidget);
      expect(find.text('Entrar al panel'), findsOneWidget);
    });

    testWidgets('con su contraseña entra a la app del administrador', (WidgetTester tester) async {
      await signInAsAdmin(tester);

      expect(find.text('Administrador del colegio'), findsNothing);
      expect(find.text('Comunidad'), findsWidgets);
    });
  });

  group('50 · panel del colegio', () {
    testWidgets('en calma: emitir alerta, cifras, reportes y gestión', (WidgetTester tester) async {
      risks.reports.add(
        RiskReport(
          id: 'r1',
          kind: RiskKind.grieta,
          place: 'Bloque A, 2.º piso',
          status: RiskStatus.nuevo,
          createdAt: DateTime.now(),
          reporterRole: 'estudiante',
          reporterGrade: '9° B',
        ),
      );
      await signInAsAdmin(tester);

      expect(find.text('Panel del colegio'), findsOneWidget);
      expect(find.text('Emitir alerta'), findsOneWidget);
      expect(find.text('912'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('Reportes nuevos'), findsOneWidget);
      expect(find.text('Grieta o daño · Bloque A, 2.º piso'), findsOneWidget);
      expect(find.text('Estudiante 9° B · ahora'), findsOneWidget);
      for (final String tile in <String>['Generar códigos', 'Rutas y puntos', 'Simulacros', 'Informes']) {
        expect(find.text(tile), findsOneWidget, reason: 'falta $tile');
      }
    });

    testWidgets('sin reportes lo dice', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      expect(find.byKey(const Key('admin-sin-reportes')), findsOneWidget);
    });

    testWidgets('un reporte de emergencia sin atender lleva al tablero', (WidgetTester tester) async {
      await incidents.report(Hazard.incendio);
      await signInAsAdmin(tester);

      expect(find.text('1 reporte de emergencia sin atender'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-emergencias-abiertas')));
      await tester.pumpAndSettle();
      expect(find.text('REPORTES DE LA COMUNIDAD'), findsOneWidget);
    });

    testWidgets('con una alerta en curso, el botón cede su lugar al seguimiento', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-emitir-alerta')), findsNothing);
      expect(find.byKey(const Key('admin-alerta-en-curso')), findsOneWidget);
    });
  });

  group('51 · emitir alerta desde el panel', () {
    testWidgets('muestra el mensaje que llegará antes de enviarlo', (WidgetTester tester) async {
      await signInAsAdmin(tester);
      await tester.tap(find.byKey(const Key('admin-emitir-alerta')));
      await tester.pumpAndSettle();

      expect(find.text('Emitir alerta'), findsOneWidget);
      expect(find.byKey(const Key('vista-previa-alerta')), findsNothing);

      await tester.tap(find.text(Hazard.sismo.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AlertLevel.roja.label));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('vista-previa-alerta')), 200);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vista-previa-alerta')), findsOneWidget);
      expect(find.textContaining('Sale del protocolo publicado'), findsOneWidget);
    });
  });

  group('52 · seguimiento en vivo', () {
    Future<void> openTracking(WidgetTester tester) async {
      await signInAsAdmin(tester);
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-alerta-en-curso')));
      await tester.pumpAndSettle();
    }

    testWidgets('a salvo, sin confirmar, pedidos de ayuda y puntos', (WidgetTester tester) async {
      await openTracking(tester);

      expect(find.text('Seguimiento en vivo'), findsOneWidget);
      expect(find.text('858'), findsOneWidget);
      expect(find.text('de 960 · 89 %'), findsOneWidget);
      expect(find.text('Sin confirmar'), findsOneWidget);
      expect(find.text('Piden ayuda'), findsOneWidget);
      expect(find.byKey(const Key('seguimiento-ayuda')), findsOneWidget);
    });

    testWidgets('finalizar pide confirmación y vuelve al panel en calma', (WidgetTester tester) async {
      await openTracking(tester);

      await tester.tap(find.byKey(const Key('seguimiento-finalizar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Finalizar la alerta'), findsOneWidget);
      await tester.tap(find.text('SÍ, FINALIZAR'));
      await tester.pumpAndSettle();

      expect(find.text('Seguimiento en vivo'), findsNothing);
      expect(find.byKey(const Key('admin-emitir-alerta')), findsOneWidget);
    });

    testWidgets('«Tablero completo» cambia a la pestaña del tablero', (WidgetTester tester) async {
      await openTracking(tester);
      await tester.tap(find.byKey(const Key('seguimiento-tablero')));
      await tester.pumpAndSettle();

      expect(find.text('Seguimiento en vivo'), findsNothing);
      expect(find.text('POR GRADO'), findsOneWidget);
    });
  });

  group('53 · reportes de riesgo', () {
    RiskReport risk(String id, RiskStatus status, String place, {String? details}) => RiskReport(
          id: id,
          kind: RiskKind.grieta,
          place: place,
          status: status,
          createdAt: DateTime.now(),
          details: details,
          reporterName: 'Laura Pérez',
          reporterGrade: '9° B',
        );

    Future<void> openInbox(WidgetTester tester) async {
      await signInAsAdmin(tester);
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
    }

    testWidgets('abre en lo nuevo, con el detalle del primero y sus acciones', (WidgetTester tester) async {
      risks.reports.addAll(<RiskReport>[
        risk('r1', RiskStatus.nuevo, 'Bloque 1, 2.º piso', details: 'Grieta nueva junto a la escalera sur.'),
        risk('r2', RiskStatus.nuevo, 'Patio central'),
        risk('r3', RiskStatus.enRevision, 'Laboratorio 2'),
      ]);
      await openInbox(tester);

      expect(find.text('2 nuevos · 1 en revisión'), findsOneWidget);
      expect(find.byKey(const Key('riesgo-abierto-r1')), findsOneWidget);
      expect(find.textContaining('«Grieta nueva junto a la escalera sur.»'), findsOneWidget);
      expect(find.text('Asignar revisión'), findsOneWidget);
      // El de revisión no se ve hasta cambiar de filtro.
      expect(find.textContaining('Laboratorio 2'), findsNothing);

      await tester.tap(find.byKey(const Key('riesgo-r1-en_revision')));
      await tester.pumpAndSettle();
      expect(risks.reports.first.status, RiskStatus.enRevision);
      expect(find.text('1 nuevo · 2 en revisión'), findsOneWidget);
    });

    testWidgets('tocar una fila la abre, y los filtros cambian la lista', (WidgetTester tester) async {
      risks.reports.addAll(<RiskReport>[
        risk('r1', RiskStatus.nuevo, 'Bloque 1'),
        risk('r2', RiskStatus.nuevo, 'Patio central'),
        risk('r3', RiskStatus.atendido, 'Laboratorio 2'),
      ]);
      await openInbox(tester);

      await tester.tap(find.byKey(const Key('riesgo-fila-r2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('riesgo-abierto-r2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('riesgos-resueltos')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('riesgo-abierto-r3')), findsOneWidget);
      expect(find.text('Reabrir'), findsOneWidget);
    });
  });
}
