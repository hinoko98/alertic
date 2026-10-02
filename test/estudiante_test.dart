import 'package:alertic/app/role_experience.dart';
import 'package:alertic/core/session/user_role.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'package:alertic/features/student/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Recorrido del bloque C: entrar como estudiante, recibir una alerta y
/// responderla.
void main() {
  late FakeAlertRepository alerts;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
  });

  tearDown(() => alerts.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository:
            FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
      ),
    );
  }

  /// Hace el registro completo con el código que se le pase y deja la app
  /// abierta en el inicio del rol correspondiente.
  Future<void> signIn(WidgetTester tester, String code) async {
    await pumpApp(tester);
    await tester.tap(find.text('EMPEZAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, code.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.enterText(fields.last, code.substring(4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SÍ, SOY YO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACTIVAR Y ENTRAR'));
    await tester.pumpAndSettle();
  }

  group('la app que abre cada rol', () {
    testWidgets('el estudiante entra a su app con las cuatro pestañas', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      expect(find.text('SIN ALERTAS'), findsOneWidget);
      expect(find.text('Cancha central'), findsOneWidget);
      for (final String tab in <String>['Inicio', 'Mapa', 'Guía', 'Perfil']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('el docente entra a su propia app, no a la del estudiante', (
      WidgetTester tester,
    ) async {
      // Por correo y contraseña: es la única forma que tiene un docente. El
      // código del carné es solo para estudiantes y acudientes.
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('YA TENGO CUENTA'));
      await tester.pumpAndSettle();

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.first, 'carlos.jaimes@iic.edu.co');
      await tester.enterText(fields.last, 'Contabilidad2026');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTIVAR Y ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('GENERAR ALERTA'), findsOneWidget);
      // No ve las pestañas del estudiante ni su punto de encuentro.
      expect(find.text('Mapa'), findsNothing);
      expect(find.text('REPORTAR EMERGENCIA'), findsNothing);
    });

    test('la fábrica de roles arma una app distinta por rol', () {
      expect(
        RoleExperiences.forRole(UserRole.estudiante),
        isA<StudentExperience>(),
      );
      expect(RoleExperiences.forRole(UserRole.docente), isA<TeacherExperience>());
      expect(
        RoleExperiences.forRole(UserRole.acudiente),
        isA<GuardianExperience>(),
      );
      expect(
        RoleExperiences.forRole(UserRole.administrador),
        isA<AdminExperience>(),
      );
    });
  });

  group('la alerta entra por encima de todo', () {
    testWidgets('una alerta amarilla se lee y se cierra con «entendido»', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      alerts.simulate(AlertLevel.amarilla);
      await tester.pumpAndSettle();

      expect(find.text('LLUVIA FUERTE'), findsOneWidget);
      expect(find.text('ENTENDIDO'), findsOneWidget);

      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();

      // Vuelve al inicio, pero la alerta sigue visible como estado del colegio.
      expect(find.text('ENTENDIDO'), findsNothing);
      expect(find.textContaining('LLUVIA FUERTE'), findsOneWidget);
    });

    testWidgets('la alerta roja no se cierra: exige responder', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      expect(find.text('SISMO'), findsOneWidget);
      expect(find.text('ESTOY A SALVO'), findsOneWidget);
      expect(find.text('NECESITO AYUDA'), findsOneWidget);

      // El botón de atrás no la quita.
      final NavigatorState navigator =
          tester.state(find.byType(Navigator).first);
      navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('ESTOY A SALVO'), findsOneWidget);
    });

    testWidgets('responder a la roja lleva al reporte de estado y lo envía', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ESTOY A SALVO'));
      await tester.pumpAndSettle();

      expect(find.text('¿CÓMO ESTÁS?'), findsOneWidget);
      expect(find.text('¿DÓNDE ESTÁS?'), findsOneWidget);
      expect(find.textContaining('En el punto P1'), findsOneWidget);

      await tester.tap(find.text('ENVIAR'));
      await tester.pumpAndSettle();

      // Con el reporte enviado, la alerta deja de tapar la app.
      expect(find.text('¿CÓMO ESTÁS?'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
    });
  });

  group('las pestañas del estudiante', () {
    testWidgets('el mapa muestra la ruta al punto de encuentro', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();

      // El punto de la persona sale de su perfil...
      expect(find.text('A P1 · 60 m · 1 min'), findsOneWidget);
      expect(find.text('TU PUNTO DE ENCUENTRO'), findsOneWidget);
      // ...y los demás, de los que definió el colegio. Ya no hay un plano
      // dibujado con bloques inventados ni un botón que fingía avisar.
      expect(find.text('PLACA ALTA'), findsOneWidget);
      expect(find.text('BLOQUE A'), findsNothing);
      expect(find.text('LLEGUÉ AL PUNTO'), findsNothing);
    });

    testWidgets('la guía trae los protocolos guardados', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      await tester.tap(find.text('Guía'));
      await tester.pumpAndSettle();

      expect(find.text('QUÉ HACER'), findsOneWidget);
      expect(find.text('SISMOS'), findsOneWidget);

      await tester.tap(find.text('SISMOS'));
      await tester.pumpAndSettle();
      expect(find.text('DURANTE'), findsOneWidget);
    });

    testWidgets('el perfil muestra el historial y permite cerrar sesión', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('TU PERFIL'), findsOneWidget);
      expect(find.text('HISTORIAL DE ALERTAS'), findsOneWidget);
      expect(find.text('Aula 7 · Bloque A'), findsOneWidget);

      // Cerrar sesión va al final de la lista, lejos de lo que se toca a
      // diario.
      await tester.scrollUntilVisible(
        find.text('CERRAR SESIÓN'),
        300,
        scrollable: find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('CERRAR SESIÓN'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      // Cancelar deja todo como estaba.
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      // Confirmar borra la sesión y devuelve al registro: para volver a entrar
      // hace falta un código nuevo.
      await tester.tap(find.text('CERRAR SESIÓN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'CERRAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.text('EMPEZAR'), findsOneWidget);
    });

    testWidgets('desde el inicio se llega al mapa y a la guía', (
      WidgetTester tester,
    ) async {
      await signIn(tester, '7K4P2Q9M');

      await tester.tap(find.text('Cancha central'));
      await tester.pumpAndSettle();
      expect(find.text('RUTA DE EVACUACIÓN'), findsOneWidget);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QUÉ HACER'));
      await tester.pumpAndSettle();
      expect(find.text('SISMOS'), findsOneWidget);
    });
  });
}
