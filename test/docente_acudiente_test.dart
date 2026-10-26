import 'support/fakes/fake_account_repository.dart';
import 'support/fakes/fake_alert_repository.dart';
import 'support/fakes/fake_drill_repository.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/onboarding/domain/guardian_link.dart';
import 'package:alertic/features/drills/domain/drill_repository.dart';
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
  late FakeDrillRepository drills;
  late FakeAccountRepository account;

  setUp(() {
    alerts = FakeAlertRepository(latency: Duration.zero);
    drills = FakeDrillRepository();
    account = FakeAccountRepository();
  });
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
        drillRepository: drills,
        accountRepository: account,
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

    await tester.tap(find.text('Saltar'));
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

      await tester.scrollUntilVisible(find.text('LISTA DEL GRUPO'), 200);
      await tester.ensureVisible(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();

      expect(find.text('FALTAN 4'), findsOneWidget);
      expect(find.text('2 de 6'), findsOneWidget);
      // Quien pidió ayuda va primero y no se marca a salvo desde la lista.
      expect(find.textContaining('Pidió ayuda'), findsWidgets);
      expect(find.text('Está aquí'), findsNWidgets(3));
      expect(find.text('Enviar lista a Coordinación'), findsOneWidget);
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
      await tester.scrollUntilVisible(find.text('LISTA DEL GRUPO'), 200);
      await tester.ensureVisible(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();

      expect(find.text('2 de 6'), findsOneWidget);
      expect(find.text('2 confirmaron en su celular · 0 los marcaste tú'), findsOneWidget);

      await tester.tap(find.text('Está aquí').first);
      await tester.pumpAndSettle();

      expect(find.text('3 de 6'), findsOneWidget);
      expect(find.text('FALTAN 3'), findsOneWidget);
      expect(find.text('2 confirmaron en su celular · 1 los marcaste tú'), findsOneWidget);
    });

    testWidgets('los que están a salvo quedan plegados hasta pedirlos', (
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
      await tester.scrollUntilVisible(find.text('LISTA DEL GRUPO'), 200);
      await tester.ensureVisible(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTA DEL GRUPO'));
      await tester.pumpAndSettle();

      expect(find.text('2 a salvo'), findsOneWidget);
      expect(find.text('Laura Pérez'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('ver-a-salvo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ver-a-salvo')));
      await tester.pumpAndSettle();

      expect(find.text('Laura Pérez'), findsOneWidget);
      expect(find.text('Ocultar la lista'), findsOneWidget);
    });
  });

  group('45 · inicio del docente', () {
    testWidgets('muestra las cifras del grupo y el próximo simulacro', (
      WidgetTester tester,
    ) async {
      drills.upcoming.add(
        Drill(
          id: 'd1',
          hazard: Hazard.sismo,
          scheduledAt: DateTime.now().add(const Duration(days: 2)),
          scope: 'Todo el colegio',
        ),
      );
      await signInWithPassword(tester, 'carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      expect(find.byKey(const Key('cifras-del-grupo')), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Con la app'), findsOneWidget);
      expect(find.text('Necesita apoyo'), findsOneWidget);
      expect(find.byKey(const Key('simulacro-docente')), findsOneWidget);
      expect(find.textContaining('tú lo sabes; tus estudiantes, no'), findsOneWidget);
    });

    testWidgets('sin tarea asignada no inventa «tu papel en una emergencia»', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(tester, 'carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      expect(find.byKey(const Key('tarea-docente')), findsNothing);
    });
  });

  group('46 · alerta del docente con su tarea', () {
    testWidgets('en roja ve su tarea, quién necesita apoyo y abre la lista de su grupo', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(tester, 'carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      alerts.simulate(AlertLevel.roja);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tarea-en-alerta')), findsOneWidget);
      expect(find.text('TU TAREA · DIRECTOR DE 10° B'), findsOneWidget);
      expect(find.text('Pasa lista en la app apenas lleguen.'), findsOneWidget);
      expect(
        find.text('Juan Pérez necesita apoyo: lo acompañan Mateo y Sara.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('abrir-lista-docente')));
      await tester.pumpAndSettle();
      expect(find.text('Lista · 10° B'), findsOneWidget);
    });

    testWidgets('en amarilla lee las mismas instrucciones que todos', (
      WidgetTester tester,
    ) async {
      await signInWithPassword(tester, 'carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      alerts.simulate(AlertLevel.amarilla);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tarea-en-alerta')), findsNothing);
      expect(find.text('QUÉ HACER AHORA'), findsOneWidget);
    });
  });

  group('bloque E · acudiente', () {
    testWidgets('en calma muestra a los hijos sin alarmar', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      expect(find.text('Todo tranquilo'), findsOneWidget);
      expect(find.text('TUS HIJOS'), findsOneWidget);
      expect(find.textContaining('Laura Pérez'), findsOneWidget);
      expect(find.textContaining('Andrés Pérez'), findsOneWidget);
    });

    testWidgets('en calma dice qué hijos ya activaron la app y avisa del que no', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      expect(find.text('App activa'), findsOneWidget);
      expect(find.text('Sin activar'), findsOneWidget);
      expect(
        find.text('Andrés aún no activa ALERTIC en su celular. Pídele el código en secretaría.'),
        findsOneWidget,
      );
    });

    testWidgets('«Del colegio» muestra el próximo simulacro', (WidgetTester tester) async {
      // Directo a la lista: `schedule` espera un temporizador que en una
      // prueba de widgets no avanza solo.
      drills.upcoming.add(
        Drill(
          id: 'd1',
          hazard: Hazard.sismo,
          scheduledAt: DateTime.now().add(const Duration(days: 3)),
          scope: 'Todo el colegio',
        ),
      );
      await signInWithCode(tester, 'IICB3HW8');
      await tester.scrollUntilVisible(find.text('DEL COLEGIO'), 200);

      expect(find.text('DEL COLEGIO'), findsOneWidget);
      expect(find.byKey(const Key('proximo-simulacro')), findsOneWidget);
      expect(find.text('Simulacro de sismos'), findsOneWidget);
      expect(find.textContaining('No es necesario ir al colegio'), findsOneWidget);
    });

    testWidgets('sin simulacros ni alertas anteriores no inventa nada', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      expect(find.text('DEL COLEGIO'), findsNothing);
    });

    testWidgets('el perfil muestra a los hijos y los avisos que se pueden apagar', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('HIJOS VINCULADOS'), findsOneWidget);
      expect(find.byKey(const Key('agregar-hijo')), findsOneWidget);
      expect(find.text('Alertas del colegio'), findsOneWidget);
      expect(find.text('Siempre activas para acudientes'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('ajuste-hijo-a-salvo')), 200);
      await tester.ensureVisible(find.byKey(const Key('ajuste-hijo-a-salvo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ajuste-hijo-a-salvo')));
      await tester.pumpAndSettle();
      expect(account.settings.notifyChildSafe, isFalse);
    });

    testWidgets('«+ Agregar» busca al hijo, pide el parentesco y deja la solicitud', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('agregar-hijo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hijo-documento')), '1098 765 434');
      await tester.pump();
      await tester.tap(find.byKey(const Key('buscar-hijo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hijo-encontrado')), findsOneWidget);
      expect(find.text('Sofía A••••• V•••••'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hijo-parentesco-other')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('enviar-solicitud-hijo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('solicitud-hijo-enviada')), findsOneWidget);
      expect(account.childRequests, hasLength(1));
      expect(account.childRequests.single.document, '1098765434');
      expect(account.childRequests.single.relationship, GuardianRelationship.other);
    });

    testWidgets('un documento que no existe muestra el error y no deja enviar', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('agregar-hijo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hijo-documento')), '99999999');
      await tester.pump();
      await tester.tap(find.byKey(const Key('buscar-hijo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-hijo')), findsOneWidget);
      expect(find.byKey(const Key('enviar-solicitud-hijo')), findsNothing);
      expect(account.childRequests, isEmpty);
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

      expect(find.byKey(const Key('aviso-alerta-acudiente')), findsOneWidget);
      expect(find.textContaining('en el colegio ·'), findsOneWidget);
      expect(find.text('QUÉ HACER COMO ACUDIENTE'), findsOneWidget);
      expect(
        find.textContaining('No vayas al colegio todavía'),
        findsOneWidget,
      );
      expect(find.textContaining('Evita llamar a tus hijos'), findsOneWidget);
      expect(find.textContaining('A SALVO'), findsOneWidget);
      expect(find.text('SIN CONFIRMAR'), findsOneWidget);
      // Y explica por qué el de sexto no ha confirmado.
      expect(find.textContaining('No tiene celular'), findsOneWidget);
    });

    testWidgets('cómo recogerlos lista a los hijos', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester, 'IICB3HW8');

      await tester.scrollUntilVisible(find.text('CÓMO RECOGERLOS'), 200);
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
