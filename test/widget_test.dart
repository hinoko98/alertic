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
      expect(PersonalCode.tryParse('IICB7K4P1'), isNull);
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
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
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

      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Quién eres en el colegio?'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu código de acceso'), findsOneWidget);
    });

    testWidgets('un código de estudiante muestra sus datos y acudientes', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, 'IICB7K4P');

      expect(find.text('¿Eres tú?'), findsOneWidget);
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
      await enterCode(tester, 'IICB3HW8');

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
      await enterCode(tester, 'IICB7K4P');

      await tester.tap(find.text('Sí, soy yo'));
      await tester.pumpAndSettle();

      expect(find.text('Para avisarte a tiempo necesitamos dos permisos'), findsOneWidget);
      expect(find.text('Alertas críticas'), findsOneWidget);
    });

    testWidgets('un código que no está en la matrícula muestra el error', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, 'IICBZZZZ');

      expect(find.text('¿Eres tú?'), findsNothing);
      expect(
        find.textContaining('no aparece en la matrícula'),
        findsOneWidget,
      );
    });

    testWidgets('un código de colegio que no existe se dice antes de pedir el personal', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);

      await tester.enterText(find.byKey(const Key('codigo-colegio')), 'ZZZZ');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-colegio')), findsOneWidget);
      expect(find.textContaining('código de colegio no existe'), findsOneWidget);
      expect(find.byKey(const Key('colegio-confirmado')), findsNothing);
      // El personal ni se deja escribir todavía.
      final TextField personal = tester.widget(find.byKey(const Key('codigo-personal')));
      expect(personal.enabled, isFalse);
    });

    testWidgets('al escribir el código del colegio aparece su nombre', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);

      await tester.enterText(find.byKey(const Key('codigo-colegio')), 'iicb');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('colegio-confirmado')), findsOneWidget);
      expect(find.text('Instituto Integrado de Comercio'), findsOneWidget);
      expect(find.text('Barbosa, Santander'), findsOneWidget);
    });

    testWidgets('un código ya usado no sirve una segunda vez', (
      WidgetTester tester,
    ) async {
      await goToCodeScreen(tester);
      await enterCode(tester, 'IICB7K4P');

      // Se confirma una vez: el código queda quemado.
      await tester.tap(find.text('Sí, soy yo'));
      await tester.pumpAndSettle();
      expect(find.text('Para avisarte a tiempo necesitamos dos permisos'), findsOneWidget);

      // Se vuelve a la pantalla del código, que conserva lo escrito, y se
      // intenta validar el mismo código otra vez.
      Navigator.of(tester.element(find.text('Para avisarte a tiempo necesitamos dos permisos')))
        ..pop()
        ..pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Validar código'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya se usó en otro celular'), findsOneWidget);
    });
  });
}
