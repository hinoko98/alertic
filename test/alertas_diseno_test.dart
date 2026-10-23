import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/presentation/screens/alert_screen.dart';
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
}
