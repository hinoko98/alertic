import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/coordination/domain/coordination_repository.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';

/// Coordinación en memoria, para recorrer el panel sin servidor.
class FakeCoordinationRepository implements CoordinationRepository {
  /// Las actualizaciones mandadas, en orden, para que la prueba las vea.
  final List<String> notes = <String>[];

  final List<Responder> responders = const <Responder>[
    Responder(id: 'carlos', fullName: 'Carlos Jaimes Duarte', isCoordination: false),
    Responder(id: 'nubia', fullName: 'Nubia Silva Castro', isCoordination: false),
    Responder(id: 'rectoria', fullName: 'Coordinación IIC', isCoordination: true),
  ];

  final Map<String, HelpAssignment> _assignments = <String, HelpAssignment>{};
  final List<DeliveredRoster> rosters = <DeliveredRoster>[];
  final Map<String, EmergencyTask> tasks = <String, EmergencyTask>{};
  final Map<String, List<SupportBuddy>> buddies = <String, List<SupportBuddy>>{};
  final Map<String, String> needs = <String, String>{};

  @override
  Future<Alert?> sendAlertNote(String alertId, String note) async {
    notes.add(note);
    // La alerta con la nota la trae el canal en vivo; aquí basta con registrarla.
    return null;
  }

  @override
  Future<List<Responder>> loadResponders() async => responders;

  @override
  Future<void> assignHelp(String alertId, String personId, String assigneeId) async {
    _assignments[personId] = HelpAssignment(
      personId: personId,
      assigneeId: assigneeId,
      assignee: responders.firstWhere((Responder r) => r.id == assigneeId).fullName,
      assignedAt: DateTime.now(),
    );
  }

  @override
  Future<List<HelpAssignment>> loadHelpAssignments(String alertId) async =>
      _assignments.values.toList();

  @override
  Future<List<DeliveredRoster>> loadDeliveredRosters(String alertId) async => rosters;

  @override
  Future<EmergencyTask?> loadEmergencyTask(String teacherId) async => tasks[teacherId];

  @override
  Future<void> saveEmergencyTask(String teacherId, EmergencyTask task) async => tasks[teacherId] = task;

  @override
  Future<void> clearEmergencyTask(String teacherId) async => tasks.remove(teacherId);

  @override
  Future<SupportPlan> loadSupportPlan(String studentId) async =>
      SupportPlan(need: needs[studentId], buddies: List<SupportBuddy>.of(buddies[studentId] ?? const <SupportBuddy>[]));

  @override
  Future<void> addSupportBuddy(String studentId, String buddyId) async {
    buddies.putIfAbsent(studentId, () => <SupportBuddy>[]).add(SupportBuddy(id: buddyId, fullName: buddyId));
  }

  @override
  Future<void> removeSupportBuddy(String studentId, String buddyId) async {
    buddies[studentId]?.removeWhere((SupportBuddy b) => b.id == buddyId);
  }
}
