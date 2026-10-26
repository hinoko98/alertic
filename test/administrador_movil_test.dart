import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'support/fakes/fake_teacher_repository.dart';
import 'support/test_app.dart';

/// Pantallas 49 a 54: el administrador del colegio en el celular.
void main() {
  late FakeAlertRepository alerts;
  late FakePanelRepository panel;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    panel = FakePanelRepository(alerts, latency: Duration.zero);
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
}
