import 'package:alertic/app/app_scope.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';
import 'package:alertic/features/panel/presentation/panel_layout.dart';
import 'package:alertic/features/panel/presentation/screens/community_tab.dart';
import 'package:alertic/features/panel/presentation/screens/history_tab.dart';
import 'package:alertic/features/panel/presentation/screens/protocols_tab.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las mismas cuatro pantallas en dos anchos muy distintos.
///
/// El panel vive en el computador de coordinación **y** en el celular del
/// administrador. No están duplicadas: se adaptan. Esta prueba existe para que
/// arreglar una de las dos formas no rompa la otra en silencio, que es
/// exactamente lo que pasaría sin ella.
void main() {
  late FakeAlertRepository alerts;

  setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
  tearDown(() => alerts.dispose());

  /// Dibuja una pestaña del panel al ancho que se le pida.
  Future<void> pumpTab(WidgetTester tester, Widget tab, Size size) async {
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
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(body: tab),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// El computador de coordinación.
  const Size desktop = Size(1280, 800);

  /// Un celular corriente.
  const Size phone = Size(400, 860);

  group('el punto de corte', () {
    testWidgets('un celular es compacto y un computador no', (
      WidgetTester tester,
    ) async {
      late bool compactOnPhone;
      late bool compactOnDesktop;

      await pumpTab(
        tester,
        Builder(
          builder: (BuildContext context) {
            compactOnPhone = PanelLayout.isCompact(context);
            return const SizedBox.shrink();
          },
        ),
        phone,
      );
      await pumpTab(
        tester,
        Builder(
          builder: (BuildContext context) {
            compactOnDesktop = PanelLayout.isCompact(context);
            return const SizedBox.shrink();
          },
        ),
        desktop,
      );

      expect(compactOnPhone, isTrue);
      expect(compactOnDesktop, isFalse);
    });
  });

  group('comunidad', () {
    testWidgets('en el computador se ve la tabla completa', (
      WidgetTester tester,
    ) async {
      await pumpTab(tester, const CommunityTab(), desktop);

      // Las seis columnas de la cabecera: es lo que justifica una tabla.
      for (final String column in <String>[
        'NOMBRE',
        'ROL',
        'GRADO',
        'VINCULADO CON',
        'CÓDIGO',
        'ESTADO',
      ]) {
        expect(find.text(column), findsOneWidget, reason: 'falta $column');
      }
    });

    testWidgets('en el celular no hay tabla, hay tarjetas', (
      WidgetTester tester,
    ) async {
      await pumpTab(tester, const CommunityTab(), phone);

      expect(find.text('VINCULADO CON'), findsNothing);
      expect(find.text('COMUNIDAD'), findsOneWidget);
      // El buscador sigue estando, en su propia línea.
      expect(find.text('Buscar por nombre o documento'), findsOneWidget);
    });
  });

  group('las cuatro pestañas caben en los dos anchos', () {
    for (final (String name, Widget Function() build) tab
        in <(String, Widget Function())>[
      ('comunidad', CommunityTab.new),
      ('historial', HistoryTab.new),
      ('protocolos', ProtocolsTab.new),
    ]) {
      for (final (String where, Size size) screen in <(String, Size)>[
        ('el computador', desktop),
        ('el celular', phone),
      ]) {
        testWidgets('${tab.$1} en ${screen.$1} no se desborda', (
          WidgetTester tester,
        ) async {
          await pumpTab(tester, tab.$2(), screen.$2);

          // Un desbordamiento en Flutter se reporta como excepción de la capa
          // de dibujo. Si hubo una, esta prueba la recoge; es la forma de que
          // una franja amarilla y negra no llegue al computador del colegio.
          expect(
            tester.takeException(),
            isNull,
            reason: '${tab.$1} se desborda en ${screen.$1}',
          );
        });
      }
    }
  });
}
