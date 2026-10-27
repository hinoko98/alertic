@Tags(<String>['integracion'])
library;

import 'dart:io';

import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/coordination/data/api_coordination_repository.dart';
import 'package:alertic/features/coordination/domain/coordination_repository.dart';
import 'package:alertic/features/onboarding/data/api_credentials_repository.dart';
import 'package:alertic/features/onboarding/data/api_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:alertic/features/panel/data/api_panel_repository.dart';
import 'package:alertic/features/panel/domain/panel_repository.dart';
import 'package:alertic/features/alerts/data/api_alert_repository.dart';
import 'package:alertic/features/teacher/data/api_teacher_repository.dart';
import 'package:alertic/features/teacher/domain/teacher_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coordinación contra el servidor de verdad: actualización de la alerta,
/// brigadista para quien pidió ayuda, listas entregadas, tarea del docente y
/// compañeros de apoyo.
///
/// Necesita el servidor con la matrícula de prueba (`npm run seed:demo`) y se
/// salta si no está.
void main() {
  const String baseUrl = String.fromEnvironment('ALERTIC_API', defaultValue: 'http://localhost:3001');

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

  Future<ApiClient> staff(String email, String password) async {
    final ApiClient client = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
    final (Credentials? built, String? problem) = Credentials.tryBuild(email: email, password: password);
    if (built == null) throw StateError('credenciales de prueba inválidas: $problem');
    await ApiCredentialsRepository(client).signIn(built);
    return client;
  }

  Future<String> myId(ApiClient client) async =>
      ((await client.get('/auth/me'))['profile'] as Map<String, dynamic>)['id'] as String;

  test('durante una alerta y antes: todo lo de coordinación llega y vuelve del servidor', () async {
    if (!serverUp) {
      markTestSkipped('La API no está corriendo en $baseUrl');
      return;
    }

    final ApiClient admin = await staff('coordinacion@iic.edu.co', 'Barbosa2026Riesgo');
    final ApiClient carlos = await staff('carlos.jaimes@iic.edu.co', 'Contabilidad2026');
    final CoordinationRepository coordination = ApiCoordinationRepository(admin);
    final PanelRepository panel = ApiPanelRepository(admin, ApiAlertRepository(admin));
    final String carlosId = await myId(carlos);

    // Un estudiante con un código recién emitido por coordinación, como en el
    // colegio cuando alguien perdió el carné.
    final CommunityMember sofia =
        (await panel.loadCommunity(role: 'estudiante', query: 'Sofía')).first;
    final String code = await panel.renewCode(sofia.id);
    final ApiClient student = ApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 8));
    await ApiEnrollmentRepository(student).confirmIdentity(PersonalCode.tryParse(code)!);

    // Antes: la tarea del docente y los compañeros de apoyo.
    await coordination.saveEmergencyTask(
      carlosId,
      const EmergencyTask(title: 'Guiar a 10° B al Punto A', detail: 'Por la escalera sur'),
    );
    expect((await coordination.loadEmergencyTask(carlosId))?.title, 'Guiar a 10° B al Punto A');
    final CommunityMember laura =
        (await panel.loadCommunity(role: 'estudiante', query: 'Laura')).first;
    await coordination.addSupportBuddy(laura.id, sofia.id);
    expect((await coordination.loadSupportPlan(laura.id)).buddies.map((SupportBuddy b) => b.id), contains(sofia.id));
    await coordination.removeSupportBuddy(laura.id, sofia.id);
    await coordination.clearEmergencyTask(carlosId);
    expect(await coordination.loadEmergencyTask(carlosId), isNull);

    // Durante: una alerta, alguien pide ayuda, coordinación actualiza y manda a Carlos.
    final Alert alert = await ApiTeacherRepository(admin).issueAlert(
      const AlertDraft(
        level: AlertLevel.roja,
        hazard: Hazard.sismo,
        title: 'SISMO',
        scope: 'Todo el instituto',
        instructions: <String>['Sal en fila'],
        meetingPoint: 'P1',
        drill: true,
      ),
    );
    try {
      await student.post(
        '/alerts/${alert.id}/reports',
        body: <String, dynamic>{'status': 'necesita_ayuda', 'location': 'salon', 'helpKind': 'herido'},
      );

      final Alert? updated = await coordination.sendAlertNote(alert.id, 'El bloque B ya está despejado.');
      expect(updated?.coordinatorNote, 'El bloque B ya está despejado.');

      final List<Responder> responders = await coordination.loadResponders();
      expect(responders.map((Responder r) => r.id), contains(carlosId));
      await coordination.assignHelp(alert.id, sofia.id, carlosId);
      final List<HelpAssignment> assigned = await coordination.loadHelpAssignments(alert.id);
      expect(assigned.single.personId, sofia.id);
      expect(assigned.single.assignee, 'Carlos Jaimes Duarte');

      await ApiTeacherRepository(carlos).submitRoster(alert.id, '10° B');
      final List<DeliveredRoster> rosters = await coordination.loadDeliveredRosters(alert.id);
      expect(rosters.map((DeliveredRoster r) => r.grade), contains('10° B'));
    } finally {
      await ApiTeacherRepository(admin).endAlert(alert.id);
    }
  });
}
