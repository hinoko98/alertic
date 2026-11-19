import 'package:alertic/app/app_scope.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/hazards/presentation/hazard_review_screen.dart';
import 'package:alertic/features/panel/domain/community_admin.dart';
import 'package:alertic/features/panel/domain/hazard_watch.dart';
import 'package:alertic/features/panel/domain/panel_repository.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:alertic/features/web_admin/presentation/web_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';

/// Avisos de amenazas: las fuentes sugieren, una persona decide, y lo que
/// escribe una persona necesita la aprobación de otra.
void main() {
  late FakeAlertRepository alerts;
  late FakePanelRepository panel;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    panel = FakePanelRepository(alerts, latency: Duration.zero);
  });
  tearDown(() => alerts.dispose());

  Widget scope(Widget child) => AppScope(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        sessionStore: InMemorySessionStore(),
        notifications: SilentNotificationService(),
        deviceRegistrar: const NoDeviceRegistrar(),
        panelRepository: panel,
        child: MaterialApp(theme: AppTheme.build(), home: child),
      );

  group('el repositorio de prueba respeta la segunda llave', () {
    test('quien escribe el aviso no puede aprobarlo; otra persona sí', () async {
      final HazardSignal created = await panel.reportHazard(
        const ManualHazardReport(hazard: Hazard.incendio, detail: 'Humo en el laboratorio 2'),
      );
      expect(created.awaitingApproval, isTrue);
      expect(created.canEmit, isFalse);

      await expectLater(panel.approveSignal(created.id), throwsA(isA<PanelActionFailure>()));

      panel.currentPersonId = 'docente-nubia';
      final HazardSignal approved = await panel.approveSignal(created.id);
      expect(approved.canEmit, isTrue);
    });
  });

  testWidgets('en la web, un incendio reportado no se puede emitir hasta que otra persona lo apruebe',
      (WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(scope(const WebGate()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'coordinacion@iic.edu.co');
    await tester.enterText(find.byType(TextField).at(1), 'Barbosa2026Riesgo');
    await tester.tap(find.text('Entrar al panel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alertas automáticas').first);
    await tester.pumpAndSettle();

    // Los avisos automáticos se ven con su sugerencia y el estado de las fuentes.
    expect(find.text('Sismo M4.2 a 86 km'), findsOneWidget);
    expect(find.text('Sugiere precaución'), findsWidgets);
    expect(find.text('No responde'), findsOneWidget);

    // Reportar un incendio.
    await tester.tap(find.text('Reportar incendio u otra emergencia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Humo saliendo del laboratorio 2');
    await tester.tap(find.text('ENVIAR PARA APROBACIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Posible incendio reportado'), findsOneWidget);
    expect(find.textContaining('Necesita la aprobación de otra persona'), findsOneWidget);

    // Quien lo escribió intenta aprobarlo: el sistema lo impide.
    await tester.tap(find.text('Aprobar: lo confirmo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No puedes aprobar tu propio aviso'), findsOneWidget);

    // Otra persona lo aprueba.
    panel.currentPersonId = 'docente-nubia';
    await tester.tap(find.text('Aprobar: lo confirmo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lo aprobó'), findsOneWidget);
  });

  testWidgets('en el celular, la revisión muestra los avisos y deja aprobar y descartar',
      (WidgetTester tester) async {
    // Fuera del reloj simulado de la prueba: el doble espera con Future.delayed.
    await tester.runAsync(
      () => panel.reportHazard(
        const ManualHazardReport(hazard: Hazard.incendio, detail: 'Humo detrás del bloque B'),
      ),
    );
    panel.currentPersonId = 'docente-nubia';

    await tester.pumpWidget(scope(const HazardReviewScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Posible incendio reportado'), findsOneWidget);
    expect(find.textContaining('Necesita que otra persona lo apruebe'), findsOneWidget);

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aprobado por'), findsOneWidget);

    await tester.tap(find.text('Descartar').first);
    await tester.pumpAndSettle();
    expect(find.text('Aviso descartado'), findsOneWidget);
  });

  testWidgets('la franja de avisos aparece cuando hay algo por decidir', (WidgetTester tester) async {
    await tester.pumpWidget(scope(const Scaffold(body: HazardReviewBanner())));
    await tester.pumpAndSettle();

    expect(find.textContaining('avisos de amenaza por revisar'), findsOneWidget);
  });
}
