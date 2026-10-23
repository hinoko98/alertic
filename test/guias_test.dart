import 'package:alertic/features/student/presentation/screens/kit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las guías para prepararse (28 y 29 del diseño).
void main() {
  Future<void> pumpKit(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: KitScreen()));
    await tester.pumpAndSettle();
  }

  group('28 · kit de emergencia', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    testWidgets('empieza en 0 de 8 y cuenta lo que se va marcando', (WidgetTester tester) async {
      await pumpKit(tester);
      expect(find.text('0 de 8'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kit-0')));
      await tester.tap(find.byKey(const Key('kit-2')));
      await tester.pumpAndSettle();

      expect(find.text('2 de 8'), findsOneWidget);
    });

    testWidgets('lo marcado se recuerda al volver a abrir la pantalla', (
      WidgetTester tester,
    ) async {
      await pumpKit(tester);
      await tester.tap(find.byKey(const Key('kit-1')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await pumpKit(tester);

      expect(find.text('1 de 8'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('kit-1'))).value, isTrue);
    });

    testWidgets('quitar la marca baja la cuenta', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        KitScreen.storageKey: <String>[KitScreen.items[0], KitScreen.items[1]],
      });
      await pumpKit(tester);
      expect(find.text('2 de 8'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kit-0')));
      await tester.pumpAndSettle();

      expect(find.text('1 de 8'), findsOneWidget);
    });

    testWidgets('ignora en el celular un elemento que ya no está en la lista', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        KitScreen.storageKey: <String>['Radio de pilas'],
      });
      await pumpKit(tester);

      expect(find.text('0 de 8'), findsOneWidget);
    });
  });
}
