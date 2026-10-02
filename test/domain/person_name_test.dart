import 'package:alertic/features/onboarding/domain/person_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// El nombre corto es lo que la persona ve de sí misma en el encabezado. Si
/// dice el apellido equivocado, se lee como si fuera otra persona.
void main() {
  group('PersonName', () {
    test('dos nombres y dos apellidos usan el primer apellido', () {
      expect(PersonName.short('Laura Camila Pérez Gómez'), 'Laura Pérez');
      expect(PersonName.initials('Laura Camila Pérez Gómez'), 'LP');
    });

    test('un nombre y dos apellidos (tres palabras) usan el primero', () {
      // El caso más común en Colombia. Con la regla anterior, a Carlos Jaimes
      // Duarte se le llamaba «Carlos Duarte»: su apellido materno.
      expect(PersonName.short('Carlos Jaimes Duarte'), 'Carlos Jaimes');
      expect(PersonName.short('Martha Gómez Ardila'), 'Martha Gómez');
      expect(PersonName.short('Nubia Silva Castro'), 'Nubia Silva');
      expect(PersonName.initials('Carlos Jaimes Duarte'), 'CJ');
    });

    test('nombre y apellido sencillos', () {
      expect(PersonName.short('Martha Gómez'), 'Martha Gómez');
      expect(PersonName.initials('Martha Gómez'), 'MG');
    });

    test('un solo nombre se deja como está', () {
      expect(PersonName.short('Laura'), 'Laura');
      expect(PersonName.initials('Laura'), 'L');
    });
  });
}
