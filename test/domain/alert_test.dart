import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:flutter_test/flutter_test.dart';

/// La alerta es lo único que la app recibe de afuera y muestra a pantalla
/// completa. Todo lo que entra se valida aquí.
void main() {
  Alert build({
    String? title = 'SISMO',
    AlertLevel? level = AlertLevel.roja,
    List<String>? instructions = const <String>['Sal en fila'],
    String? meetingPoint = 'P1',
  }) {
    return Alert.validated(
      id: 'a1',
      level: level,
      hazard: Hazard.sismo,
      title: title,
      scope: 'Todo el instituto',
      instructions: instructions,
      meetingPoint: meetingPoint,
      issuedAt: DateTime(2026, 9, 25, 9, 28),
    );
  }

  group('Alert.validated', () {
    test('arma la alerta cuando los datos están completos', () {
      final Alert alert = build();

      expect(alert.title, 'SISMO');
      expect(alert.level, AlertLevel.roja);
      expect(alert.issuedAtLabel, '9:28');
    });

    test('rechaza una alerta sin instrucciones', () {
      expect(
        () => build(instructions: const <String>[]),
        throwsA(isA<InvalidAlertData>()),
      );
    });

    test('rechaza un nivel que no existe en el protocolo', () {
      expect(() => build(level: null), throwsA(isA<InvalidAlertData>()));
    });

    test('rechaza una alerta roja sin punto de encuentro', () {
      // Una evacuación sin destino deja a la gente en el patio sin saber a
      // dónde ir.
      expect(() => build(meetingPoint: null), throwsA(isA<InvalidAlertData>()));
    });

    test('rechaza un título más largo de lo que cabe en pantalla', () {
      expect(
        () => build(title: 'S' * (Alert.maxTitleLength + 1)),
        throwsA(isA<InvalidAlertData>()),
      );
    });

    test('limpia los caracteres de control que vengan del servidor', () {
      final Alert alert = build(title: 'SISMO\u0007\u0000');

      expect(alert.title, 'SISMO');
    });
  });

  group('lectura de valores del servidor', () {
    test('reconoce los tres niveles, sin importar mayúsculas ni espacios', () {
      expect(AlertLevel.tryParse('roja'), AlertLevel.roja);
      expect(AlertLevel.tryParse('  NARANJA '), AlertLevel.naranja);
    });

    test('un nivel desconocido no se interpreta', () {
      expect(AlertLevel.tryParse('morada'), isNull);
      expect(AlertLevel.tryParse(null), isNull);
    });

    test('reconoce las amenazas del plan', () {
      expect(Hazard.tryParse('sismo'), Hazard.sismo);
      expect(Hazard.tryParse('terremoto'), isNull);
    });
  });

  group('reglas del nivel', () {
    test('solo la roja exige respuesta de cada persona', () {
      expect(AlertLevel.roja.requiresResponse, isTrue);
      expect(AlertLevel.naranja.requiresResponse, isFalse);
      expect(AlertLevel.amarilla.requiresResponse, isFalse);
    });

    test('de naranja para arriba la alerta toma la pantalla', () {
      expect(AlertLevel.amarilla.takesOverScreen, isFalse);
      expect(AlertLevel.naranja.takesOverScreen, isTrue);
      expect(AlertLevel.roja.takesOverScreen, isTrue);
    });
  });
}
