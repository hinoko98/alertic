import 'package:alertic/app/app_scope.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:alertic/features/web_admin/presentation/web_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';

/// El panel del administrador en el navegador: entrada y menú.
void main() {
  late FakeAlertRepository alerts;

  setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
  tearDown(() => alerts.dispose());

  Future<void> pumpGate(WidgetTester tester, Size size) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        sessionStore: InMemorySessionStore(),
        notifications: SilentNotificationService(),
        deviceRegistrar: const NoDeviceRegistrar(),
        panelRepository: FakePanelRepository(alerts),
        child: MaterialApp(theme: AppTheme.build(), home: const WebGate()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Entrar al panel'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión muestra el ingreso, no el panel', (WidgetTester tester) async {
    await pumpGate(tester, const Size(1440, 900));

    expect(find.text('Panel del administrador'), findsOneWidget);
    expect(find.text('Entrar al panel'), findsOneWidget);
    expect(find.text('Resumen'), findsNothing);
  });

  testWidgets('un correo mal escrito se explica sin ir al servidor', (WidgetTester tester) async {
    await pumpGate(tester, const Size(1440, 900));

    await signIn(tester, 'coordinacion', 'Barbosa2026Riesgo');

    expect(find.textContaining('incompleto'), findsOneWidget);
    expect(find.text('Resumen'), findsNothing);
  });

  testWidgets('un docente no entra al panel de coordinación', (WidgetTester tester) async {
    await pumpGate(tester, const Size(1440, 900));

    await signIn(tester, 'nubia.silva@iic.edu.co', 'Matematicas2026');

    expect(find.textContaining('solo para la coordinación'), findsOneWidget);
    expect(find.text('Resumen'), findsNothing);
  });

  testWidgets('la coordinación entra y ve el menú lateral completo', (WidgetTester tester) async {
    await pumpGate(tester, const Size(1440, 900));

    await signIn(tester, 'coordinacion@iic.edu.co', 'Barbosa2026Riesgo');

    expect(find.text('Resumen'), findsWidgets);
    expect(find.text('Emitir alerta'), findsWidgets);
    expect(find.text('Usuarios y códigos'), findsOneWidget);
    expect(find.text('Gloria Amparo Rueda Sánchez'), findsOneWidget);
  });

  testWidgets('cada página del menú abre su pantalla', (WidgetTester tester) async {
    await pumpGate(tester, const Size(1440, 900));
    await signIn(tester, 'coordinacion@iic.edu.co', 'Barbosa2026Riesgo');

    await tester.tap(find.text('Informes'));
    await tester.pumpAndSettle();
    expect(find.text('Historial de alertas'), findsOneWidget);

    await tester.tap(find.text('Repetición de simulacros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no se guarda el movimiento'), findsOneWidget);
  });

  testWidgets('en pantalla angosta el menú pasa a un cajón', (WidgetTester tester) async {
    await pumpGate(tester, const Size(600, 900));
    await signIn(tester, 'coordinacion@iic.edu.co', 'Barbosa2026Riesgo');

    expect(find.text('Usuarios y códigos'), findsNothing);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();

    expect(find.text('Usuarios y códigos'), findsOneWidget);
  });
}
