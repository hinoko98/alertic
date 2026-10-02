import 'package:alertic/features/alerts/domain/safety_report.dart';
import 'package:alertic/features/guardian/domain/guardian_repository.dart';

/// Hijos de prueba para recorrer el bloque E sin backend.
///
/// Reproduce el caso del diseño: una hija que ya confirmó y un hijo de sexto
/// que no tiene celular, donde la docente está pasando lista.
class FakeGuardianRepository implements GuardianRepository {
  FakeGuardianRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  @override
  Future<List<ChildStatus>> loadChildren(String? alertId) async {
    await Future<void>.delayed(latency);

    return <ChildStatus>[
      ChildStatus(
        fullName: 'Laura Camila Pérez Gómez',
        grade: '10° B',
        shift: 'Mañana',
        homeroomTeacher: 'Carlos Jaimes',
        meetingPoint: 'P1 · Cancha central',
        status: alertId == null ? null : SafetyStatus.safe,
        location: alertId == null ? null : ReportedLocation.atMeetingPoint,
        reportedAt: alertId == null ? null : DateTime.now(),
      ),
      const ChildStatus(
        fullName: 'Andrés Felipe Pérez Gómez',
        grade: '6° A',
        shift: 'Mañana',
        homeroomTeacher: 'Nubia Silva',
        meetingPoint: 'P1 · Cancha central',
        note: 'No tiene celular. Su docente, Prof. Nubia Silva, está pasando '
            'lista.',
      ),
    ];
  }

  @override
  Future<String?> loadSchoolPhone() async {
    await Future<void>.delayed(latency);
    // Número de la maqueta, solo para el modo de prueba. Con servidor, lo
    // publica el colegio.
    return '(607) 748 0000';
  }
}
