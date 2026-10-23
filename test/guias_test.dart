import 'package:alertic/features/student/domain/quiz.dart';
import 'package:alertic/features/student/presentation/screens/kit_screen.dart';
import 'package:alertic/features/student/presentation/screens/quiz_screen.dart';
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

  group('29 · quiz', () {
    Future<void> pumpQuiz(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: QuizScreen()));
      await tester.pumpAndSettle();
    }

    Future<void> answer(WidgetTester tester, int option) async {
      await tester.tap(find.byKey(Key('opcion-$option')));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la primera pregunta y no deja avanzar sin contestar', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(tester);

      expect(find.text('Sismo · pregunta 1 de 5'), findsOneWidget);
      expect(find.text(SismoQuiz.questions.first.text), findsOneWidget);
      expect(find.byKey(const Key('retroalimentacion')), findsNothing);
      // El botón está apagado (opacidad baja) hasta que se conteste.
      final Opacity button = tester.widget<Opacity>(
        find.ancestor(of: find.text('Siguiente pregunta'), matching: find.byType(Opacity)).first,
      );
      expect(button.opacity, 0.4);
    });

    testWidgets('acertar dice «¡Correcto!» y explica por qué', (WidgetTester tester) async {
      await pumpQuiz(tester);

      await answer(tester, SismoQuiz.questions.first.correct);

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.textContaining('Correr mientras tiembla'), findsOneWidget);
    });

    testWidgets('fallar explica la respuesta correcta y no suma', (WidgetTester tester) async {
      await pumpQuiz(tester);

      await answer(tester, 0);

      expect(find.text('No era esa'), findsOneWidget);
      expect(find.textContaining('Correr mientras tiembla'), findsOneWidget);
    });

    testWidgets('una vez contestada, la pregunta no se puede cambiar', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(tester);

      await answer(tester, 0);
      await answer(tester, SismoQuiz.questions.first.correct);

      expect(find.text('No era esa'), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
    });

    testWidgets('al terminar muestra cuántas acertó y deja repetir', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(tester);

      for (int i = 0; i < SismoQuiz.questions.length; i++) {
        // Acierta las tres primeras y falla las demás.
        final int pick = i < 3 ? SismoQuiz.questions[i].correct : (SismoQuiz.questions[i].correct + 1) % 4;
        await answer(tester, pick);
        await tester.tap(find.byKey(const Key('siguiente-pregunta')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Acertaste 3 de 5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('repetir-quiz')));
      await tester.pumpAndSettle();
      expect(find.text('Sismo · pregunta 1 de 5'), findsOneWidget);
    });

    test('cada pregunta tiene una respuesta correcta que existe', () {
      for (final QuizQuestion q in SismoQuiz.questions) {
        expect(q.correct, inInclusiveRange(0, q.options.length - 1));
        expect(q.options.toSet().length, q.options.length, reason: 'sin opciones repetidas');
      }
    });
  });
}
