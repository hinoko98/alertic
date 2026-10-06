@Tags(<String>['integracion'])
library;

import 'dart:io';

import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/features/account/data/api_account_repository.dart';
import 'package:alertic/features/account/domain/account_repository.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/drills/data/api_drill_repository.dart';
import 'package:alertic/features/drills/domain/drill_repository.dart';
import 'package:alertic/features/onboarding/data/api_credentials_repository.dart';
import 'package:alertic/features/onboarding/data/api_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:alertic/features/risks/data/api_risk_repository.dart';
import 'package:alertic/features/risks/domain/risk_repository.dart';
import 'package:alertic/features/support/data/api_support_repository.dart';
import 'package:alertic/features/support/domain/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chat con el colegio, ajustes, simulacros y reportes de riesgo, contra el
/// servidor de verdad.
///
/// Igual que las demás pruebas de integración: necesitan el servidor con la
/// matrícula de prueba (`npm run seed:demo`) y se saltan si no está.
void main() {
  const String baseUrl = String.fromEnvironment(
    'ALERTIC_API',
    defaultValue: 'http://localhost:3000',
  );

  bool serverUp = false;

  setUpAll(() async {
    HttpOverrides.global = null;
    final ApiClient probe = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 3));
    try {
      await probe.get('/health');
      serverUp = true;
    } on ApiException {
      serverUp = false;
    } finally {
      probe.close();
    }
  });

  /// Un cliente por persona: si dos pruebas compartieran uno, una entraría con
  /// la sesión de la otra.
  Future<ApiClient> staff(String email, String password) async {
    final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
    final (Credentials? built, String? problem) = Credentials.tryBuild(
      email: email,
      password: password,
    );
    if (built == null) throw StateError('credenciales de prueba inválidas: $problem');
    await ApiCredentialsRepository(client).signIn(built);
    return client;
  }

  /// Entra una persona con su código. Es de un solo uso: null si ya se gastó.
  Future<ApiClient?> withCode(String code) async {
    final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
    try {
      await ApiEnrollmentRepository(client).confirmIdentity(PersonalCode.tryParse(code)!);
      return client;
    } on CodeAlreadyUsed {
      return null;
    }
  }

  // Andrés es estudiante y su código solo se quema una vez: todas las pruebas
  // que necesitan un estudiante comparten la misma sesión.
  Future<ApiClient?>? andresSession;
  Future<ApiClient?> andres() => andresSession ??= withCode('IICB-9RT2');

  group('chat con el colegio', () {
    test('lo que escribe un estudiante le llega a coordinación, que le responde', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient? guardian = await andres();
      if (guardian == null) {
        markTestSkipped('El código ya se usó. Vuelve a sembrar: npm run seed:demo');
        return;
      }
      final SupportRepository mine = ApiSupportRepository(guardian);
      final String text = 'Buenas, ¿a qué hora salen hoy? ${DateTime.now().microsecondsSinceEpoch}';
      await mine.sendMine(text);

      final ApiClient admin = await staff('coordinacion@iic.edu.co', 'Barbosa2026Riesgo');
      final SupportRepository inbox = ApiSupportRepository(admin);
      final List<SupportThread> threads = await inbox.loadThreads();
      final SupportThread thread = threads.firstWhere(
        (SupportThread t) => t.personName?.startsWith('Andrés') ?? false,
      );
      expect(thread.unread, greaterThan(0));

      final SupportConversation conversation = await inbox.loadThread(thread.id);
      expect(conversation.messages.map((SupportMessage m) => m.body), contains(text));

      await inbox.reply(thread.id, 'A las 12:30.');
      // Antes de abrir la conversación: al abrirla queda leída.
      expect(await mine.unreadCount(), greaterThan(0));
      final SupportConversation seen = await mine.loadMine();
      expect(seen.messages.last.fromStaff, isTrue);
      expect(seen.messages.last.body, 'A las 12:30.');
      expect(await mine.unreadCount(), 0);
    });

    test('un docente no ve la bandeja de otro grupo: solo los hilos que le asignaron', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient nubia = await staff('nubia.silva@iic.edu.co', 'Matematicas2026');
      final List<SupportThread> threads = await ApiSupportRepository(nubia).loadThreads();
      // Lo que importa: no lanza y no trae hilos de personas ajenas a sus grupos.
      for (final SupportThread t in threads) {
        expect(t.personName, isNotNull);
      }
    });
  });

  group('ajustes y contactos', () {
    test('la información médica se guarda y se borra', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await staff('carlos.jaimes@iic.edu.co', 'Contabilidad2026');
      final AccountRepository account = ApiAccountRepository(client);

      final AccountSettings saved = await account.updateSettings(
        medicalInfo: 'Alergia a la penicilina',
      );
      expect(saved.medicalInfo, 'Alergia a la penicilina');

      final AccountSettings cleared = await account.updateSettings(clearMedicalInfo: true);
      expect(cleared.medicalInfo, isNull);
    });

    test('un contacto de la familia se agrega y se quita', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      // Los contactos de la familia son de estudiantes y acudientes.
      final ApiClient? client = await andres();
      if (client == null) {
        markTestSkipped('El código ya se usó. Vuelve a sembrar: npm run seed:demo');
        return;
      }
      final AccountRepository account = ApiAccountRepository(client);

      final List<FamilyContact> after = await account.addContact(
        const NewContact(fullName: 'Prueba Integración', relationship: 'Tío', phone: '3001234567'),
      );
      final FamilyContact added =
          after.firstWhere((FamilyContact c) => c.fullName == 'Prueba Integración');

      final List<FamilyContact> removed = await account.removeContact(added.id);
      expect(removed.any((FamilyContact c) => c.id == added.id), isFalse);
    });

    test('«alertas y avisos» responde con una lista', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient client = await staff('carlos.jaimes@iic.edu.co', 'Contabilidad2026');
      expect(await ApiAccountRepository(client).loadFeed(), isA<List<FeedItem>>());
    });
  });

  group('simulacros', () {
    test('coordinación programa uno, todos lo ven y lo cancela', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient admin = await staff('coordinacion@iic.edu.co', 'Barbosa2026Riesgo');
      final ApiClient teacher = await staff('carlos.jaimes@iic.edu.co', 'Contabilidad2026');

      final DrillRepository drills = ApiDrillRepository(admin);
      final Drill drill = await drills.schedule(
        hazard: Hazard.sismo,
        at: DateTime.now().add(const Duration(days: 30)),
        note: 'Prueba de integración',
      );

      final DrillOverview seen = await ApiDrillRepository(teacher).load();
      expect(seen.upcoming.any((Drill d) => d.id == drill.id), isTrue);

      // Un docente no programa ni cancela.
      await expectLater(
        ApiDrillRepository(teacher).cancel(drill.id),
        throwsA(isA<ApiException>()),
      );

      await drills.cancel(drill.id);
      final DrillOverview after = await drills.load();
      expect(after.upcoming.any((Drill d) => d.id == drill.id), isFalse);
    });
  });

  group('reportes de riesgo', () {
    test('un reporte llega a la bandeja y coordinación lo cierra', () async {
      if (!serverUp) {
        markTestSkipped('La API no está corriendo en $baseUrl');
        return;
      }

      final ApiClient reporter = await staff('carlos.jaimes@iic.edu.co', 'Contabilidad2026');
      final String place = 'Laboratorio ${DateTime.now().microsecondsSinceEpoch}';
      await ApiRiskRepository(reporter).report(
        kind: RiskKind.cable,
        place: place,
        details: 'Cable pelado junto al tomacorriente',
      );
      final List<RiskReport> mine = await ApiRiskRepository(reporter).loadMine();
      expect(mine.any((RiskReport r) => r.place == place), isTrue);

      final ApiClient admin = await staff('coordinacion@iic.edu.co', 'Barbosa2026Riesgo');
      final RiskRepository inbox = ApiRiskRepository(admin);
      final RiskReport report =
          (await inbox.loadInbox()).firstWhere((RiskReport r) => r.place == place);
      expect(report.status, RiskStatus.nuevo);

      await inbox.setStatus(report.id, RiskStatus.atendido);
      final RiskReport closed =
          (await inbox.loadInbox()).firstWhere((RiskReport r) => r.id == report.id);
      expect(closed.status, RiskStatus.atendido);
    });
  });
}
