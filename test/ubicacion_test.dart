import 'package:alertic/core/location/geo.dart';
import 'package:alertic/core/location/location_service.dart';
import 'package:alertic/core/location/location_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_location_service.dart';
import 'support/test_app.dart';

/// El mapa y la ruta en vivo: dónde está la persona, hacia dónde va y cuánto le
/// falta, con un GPS de mentira que se mueve a mano.
void main() {
  // El punto P1 de las pruebas (la cancha).
  const GeoPoint cancha = GeoPoint(5.93345, -73.62135);

  /// Un punto a [meters] al sur de la cancha (un grado de latitud son ~111 km).
  GeoPoint southOf(double meters) => GeoPoint(cancha.latitude - meters / 111000, cancha.longitude);

  group('la geografía', () {
    test('la distancia entre dos puntos sale en metros', () {
      final double meters = Geo.distance(cancha, southOf(100));
      expect(meters, closeTo(100, 1));
      expect(Geo.distance(cancha, cancha), 0);
    });

    test('el rumbo: norte 0°, este 90°, sur 180°', () {
      expect(Geo.bearing(cancha, GeoPoint(cancha.latitude + 0.001, cancha.longitude)), closeTo(0, 0.5));
      expect(Geo.bearing(cancha, GeoPoint(cancha.latitude, cancha.longitude + 0.001)), closeTo(90, 0.5));
      expect(Geo.bearing(cancha, southOf(50)), closeTo(180, 0.5));
    });

    test('lo que hay que girar para mirar al destino', () {
      expect(Geo.turnTo(0, 90), 90);
      expect(Geo.turnTo(350, 10), 20);
      expect(Geo.turnTo(10, 350), -20);
      expect(Geo.turnTo(90, 270).abs(), 180);
    });

    test('los textos: distancia, tiempo caminando y rumbo en palabras', () {
      expect(Geo.distanceLabel(45.4), '45 m');
      expect(Geo.distanceLabel(1250), '1,3 km');
      // 120 m a 1,2 m/s son 100 segundos.
      expect(Geo.walkLabel(120), '1 min 40 s');
      expect(Geo.walkLabel(36), '30 s');
      expect(Geo.walkLabel(600), '8 min');
      expect(Geo.compassWord(0), 'norte');
      expect(Geo.compassWord(135), 'sureste');
      expect(Geo.compassWord(359), 'norte');
    });
  });

  group('el seguimiento de la ubicación', () {
    test('sin permiso no hay ubicación en vivo', () async {
      final FakeLocationService service = FakeLocationService(access: LocationAccess.denied);
      final LocationTracker tracker = LocationTracker(service);
      addTearDown(tracker.dispose);

      await tracker.start();

      expect(tracker.access, LocationAccess.denied);
      expect(tracker.isLive, isFalse);
    });

    test('con permiso, cada ubicación mueve el punto y guarda el recorrido', () async {
      final FakeLocationService service = FakeLocationService();
      final LocationTracker tracker = LocationTracker(service);
      addTearDown(() async {
        tracker.dispose();
        await service.dispose();
      });

      await tracker.start();
      expect(tracker.isLive, isFalse, reason: 'todavía no llega nada');

      service.moveTo(southOf(100));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.isLive, isTrue);
      expect(tracker.trail, hasLength(1));

      // Un movimiento de 1 m es ruido del GPS: no se anota.
      service.moveTo(southOf(99));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.trail, hasLength(1));

      service.moveTo(southOf(90));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.trail, hasLength(2));
      expect(tracker.fix!.point, southOf(90));
    });

    test('un celular sin GPS (pruebas, escritorio) no inventa una ubicación', () async {
      final LocationTracker tracker = LocationTracker(const NoLocationService());
      addTearDown(tracker.dispose);

      await tracker.start();

      expect(tracker.access, LocationAccess.unsupported);
      expect(tracker.fix, isNull);
    });
  });

  group('el mapa y la ruta del estudiante', () {
    late FakeAlertRepository alerts;
    late FakeLocationService gps;

    setUp(() {
      alerts = FakeAlertRepository(latency: Duration.zero);
      gps = FakeLocationService();
    });

    tearDown(() async {
      alerts.dispose();
      await gps.dispose();
    });

    Future<void> openMap(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(411, 1100);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(
          enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
          credentialsRepository: FakeCredentialsRepository(latency: Duration.zero),
          alertRepository: alerts,
          locationService: gps,
        ),
      );
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
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
    }

    testWidgets('el mapa dice a cuántos metros está el punto y hacia dónde queda', (
      WidgetTester tester,
    ) async {
      await openMap(tester);
      expect(find.byKey(const Key('mapa-en-vivo')), findsOneWidget);
      expect(find.text('Sin ubicación'), findsOneWidget);

      gps.moveTo(southOf(100), accuracy: 6);
      await tester.pumpAndSettle();

      expect(find.text('En vivo · GPS ±6 m'), findsOneWidget);
      expect(find.textContaining('Estás a 100 m del punto P1'), findsOneWidget);
      // Al sur del punto: el punto queda al norte.
      expect(find.textContaining('hacia el norte'), findsOneWidget);
    });

    testWidgets('sin permiso lo dice y deja darlo sin salir de la pantalla', (
      WidgetTester tester,
    ) async {
      gps.access = LocationAccess.denied;
      gps.accessAfterRetry = LocationAccess.granted;
      await openMap(tester);

      expect(find.text('Activa tu ubicación'), findsOneWidget);

      await tester.tap(find.byKey(const Key('activar-ubicacion')));
      await tester.pumpAndSettle();
      expect(find.text('Activa tu ubicación'), findsNothing);

      gps.moveTo(southOf(60));
      await tester.pumpAndSettle();
      expect(find.textContaining('Estás a 60 m del punto P1'), findsOneWidget);
    });

    testWidgets('si el permiso se negó para siempre, manda a los ajustes', (
      WidgetTester tester,
    ) async {
      gps.access = LocationAccess.deniedForever;
      await openMap(tester);

      expect(find.text('La ubicación está bloqueada'), findsOneWidget);
      await tester.tap(find.byKey(const Key('activar-ubicacion')));
      await tester.pumpAndSettle();
      expect(gps.settingsOpened, 1);
    });

    testWidgets('se puede escoger el otro punto y la distancia cambia', (
      WidgetTester tester,
    ) async {
      await openMap(tester);
      gps.moveTo(southOf(100));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('punto-P1')), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('punto-P2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('del punto P2'), findsOneWidget);
    });

    testWidgets('la ruta en vivo cuenta los metros que faltan y avanza sola al llegar', (
      WidgetTester tester,
    ) async {
      await openMap(tester);
      gps.moveTo(southOf(120), heading: 0);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('iniciar-ruta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mapa-ruta-en-vivo')), findsOneWidget);
      expect(find.byKey(const Key('metros-restantes')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('metros-restantes'))).data,
        '120 m',
      );
      expect(find.textContaining('Sigue hacia el norte'), findsOneWidget);
      // Los pasos que escribió el colegio siguen ahí.
      expect(find.byKey(const Key('instruccion-actual')), findsOneWidget);

      // Camina hacia el punto: lo que falta baja.
      gps.moveTo(southOf(50), heading: 0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('metros-restantes'))).data, '50 m');

      // A menos de 15 m, la app da por llegada a la persona.
      gps.moveTo(southOf(8), heading: 0);
      await tester.pumpAndSettle();
      expect(find.text('Llegaste al punto P1'), findsOneWidget);
    });

    testWidgets('desde la ruta se puede pedir ayuda', (
      WidgetTester tester,
    ) async {
      await openMap(tester);
      await tester.tap(find.byKey(const Key('iniciar-ruta')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('ruta-necesito-ayuda')));
      await tester.tap(find.byKey(const Key('ruta-necesito-ayuda')));
      await tester.pumpAndSettle();
      expect(find.text('¿QUÉ PASA?'), findsOneWidget);
    });
  });
}
