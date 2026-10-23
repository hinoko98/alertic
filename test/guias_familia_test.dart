import 'package:alertic/features/guardian/presentation/screens/family_content_screen.dart';
import 'package:alertic/features/guardian/presentation/screens/family_guides_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla 42: guías para la familia.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpGuides(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FamilyGuidesScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('arriba dice qué hacer si llega una alerta, en tres pasos', (
    WidgetTester tester,
  ) async {
    await pumpGuides(tester);

    expect(find.text('Guías para la familia'), findsOneWidget);
    expect(find.byKey(const Key('si-recibes-una-alerta')), findsOneWidget);
    expect(find.text('Mira en Inicio si tu hijo ya está a salvo.'), findsOneWidget);
    expect(find.text('No vayas ni llames: deja las vías y las líneas libres.'), findsOneWidget);
  });

  testWidgets('«Prepárate en casa» ofrece las cuatro guías', (WidgetTester tester) async {
    await pumpGuides(tester);

    for (final String key in <String>[
      'guia-kit-familiar',
      'guia-plan-familiar',
      'guia-que-aprende',
      'guia-hablar-despues',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('el plan familiar y «hablarles después del susto» abren su contenido', (
    WidgetTester tester,
  ) async {
    await pumpGuides(tester);

    await tester.tap(find.byKey(const Key('guia-plan-familiar')));
    await tester.pumpAndSettle();
    expect(find.text('Plan familiar de emergencia'), findsWidgets);
    expect(find.textContaining('punto de reunión fuera de casa'), findsOneWidget);

    // La app dibuja su propia flecha de volver, no la de Material.
    Navigator.of(tester.element(find.byType(FamilyContentScreen))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('guia-hablar-despues')), 200);
    await tester.tap(find.byKey(const Key('guia-hablar-despues')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escúchalos primero'), findsOneWidget);
  });

  testWidgets('el kit familiar es el mismo kit de casa', (WidgetTester tester) async {
    await pumpGuides(tester);

    await tester.tap(find.byKey(const Key('guia-kit-familiar')));
    await tester.pumpAndSettle();

    expect(find.text('Tu kit'), findsOneWidget);
    expect(find.text('0 de 8'), findsOneWidget);
  });

  test('cada guía de la familia tiene contenido', () {
    for (final FamilyContentScreen guide in <FamilyContentScreen>[
      FamilyContentScreen.familyPlan,
      FamilyContentScreen.afterTheScare,
    ]) {
      expect(guide.points.length, greaterThanOrEqualTo(4));
      expect(guide.intro, isNotEmpty);
    }
  });
}
