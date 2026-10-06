import 'support/fakes/fake_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'support/fakes/fake_guardian_repository.dart';
import 'support/fakes/fake_credentials_repository.dart';
import 'support/fakes/fake_enrollment_repository.dart';
import 'support/fakes/fake_teacher_repository.dart';
import 'package:alertic/features/teacher/presentation/widgets/hold_to_send_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Bloques D y E: la app del docente y la del acudiente.
void main() {
  late FakeAlertRepository alerts;

  setUp(() => alerts = FakeAlertRepository(latency: Duration.zero));
  tearDown(() => alerts.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository:
            FakeCredentialsRepository(latency: Duration.zero),
        alertRepository: alerts,
        // Sin demora: `pumpAndSettle` no espera trabajo asíncrono que no anime
        // nada, así que una latencia simulada dejaría la pantalla a medio
        // cargar cuando el test mira.
        teacherRepository:
            FakeTeacherRepository(alerts, latency: Duration.zero),
        guardianRepository: FakeGuardianRepository(latency: Duration.zero),
      ),
    );
  }

  /// Entra como docente o administrador: correo y contraseña, que es la única
  /// forma que tienen. No pasan por «¿eres tú?» porque acaban de escribir su
  /// propia contraseña: ya saben quiénes son.
  Future<void> signInWithPassword(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, email);
    await tester.enterText(fields.last, password);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Permitir y continuar'));
    await tester.pumpAndSettle();
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  /// Entra con el código del carné: estudiantes y acudientes.
  Future<void> signInWithCode(WidgetTester tester, String code) async {
    await pumpApp(tester);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, code.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.enterText(fields.last, code.substring(4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sí, soy yo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir y continuar'));
    await tester.pumpAndSettle();
    if (find.text('Terminar y entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Terminar y entrar'));
      await tester.pumpAndSettle();
    }
  }

  group('bloque D · docente', () {
    testWidgets('el inicio muestra su grupo y el botón de emitir', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );

      expect(find.text('10° B'), findsOneWidget);
      expect(find.text('Contabilidad'), findsOneWidget);
      expect(find.text('GENERAR ALERTA'), findsOneWidget);
    });

    testWidgets('la alerta no se emite con un toque: hay que sostener', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );

      await tester.tap(find.text('GENERAR ALERTA'));
      await tester.pumpAndSettle();
      expect(find.text('NUEVA ALERTA'), findsOneWidget);

      // Sin escoger amenaza y nivel, el botón está bloqueado.
      await tester.tap(find.text('SISMOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ROJA'));
      await tester.pumpAndSettle();

      // Un toque suelta el gesto antes de tiempo: no debe emitir nada.
      await tester.tap(find.byType(HoldToSendButton));
      await tester.pumpAndSettle();
      expect(find.text('NUEVA ALERTA'), findsOneWidget);
      expect(alerts.lastPublished, isNull);
    });

    testWidgets('sostener el botón sí emite la alerta', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );

      await tester.tap(find.text('GENERAR ALERTA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SISMOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ROJA'));
      await tester.pumpAndSettle();

      // Se mantiene presionado más de lo que dura la barra.
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(HoldToSendButton)));
      // El reconocedor de gestos necesita un frame para dar por empezado el
      // toque antes de que la barra arranque.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(alerts.lastPublished?.level, AlertLevel.roja);
      expect(alerts.lastPublished?.title, 'SISMO');
      // Una roja siempre lleva punto de encuentro.
      expect(alerts.lastPublished?.meetingPoint, isNotNull);
      // Lo que dice la alerta es el protocolo «Durante» que publicó el colegio, no
      // un texto escrito en la app con lugares inventados.
      expect(alerts.lastPublished?.instructions.first, 'Cúbrete bajo el pupitre hasta que pare');
      expect(
        alerts.lastPublished?.instructions.join(' ').toLowerCase(),
        isNot(contains('cancha')),
      );
    });

    testWidgets('«dónde» ofrece el colegio y los grupos del docente, no bloques inventados', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(tester, 'carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      await tester.tap(find.text('GENERAR ALERTA'));
      await tester.pumpAndSettle();

      Finder chip(String text) =>
          find.textContaining(RegExp(text, caseSensitive: false));

      expect(chip('todo el instituto'), findsOneWidget);
      expect(chip('10° B'), findsWidgets);
      expect(chip('bloque'), findsNothing);
      expect(chip('patio'), findsNothing);
    });

    testWidgets('la lista del grupo separa a quien falta', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      // El docente también está en el edificio: primero responde por él.
      await tester.tap(find.text('Estoy a salvo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();

      expect(find.text('SIN RESPUESTA'), findsOneWidget);
      expect(find.text('Necesita ayuda'), findsOneWidget);
      expect(find.text('MARCAR A SALVO'), findsWidgets);
      expect(find.text('ENVIAR REPORTE A COORDINACIÓN'), findsOneWidget);
    });

    testWidgets('marcar a salvo a quien no tiene celular actualiza el conteo', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(
        tester,
        'carlos.jaimes@iic.edu.co',
        'Contabilidad2026',
      );
      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estoy a salvo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();

      expect(find.text('/6'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('MARCAR A SALVO').first);
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
    });
  });

  group('bloque E · acudiente', () {
    testWidgets('en calma muestra a los hijos sin alarmar', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      expect(find.text('Sin alertas activas'), findsOneWidget);
      expect(find.text('TUS HIJOS'), findsOneWidget);
      expect(find.textContaining('Laura Pérez'), findsOneWidget);
      expect(find.textContaining('Andrés Pérez'), findsOneWidget);
    });

    testWidgets('durante una alerta dice primero que no vaya al colegio', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();
      // La recarga del estado de los hijos ocurre después del frame en que
      // llega la alerta.
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No vayas al colegio todavía'),
        findsOneWidget,
      );
      expect(find.textContaining('A SALVO'), findsOneWidget);
      expect(find.text('SIN CONFIRMAR'), findsOneWidget);
      // Y explica por qué el de sexto no ha confirmado.
      expect(find.textContaining('No tiene celular'), findsOneWidget);
    });

    testWidgets('cómo recogerlos lista a los hijos', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      await tester.tap(find.text('CÓMO RECOGERLOS'));
      await tester.pumpAndSettle();

      expect(find.text('RECOGE A TUS HIJOS'), findsOneWidget);
      expect(find.text('Documento de identidad'), findsOneWidget);
      // Los dos hijos de la familia, por nombre.
      expect(find.textContaining('Laura'), findsOneWidget);
      expect(find.textContaining('Andrés'), findsOneWidget);
      // No hay código QR ni nada que parezca uno: lo que no se puede escanear
      // no se dibuja.
      expect(find.textContaining('CÓDIGO'), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
    });
  });
}
