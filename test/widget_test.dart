import 'support/fakes/fake_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  group('PersonalCode', () {
    test('acepta el código tal como viene impreso en el carné', () {
      expect(PersonalCode.tryParse('7k4p-2q9m')?.formatted, '7K4P-2Q9M');
      expect(PersonalCode.tryParse('IICB-7K4P')?.formatted, 'IICB-7K4P');
    });

    test('rechaza códigos incompletos o con caracteres de más', () {
      expect(PersonalCode.tryParse('7K4P'), isNull);
      expect(PersonalCode.tryParse('7K4P2Q9M1'), isNull);
    });
  });

  group('registro', () {
    /// Arranca la app con la matrícula de prueba sin demora, para que los
    /// tests no tengan que esperar la latencia simulada.
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          enrollmentRepository:
              FakeEnrollmentRepository(latency: Duration.zero),
        ),
      );
    }

    Future<void> goToCodeScreen(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('EMPEZAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIGUIENTE'));
      await tester.pumpAndSettle();
    }

    Future<void> enterCode(WidgetTester tester, String code) async {
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.first, code.substring(0, 4));
      await tester.pumpAndSettle();
      await tester.enterText(fields.last, code.substring(4));
      await tester.pumpAndSettle();
    }

    testWidgets('avanza de bienvenida a la pantalla del código', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('ALERTIC'), findsOneWidget);

      await tester.tap(find.text('EMPEZAR'));
      await tester.pumpAndSettle();
      expect(find.text('ASÍ FUNCIONA'), findsOneWidget);

      await tester.tap(find.text('SIGUIENTE'));
      await tester.pumpAndSettle();
      expect(find.text('TU CÓDIGO'), findsOneWidget);
    });

    testWidgets('un código de estudiante muestra sus datos y acudientes', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, '7K4P2Q9M');

      expect(find.text('¿ERES TÚ?'), findsOneWidget);
      expect(find.text('ESTUDIANTE'), findsOneWidget);
      expect(find.text('Laura Camila Pérez Gómez'), findsOneWidget);
      expect(find.text('10° B · Mañana'), findsOneWidget);
      expect(find.text('Martha Gómez'), findsOneWidget);
      expect(find.text('Jorge Pérez'), findsOneWidget);
    });

    testWidgets('un código de acudiente muestra los hijos vinculados', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, '3HW8X4LD');

      expect(find.text('ACUDIENTE'), findsOneWidget);
      expect(find.text('Martha Gómez Ardila'), findsOneWidget);
      expect(find.text('Laura Camila Pérez Gómez'), findsOneWidget);
      expect(find.text('Andrés Felipe Pérez Gómez'), findsOneWidget);
      expect(find.text('LP'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
    });

    testWidgets('confirmar identidad lleva a los permisos', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, '7K4P2Q9M');

      await tester.tap(find.text('SÍ, SOY YO'));
      await tester.pumpAndSettle();

      expect(find.text('ÚLTIMO PASO'), findsOneWidget);
      expect(find.text('Alertas críticas'), findsOneWidget);
    });

    testWidgets('un código que no está en la matrícula muestra el error', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, 'ZZZZ9999');

      expect(find.text('¿ERES TÚ?'), findsNothing);
      expect(
        find.textContaining('no aparece en la matrícula'),
        findsOneWidget,
      );
    });

    testWidgets('un código ya usado no sirve una segunda vez', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, '7K4P2Q9M');

      // Se confirma una vez: el código queda quemado.
      await tester.tap(find.text('SÍ, SOY YO'));
      await tester.pumpAndSettle();
      expect(find.text('ÚLTIMO PASO'), findsOneWidget);

      // Se vuelve a la pantalla del código, que conserva lo escrito, y se
      // intenta validar el mismo código otra vez.
      Navigator.of(tester.element(find.text('ÚLTIMO PASO')))
        ..pop()
        ..pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('VALIDAR CÓDIGO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya se usó en otro celular'), findsOneWidget);
    });
  });
}
