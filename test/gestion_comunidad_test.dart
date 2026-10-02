import 'package:alertic/app/app_scope.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:alertic/features/panel/presentation/screens/community_tab.dart';
import 'package:alertic/features/panel/presentation/screens/protocols_tab.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';

/// Coordinación carga y mantiene la comunidad desde el panel: dar de alta,
/// vincular, editar y eliminar, empezando desde un colegio vacío.
void main() {
  late FakeAlertRepository alerts;
  late FakePanelRepository panel;

  setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
  tearDown(() => alerts.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget tab, {
    bool empty = false,
    Size size = const Size(1280, 2000),
  }) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = size;
    addTearDown(tester.view.reset);

    panel = FakePanelRepository(alerts, empty: empty);

    await tester.pumpWidget(
      AppScope(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        sessionStore: InMemorySessionStore(),
        notifications: SilentNotificationService(),
        deviceRegistrar: const NoDeviceRegistrar(),
        panelRepository: panel,
        child: MaterialApp(theme: AppTheme.build(), home: Scaffold(body: tab)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  Finder chip(String label, {bool last = false}) {
    final Finder found = inSheet(find.widgetWithText(InkWell, label));
    return last ? found.last : found.first;
  }

  group('un colegio vacío', () {
    testWidgets('la comunidad dice por dónde empezar, no se ve rota', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab(), empty: true);

      expect(find.text('AÚN NO HAY NADIE'), findsOneWidget);
      expect(find.textContaining('dando de alta'), findsOneWidget);
      // Los tres caminos de alta están a la vista.
      expect(find.text('NUEVO ESTUDIANTE'), findsOneWidget);
      expect(find.text('NUEVO ACUDIENTE'), findsOneWidget);
      expect(find.text('NUEVO DOCENTE'), findsOneWidget);
      // Y ya no hay botones que prometen algo que no hacen.
      expect(find.textContaining('IMPORTAR'), findsNothing);
      expect(find.text('GENERAR CÓDIGOS'), findsNothing);
    });

    testWidgets('una búsqueda sin resultados no dice que la comunidad está vacía', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab());

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await flush(tester);

      expect(find.text('SIN RESULTADOS'), findsOneWidget);
      expect(find.text('AÚN NO HAY NADIE'), findsNothing);
    });

    testWidgets('el primer estudiante: se da de alta y recibe su código', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab(), empty: true);

      await tester.tap(find.text('NUEVO ESTUDIANTE'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana María Torres Ruiz',
      );
      // El colegio vacío no tiene grupos todavía: «+ OTRO» deja crear el primero.
      await tester.tap(chip('+ OTRO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9c');
      await tester.tap(find.text('AGREGAR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DAR DE ALTA'));
      await flush(tester);

      expect(find.text('CÓDIGO NUEVO'), findsOneWidget);
      expect(find.byKey(const Key('secreto-emitido')), findsOneWidget);

      await tester.tap(find.text('LISTO'));
      await flush(tester);

      expect(find.text('AÚN NO HAY NADIE'), findsNothing);
      expect(find.text('Ana María Torres Ruiz'), findsOneWidget);
      // El grupo salió normalizado: «9c» se guarda como «9° C».
      expect(find.text('9° C'), findsWidgets);
    });

    testWidgets('no se da de alta a nadie sin nombre completo ni grupo', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab(), empty: true);
      await tester.tap(find.text('NUEVO ESTUDIANTE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DAR DE ALTA'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre y al menos un apellido.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana María Torres',
      );
      await tester.tap(find.text('DAR DE ALTA'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el grupo del estudiante.'), findsOneWidget);
    });
  });

  group('acudientes y sus hijos', () {
    testWidgets('se da de alta un acudiente buscando a su hijo en la matrícula', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab());

      await tester.tap(find.text('NUEVO ACUDIENTE'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Rosa Elena Pinto Díaz',
      );

      // El estudiante se BUSCA, no se escribe: un nombre mal tecleado enlazaría a
      // la familia con el menor equivocado.
      await tester.tap(find.text('+ AGREGAR ESTUDIANTE'));
      await tester.pumpAndSettle();
      expect(find.text('Buscar estudiante'), findsOneWidget);
      await tester.tap(find.text('Sofía Arenas Villamizar').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('MADRE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DAR DE ALTA'));
      await flush(tester);
      await tester.tap(find.text('LISTO'));
      await flush(tester);

      // Aparece en la lista, y en la fila de su hija como su acudiente.
      expect(find.text('Rosa Elena Pinto Díaz'), findsNWidgets(2));
      expect(find.textContaining('Sofía'), findsWidgets);
    });

    testWidgets('el buscador no ofrece a un estudiante que ya está vinculado', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab());

      await tester.tap(find.text('Martha Gómez Ardila'));
      await tester.pumpAndSettle();
      // Martha ya tiene a Laura y a Andrés.
      await tester.tap(find.text('+ AGREGAR ESTUDIANTE'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Laura Camila Pérez Gómez'),
        ),
        findsNothing,
        reason: 'ya está a cargo de esta acudiente',
      );
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Sofía Arenas Villamizar'),
        ),
        findsOneWidget,
      );
    });
  });

  group('eliminar', () {
    testWidgets('se elimina a un estudiante, tras confirmar', (WidgetTester tester) async {
      await pump(tester, const CommunityTab());

      await tester.tap(find.text('Sofía Arenas Villamizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ELIMINAR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      expect(find.textContaining('respuestas a alertas pasadas'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'ELIMINAR'));
      await flush(tester);

      // La hoja se cerró y la persona ya no está.
      expect(find.text('GUARDAR CAMBIOS'), findsNothing);
      expect(find.text('Sofía Arenas Villamizar'), findsNothing);
    });

    testWidgets('cancelar no elimina a nadie', (WidgetTester tester) async {
      await pump(tester, const CommunityTab());

      await tester.tap(find.text('Sofía Arenas Villamizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ELIMINAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
    });

    testWidgets('un docente con historial no se elimina: el motivo se dice en la hoja', (
      WidgetTester tester,
    ) async {
      await pump(tester, const CommunityTab());

      await tester.tap(find.text('Carlos Jaimes Duarte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ELIMINAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ELIMINAR'));
      await flush(tester);

      expect(find.textContaining('Dale de baja en vez de eliminarlo'), findsOneWidget);
      // Sigue ahí.
      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
    });
  });

  group('protocolos y puntos de encuentro', () {
    testWidgets('se edita un protocolo y lo guardado es lo que se ve', (
      WidgetTester tester,
    ) async {
      await pump(tester, const ProtocolsTab());

      await tester.tap(find.text('EDITAR').first);
      await tester.pumpAndSettle();
      expect(find.text('GUARDAR PROTOCOLO'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Paso 1').at(1),
        'Cúbrete y sujétate de la mesa',
      );
      await tester.tap(find.text('GUARDAR PROTOCOLO'));
      await flush(tester);

      expect(find.text('GUARDAR PROTOCOLO'), findsNothing);
      // Fuera del reloj falso: el `Future.delayed` del doble solo avanza al bombear.
      final List<Protocol> saved = (await tester.runAsync(() => alerts.loadProtocols()))!;
      expect(
        saved.expand((Protocol p) => p.duringSteps),
        contains('Cúbrete y sujétate de la mesa'),
      );
    });

    testWidgets('un protocolo sin pasos en «Durante» no se guarda', (
      WidgetTester tester,
    ) async {
      await pump(tester, const ProtocolsTab());

      await tester.tap(find.text('EDITAR').first);
      await tester.pumpAndSettle();
      // Se vacían los pasos de «Durante».
      // Sismo tiene tres pasos en «Durante»: el 1 y el 2 se repiten en «Antes» y
      // «Después», el 3 es solo de «Durante».
      await tester.enterText(find.widgetWithText(TextField, 'Paso 1').at(1), '');
      await tester.enterText(find.widgetWithText(TextField, 'Paso 2').at(1), '');
      await tester.enterText(find.widgetWithText(TextField, 'Paso 3'), '');
      await tester.tap(find.text('GUARDAR PROTOCOLO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('al menos un paso en «Durante»'), findsOneWidget);
    });

    testWidgets('se crea un punto de encuentro y aparece en la lista con su código', (
      WidgetTester tester,
    ) async {
      await pump(tester, const ProtocolsTab());

      await tester.tap(find.text('+ NUEVO PUNTO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Zona alta');
      await tester.enterText(
        find.widgetWithText(TextField, 'Cómo llegar'),
        'Subiendo por la escalera norte',
      );
      await tester.tap(chip('INUNDACIÓN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREAR PUNTO'));
      await flush(tester);

      expect(find.text('P2'), findsOneWidget);
      expect(find.text('Zona alta'), findsOneWidget);
      expect(find.textContaining('Solo inundación'), findsOneWidget);
    });

    testWidgets('el único punto general no se puede quitar, y el motivo se dice', (
      WidgetTester tester,
    ) async {
      await pump(tester, const ProtocolsTab());

      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QUITAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'QUITAR'));
      await flush(tester);

      expect(find.textContaining('al menos un punto de encuentro general'), findsOneWidget);
    });

    testWidgets('la distancia que no es un número se rechaza, no se guarda como cero', (
      WidgetTester tester,
    ) async {
      await pump(tester, const ProtocolsTab());

      await tester.tap(find.text('+ NUEVO PUNTO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Cancha');
      await tester.enterText(find.widgetWithText(TextField, 'Cómo llegar'), 'Por el corredor');
      await tester.enterText(
        find.widgetWithText(TextField, 'Distancia en metros (opcional)'),
        'cerca',
      );
      await tester.tap(find.text('CREAR PUNTO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('son números'), findsOneWidget);
    });
  });
}
