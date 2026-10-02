import 'package:alertic/core/security/redaction.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se registra en un log de una app escolar termina en capturas y
/// tickets de soporte. Estas pruebas cuidan que ahí no quede nada que
/// identifique a un menor ni sirva para suplantarlo.
void main() {
  group('Redact', () {
    test('el código deja ver el colegio y el primer grupo, nada más', () {
      expect(Redact.code('IICB-7K4P'), 'IICB-••••');
    });

    test('un código con formato raro se oculta completo', () {
      expect(Redact.code('7K4P2Q9M'), '••••');
      expect(Redact.code(null), '••••');
    });

    test('el nombre queda en iniciales', () {
      expect(Redact.name('Laura Camila Pérez Gómez'), 'L. G.');
      expect(Redact.name('Laura'), 'L.');
      expect(Redact.name(null), '••••');
    });

    test('el celular conserva el operador y los últimos cuatro', () {
      expect(Redact.phone('3105554521'), '310 •••• 4521');
      expect(Redact.phone('123'), '••••');
    });

    test('el token no se escribe nunca', () {
      expect(Redact.token('token-real-de-sesion'), '••••');
    });

    test('la ubicación solo dice si había GPS, no dónde', () {
      expect(Redact.coordinates(6.43, -73.61), 'ubicación presente');
      expect(Redact.coordinates(null, null), 'sin ubicación');
    });
  });

  group('PersonalCode', () {
    test('toString sale redactado, formatted sale completo', () {
      final PersonalCode code = PersonalCode.tryParse('IICB7K4P')!;

      // toString es lo que se cuela en una interpolación o en una traza.
      expect('$code', 'IICB-••••');
      // formatted es lo que se muestra en pantalla, a la persona dueña del
      // código.
      expect(code.formatted, 'IICB-7K4P');
    });
  });
}
