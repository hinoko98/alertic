import 'fake_alert_repository.dart';
import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/safety_report.dart';
import 'package:alertic/features/teacher/domain/teacher_repository.dart';

/// Grupo de prueba para recorrer el bloque D sin backend.
class FakeTeacherRepository implements TeacherRepository {
  FakeTeacherRepository(
    this._alerts, {
    this.latency = const Duration(milliseconds: 400),
  });

  final FakeAlertRepository _alerts;
  final Duration latency;

  /// Estado de cada estudiante, por alerta.
  final Map<String, Map<String, SafetyStatus>> _responses =
      <String, Map<String, SafetyStatus>>{};

  static const List<String> _students = <String>[
    'Laura Camila Pérez Gómez',
    'Sofía Arenas Villamizar',
    'Juan Diego Rincón Parra',
    'Mateo Cárdenas Ruiz',
    'Valentina Ortiz Pinzón',
    'Daniel Mantilla Serrano',
  ];

  @override
  Future<Alert> issueAlert(AlertDraft draft) async {
    await Future<void>.delayed(latency);
    return _alerts.publish(draft);
  }

  @override
  Future<void> endAlert(String alertId) async {
    await Future<void>.delayed(latency);
    _alerts.clear();
  }

  @override
  Future<List<RosterEntry>> loadRoster(String alertId, String grade) async {
    await Future<void>.delayed(latency);

    // Se siembra una respuesta plausible la primera vez: algunos a salvo, uno
    // pidiendo ayuda y otros sin responder, que es como se ve de verdad.
    final Map<String, SafetyStatus> responses = _responses.putIfAbsent(
      alertId,
      () => <String, SafetyStatus>{
        _students[0]: SafetyStatus.safe,
        _students[5]: SafetyStatus.safe,
        _students[2]: SafetyStatus.needsHelp,
      },
    );

    return <RosterEntry>[
      for (final String name in _students)
        RosterEntry(
          personId: name,
          fullName: name,
          status: responses[name],
          location: responses[name] == null
              ? null
              : ReportedLocation.atMeetingPoint,
          reportedAt: responses[name] == null ? null : DateTime.now(),
        ),
    ];
  }

  @override
  Future<void> markSafe(String alertId, String personId) async {
    await Future<void>.delayed(latency);
    _responses.putIfAbsent(alertId, () => <String, SafetyStatus>{})[personId] =
        SafetyStatus.safe;
  }

  @override
  Future<int?> loadReach() async {
    await Future<void>.delayed(latency);
    // Cifra del colegio de la maqueta: solo para el modo de prueba.
    return 1248;
  }
}
