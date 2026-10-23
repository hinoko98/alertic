import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/presentation/screens/alert_screen.dart';
import 'package:alertic/features/alerts/presentation/widgets/drill_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las pantallas de alerta por tipo y color (14 a 19 del diseño).
void main() {
  Alert alertOf({
    required Hazard hazard,
    required AlertLevel level,
    String title = 'SISMO',
    String scope = 'Evacuación de todo el colegio',
    bool drill = false,
  }) {
    return Alert.validated(
      id: 'a-${hazard.wire}-${level.wire}',
      level: level,
      hazard: hazard,
      title: title,
      scope: scope,
      meetingPoint: level.requiresResponse ? 'A · Cancha' : null,
      instructions: const <String>[
        'Agáchate, cúbrete y sujétate bajo tu pupitre.',
        'Aléjate de ventanas y estantes.',
      ],
      issuedAt: DateTime(2026, 10, 23, 10, 42),
      isDrill: drill,
    );
  }

  Future<void> pumpAlert(WidgetTester tester, Alert alert) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlertScreen(alert: alert, onAcknowledge: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color backgroundOf(WidgetTester tester) =>
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;

  group('14 · sismo · rojo', () {
    testWidgets('el sismo es rojo y dice el nivel con palabras', (WidgetTester tester) async {
      await pumpAlert(tester, alertOf(hazard: Hazard.sismo, level: AlertLevel.roja));

      expect(backgroundOf(tester), const Color(0xFFB3263A));
      expect(find.text('● ALERTA ACTIVA'), findsOneWidget);
      expect(find.text('SISMO'), findsOneWidget);
      expect(find.text('Alerta roja · Evacuar ya'), findsOneWidget);
      expect(find.text('QUÉ HACER AHORA'), findsOneWidget);
      expect(find.text('10:42'), findsOneWidget);
    });

    testWidgets('lleva los pasos numerados', (WidgetTester tester) async {
      await pumpAlert(tester, alertOf(hazard: Hazard.sismo, level: AlertLevel.roja));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Aléjate de ventanas y estantes.'), findsOneWidget);
    });
  });

  group('15 · inundación · azul', () {
    testWidgets('el fondo es azul y el nivel naranja conserva su propio color', (
      WidgetTester tester,
    ) async {
      await pumpAlert(
        tester,
        alertOf(
          hazard: Hazard.inundacion,
          level: AlertLevel.naranja,
          title: 'INUNDACIÓN',
          scope: 'Bloque 3 y patio central',
        ),
      );

      expect(backgroundOf(tester), const Color(0xFF1D5FA8));
      expect(find.text('Alerta naranja · Prepararse para salir'), findsOneWidget);
      final Container chip = tester.widget<Container>(find.byKey(const Key('nivel-alerta')));
      expect((chip.decoration! as BoxDecoration).color, const Color(0xFFF28C28));
    });

    testWidgets('en roja el nivel se ve rojo aunque el fondo sea azul', (
      WidgetTester tester,
    ) async {
      await pumpAlert(
        tester,
        alertOf(hazard: Hazard.inundacion, level: AlertLevel.roja, title: 'INUNDACIÓN'),
      );

      final Container chip = tester.widget<Container>(find.byKey(const Key('nivel-alerta')));
      expect((chip.decoration! as BoxDecoration).color, const Color(0xFFB2243B));
    });
  });

  group('16 · lluvias fuertes · amarillo', () {
    testWidgets('amarillo con texto oscuro y aviso de precaución', (WidgetTester tester) async {
      await pumpAlert(
        tester,
        alertOf(
          hazard: Hazard.lluvia,
          level: AlertLevel.amarilla,
          title: 'LLUVIAS FUERTES',
          scope: 'No hay que evacuar por ahora',
        ),
      );

      expect(backgroundOf(tester), const Color(0xFFF4C430));
      expect(find.text('● AVISO DE PRECAUCIÓN'), findsOneWidget);
      expect(find.text('Alerta amarilla · Estar atentos'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
      expect(find.text('Reportar algo peligroso'), findsOneWidget);
    });

    testWidgets('si la lluvia sube a roja deja de ser amarilla', (WidgetTester tester) async {
      await pumpAlert(
        tester,
        alertOf(hazard: Hazard.lluvia, level: AlertLevel.roja, title: 'LLUVIAS FUERTES'),
      );

      expect(backgroundOf(tester), isNot(const Color(0xFFF4C430)));
      expect(find.text('Reportar algo peligroso'), findsNothing);
    });
  });

  group('17 · incendio · naranja quemado', () {
    testWidgets('el fondo es el naranja de las llamas y se lee qué zona evitar', (
      WidgetTester tester,
    ) async {
      await pumpAlert(
        tester,
        alertOf(
          hazard: Hazard.incendio,
          level: AlertLevel.roja,
          title: 'INCENDIO',
          scope: 'Laboratorio 2 · tu ruta evita esa zona',
        ),
      );

      expect(backgroundOf(tester), const Color(0xFFB84A00));
      expect(find.text('INCENDIO'), findsOneWidget);
      expect(find.text('Alerta roja · Evacuar ya'), findsOneWidget);
      expect(find.textContaining('Laboratorio 2'), findsOneWidget);
    });
  });

  group('18 · simulacro · morado', () {
    testWidgets('dice que es una práctica y no una emergencia', (WidgetTester tester) async {
      await pumpAlert(
        tester,
        alertOf(
          hazard: Hazard.sismo,
          level: AlertLevel.roja,
          scope: 'todo el colegio',
          drill: true,
        ),
      );

      expect(backgroundOf(tester), const Color(0xFF4B3F8F));
      expect(find.byKey(const Key('banner-simulacro')), findsOneWidget);
      expect(find.text('SIMULACRO · ESTO ES UNA PRÁCTICA'), findsOneWidget);
      expect(find.text('Simulacro programado · todo el colegio'), findsOneWidget);
      // La insignia de «alerta activa» no aparece: sería una mentira.
      expect(find.text('● ALERTA ACTIVA'), findsNothing);
    });

    testWidgets('muestra la meta del colegio que se le pasa', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AlertScreen(
            alert: alertOf(hazard: Hazard.sismo, level: AlertLevel.roja, drill: true),
            onAcknowledge: () {},
            drillGoal: const Duration(minutes: 4, seconds: 30),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('menos de 4:30'), findsOneWidget);
    });
  });

  group('el reloj del simulacro', () {
    test('cuenta desde la hora de emisión, en minutos y segundos', () {
      expect(formatDrillTime(const Duration(seconds: 84)), '01:24');
      expect(formatDrillTime(const Duration(minutes: 12, seconds: 5)), '12:05');
    });

    test('nunca muestra un tiempo negativo', () {
      expect(formatDrillTime(const Duration(seconds: -30)), '00:00');
    });
  });
}
