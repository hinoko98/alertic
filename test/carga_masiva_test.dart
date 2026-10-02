import 'package:alertic/app/app_scope.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/core/theme/app_theme.dart';
import 'package:alertic/features/panel/domain/student_list_parser.dart';
import 'package:alertic/features/panel/presentation/screens/community_tab.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_panel_repository.dart';

/// Cargar una lista de estudiantes y emitir códigos por grupo desde el panel.
void main() {
  group('lectura de la lista pegada', () {
    test('entiende tabulador, punto y coma y coma, y arregla el grupo', () {
      final StudentListResult result = StudentListParser.parse(
        'Ana María Torres Ruiz\t9a\t1020304050\n'
        'Pedro Pablo Gómez León; 10 b\n'
        '\n'
        'Luisa Rojas Díaz, 6° C, 998877',
      );

      expect(result.error, isNull);
      expect(result.students.map((s) => s.grade), <String>['9° A', '10° B', '6° C']);
      expect(result.students[0].document, '1020304050');
      expect(result.students[1].document, isNull);
      expect(result.students[2].fullName, 'Luisa Rojas Díaz');
    });

    test('lee al acudiente con su documento y exige que vayan juntos', () {
      final StudentListResult ok = StudentListParser.parse(
        'Ana María Torres Ruiz; 9° A; 1020304050; Rosa Ruiz Díaz; 63111222',
      );
      expect(ok.error, isNull);
      expect(ok.students.single.guardianName, 'Rosa Ruiz Díaz');
      expect(ok.students.single.guardianDocument, '63111222');
      expect(ok.students.single.toJson()['guardianDocument'], '63111222');

      final StudentListResult half = StudentListParser.parse(
        'Ana María Torres Ruiz; 9° A; 1020304050; Rosa Ruiz Díaz',
      );
      expect(half.error, contains('Línea 1'));
      expect(half.error, contains('acudiente'));
    });

    test('salta el encabezado de una hoja de cálculo', () {
      final StudentListResult result = StudentListParser.parse(
        'Nombre;Grupo;Documento\nAna María Torres Ruiz;9° A;1020304050',
      );

      expect(result.error, isNull);
      expect(result.students, hasLength(1));
    });

    test('dice qué línea está mal', () {
      expect(
        StudentListParser.parse('Ana María Torres Ruiz; 9° A\nPedro Gómez León; décimo').error,
        contains('Línea 2'),
      );
      expect(StudentListParser.parse('Ana María Torres Ruiz').error, contains('Línea 1'));
      expect(StudentListParser.parse('   \n ').error, isNotNull);
    });

    test('se niega a más de lo que acepta el servidor', () {
      final String text = List<String>.generate(
        StudentListParser.maxStudents + 1,
        (int i) => 'Estudiante Número $i; 9° A',
      ).join('\n');

      expect(StudentListParser.parse(text).error, contains('máximo'));
    });
  });

  group('en el panel', () {
    late FakeAlertRepository alerts;
    late FakePanelRepository panel;

    setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
    tearDown(() => alerts.dispose());

    Future<void> pump(WidgetTester tester, {bool empty = false}) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1280, 2000);
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
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const Scaffold(body: CommunityTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('carga una lista desde un colegio vacío y muestra los códigos', (
      WidgetTester tester,
    ) async {
      await pump(tester, empty: true);

      await tester.tap(find.text('CARGAR LISTA'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('lista-estudiantes')),
        'Ana María Torres Ruiz; 9° A\nPedro Pablo Gómez León; 9° A',
      );
      await tester.tap(find.text('CARGAR'));
      await tester.pumpAndSettle();

      // La lista de códigos, que se ve una sola vez.
      expect(find.text('ESTUDIANTES CARGADOS'), findsOneWidget);
      expect(find.text('2 códigos nuevos.'), findsOneWidget);
      expect(find.textContaining('Ana María Torres Ruiz · 9° A'), findsOneWidget);
      expect(find.textContaining('vale una hora'), findsOneWidget);

      await tester.tap(find.text('LISTO'));
      await tester.pumpAndSettle();

      // Y quedaron en la comunidad.
      expect(find.text('Ana María Torres Ruiz'), findsOneWidget);
      expect(find.text('Pedro Pablo Gómez León'), findsOneWidget);
    });

    testWidgets('una línea mal escrita no cierra el cuadro y dice cuál es', (
      WidgetTester tester,
    ) async {
      await pump(tester, empty: true);

      await tester.tap(find.text('CARGAR LISTA'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('lista-estudiantes')),
        'Ana María Torres Ruiz; 9° A\nPedro Pablo Gómez León; décimo',
      );
      await tester.tap(find.text('CARGAR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Línea 2'), findsOneWidget);
      expect(find.text('CARGAR ESTUDIANTES'), findsOneWidget);
      expect(find.text('ESTUDIANTES CARGADOS'), findsNothing);
    });

    testWidgets('genera los códigos de un grupo y avisa de quién ya se registró', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('CÓDIGOS POR GRUPO'));
      await tester.pumpAndSettle();

      // Sin elegir grupo no hace nada y lo dice.
      await tester.tap(find.text('GENERAR'));
      await tester.pumpAndSettle();
      expect(find.text('Elige al menos un grupo.'), findsOneWidget);

      // Dentro del diálogo: detrás, la lista de comunidad también dice «10° B».
      for (final String grade in <String>['10° B', '6° A']) {
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(grade),
          ),
        );
        // Un cuadro entre toque y toque, como en la mano: sin él, el segundo
        // toque parte de la selección vieja.
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const Key('reemplazar-sin-usar')));
      await tester.tap(find.text('Reemplazar también los códigos vigentes sin usar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERAR'));
      await tester.pumpAndSettle();

      expect(find.text('CÓDIGOS GENERADOS'), findsOneWidget);
      expect(find.byKey(const Key('codigos-emitidos')), findsOneWidget);
      expect(find.textContaining('ya se registraron'), findsOneWidget);
      expect(find.byKey(const Key('copiar-todo')), findsOneWidget);

      await tester.tap(find.text('LISTO'));
      await tester.pumpAndSettle();
      expect(find.text('CÓDIGOS GENERADOS'), findsNothing);
    });
  });
}
