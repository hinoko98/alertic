import 'package:alertic/features/account/domain/alert_preferences.dart';
import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/presentation/screens/alert_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla 34: cómo le llega la alerta a la persona, en este celular.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('preferencias guardadas en el celular', () {
    test('sin nada guardado, valen los de fábrica', () async {
      final AlertPreferences prefs = await AlertPreferencesStore.load();

      expect(prefs.strongVibration, isFalse);
      expect(prefs.textSize, AlertTextSize.normal);
    });

    test('lo que se guarda se vuelve a leer', () async {
      await AlertPreferencesStore.save(
        const AlertPreferences(strongVibration: true, textSize: AlertTextSize.extraLarge),
      );

      final AlertPreferences prefs = await AlertPreferencesStore.load();
      expect(prefs.strongVibration, isTrue);
      expect(prefs.textSize, AlertTextSize.extraLarge);
    });

    test('un tamaño desconocido vuelve a normal en vez de romper', () {
      expect(AlertTextSize.fromWire('gigante'), AlertTextSize.normal);
      expect(AlertTextSize.fromWire(null), AlertTextSize.normal);
    });
  });

  group('la alerta respeta esas preferencias', () {
    final Alert alert = Alert.validated(
      id: 'a1',
      level: AlertLevel.roja,
      hazard: Hazard.sismo,
      title: 'SISMO',
      scope: 'Todo el colegio',
      meetingPoint: 'P1',
      instructions: const <String>['Cúbrete bajo el pupitre.'],
      issuedAt: DateTime(2026, 10, 23, 10, 42),
    );

    testWidgets('con letra grande, el título se dibuja más grande', (WidgetTester tester) async {
      Future<double> titleWidth(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AlertScreen(alert: alert, onAcknowledge: () {}, textScale: scale),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byKey(const Key('titulo-alerta'))).width;
      }

      final double normal = await titleWidth(1.0);
      final double large = await titleWidth(1.3);

      expect(large, greaterThan(normal));
    });

    testWidgets('con vibración fuerte, vibra al aparecer; sin ella, no', (
      WidgetTester tester,
    ) async {
      int hits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'HapticFeedback.vibrate') hits++;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AlertScreen(alert: alert, onAcknowledge: () {})),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(hits, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: AlertScreen(
            key: UniqueKey(),
            alert: alert,
            onAcknowledge: () {},
            strongVibration: true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(hits, 3);
    });
  });
}
