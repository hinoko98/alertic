import 'package:alertic/features/onboarding/presentation/screens/guardian_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes/fake_enrollment_repository.dart';
import 'support/test_app.dart';

/// El registro del acudiente buscando a su hijo por documento (pantallas 10 a 13).
void main() {
  late FakeEnrollmentRepository enrollment;

  Future<void> pumpApp(WidgetTester tester) async {
    enrollment = FakeEnrollmentRepository(latency: Duration.zero);
    await tester.pumpWidget(testApp(enrollmentRepository: enrollment));
  }

  Future<void> openSearch(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acudiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  group('10 · buscar al hijo', () {
    testWidgets('«Acudiente» lleva a buscar al estudiante por documento', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);

      expect(find.byType(GuardianSearchScreen), findsOneWidget);
      expect(find.text('Busca a tu hijo o hija'), findsOneWidget);
      expect(find.text('Paso 1 de 4'), findsOneWidget);
    });

    testWidgets('el botón espera un colegio válido y un documento', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);

      // El botón apagado se dibuja con opacidad baja.
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text('Buscar estudiante'), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(opacity(), 0.4);

      await tester.enterText(find.byKey(const Key('acudiente-colegio')), 'IICB');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('colegio-confirmado')), findsOneWidget);
      expect(find.text('Instituto Integrado de Comercio'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('acudiente-documento')), '1095 812 334');
      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('un colegio que no existe lo dice', (WidgetTester tester) async {
      await openSearch(tester);

      await tester.enterText(find.byKey(const Key('acudiente-colegio')), 'ZZZZ');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-colegio')), findsOneWidget);
      expect(find.byKey(const Key('colegio-confirmado')), findsNothing);
    });

    testWidgets('un documento que no está en la matrícula muestra el error', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);

      await tester.enterText(find.byKey(const Key('acudiente-colegio')), 'IICB');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('acudiente-documento')), '99999999');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar estudiante'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-estudiante')), findsOneWidget);
    });

    testWidgets('quien ya tiene código puede seguir con él', (WidgetTester tester) async {
      await openSearch(tester);

      // En una pantalla baja el enlace queda debajo del pliegue.
      await tester.ensureVisible(find.byKey(const Key('acudiente-tengo-codigo')));
      await tester.tap(find.byKey(const Key('acudiente-tengo-codigo')));
      await tester.pumpAndSettle();

      expect(find.text('Tu código de acceso'), findsOneWidget);
    });
  });

  Future<void> searchChild(WidgetTester tester) async {
    await openSearch(tester);
    await tester.enterText(find.byKey(const Key('acudiente-colegio')), 'IICB');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('acudiente-documento')), '1095 812 334');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar estudiante'));
    await tester.pumpAndSettle();
  }

  group('11 · confirmar al estudiante', () {
    testWidgets('muestra al estudiante con el apellido tapado', (WidgetTester tester) async {
      await searchChild(tester);

      expect(find.text('¿Es tu hijo o hija?'), findsOneWidget);
      expect(find.text('Valentina R••••• G•••••'), findsOneWidget);
      expect(find.text('9.° B'), findsOneWidget);
      expect(find.text('•••2334'), findsOneWidget);
      expect(find.text('Paso 2 de 4'), findsOneWidget);
    });

    testWidgets('«No es mi hijo» vuelve a la búsqueda', (WidgetTester tester) async {
      await searchChild(tester);

      await tester.tap(find.byKey(const Key('no-es-mi-hijo')));
      await tester.pumpAndSettle();

      expect(find.text('Busca a tu hijo o hija'), findsOneWidget);
    });

    testWidgets('agregar otro hijo vuelve a buscar con el colegio ya confirmado', (
      WidgetTester tester,
    ) async {
      await searchChild(tester);

      await tester.ensureVisible(find.byKey(const Key('agregar-otro-hijo')));
      await tester.tap(find.byKey(const Key('agregar-otro-hijo')));
      await tester.pumpAndSettle();

      expect(find.text('Busca a tu hijo o hija'), findsOneWidget);
      expect(find.byKey(const Key('colegio-confirmado')), findsOneWidget);
      // Ya no se ofrece el ingreso con código a mitad del registro.
      expect(find.byKey(const Key('acudiente-tengo-codigo')), findsNothing);
    });
  });

  Future<void> goToData(WidgetTester tester) async {
    await searchChild(tester);
    await tester.tap(find.text('Sí, continuar'));
    await tester.pumpAndSettle();
  }

  group('12 · datos del acudiente', () {
    testWidgets('resume al hijo y el parentesco elegido', (WidgetTester tester) async {
      await searchChild(tester);
      await tester.tap(find.byKey(const Key('parentesco-grandparent')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Tus datos de contacto'), findsOneWidget);
      expect(find.text('Paso 3 de 4'), findsOneWidget);
      expect(find.text('Valentina · 9.° B'), findsOneWidget);
      expect(find.text('Abuelo o abuela'), findsOneWidget);
    });

    testWidgets('pide lo que falta antes de enviar y no manda nada', (
      WidgetTester tester,
    ) async {
      await goToData(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu nombre completo.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('acudiente-nombre')), 'Sandra Rojas Gómez');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu número de documento.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('acudiente-numero')), '63 456 789');
      await tester.enterText(find.byKey(const Key('acudiente-celular')), 'abc');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-datos')), findsOneWidget);

      expect(enrollment.requestsSent, 0);
    });

    testWidgets('con los datos completos envía una solicitud por hijo', (
      WidgetTester tester,
    ) async {
      await goToData(tester);

      await tester.enterText(find.byKey(const Key('acudiente-nombre')), 'Sandra Rojas Gómez');
      await tester.enterText(find.byKey(const Key('acudiente-numero')), '63 456 789');
      await tester.enterText(find.byKey(const Key('acudiente-celular')), '300 555 12 34');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(enrollment.requestsSent, 1);
    });
  });
}
