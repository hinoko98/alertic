import 'package:alertic/features/alerts/domain/meeting_point.dart';
import 'package:alertic/features/session/domain/session.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/domain/personal_code.dart';
import 'package:alertic/features/onboarding/data/enrollment_repository.dart';

/// Matrícula de prueba, en memoria, con las personas del diseño.
///
/// Sirve para recorrer el registro completo sin backend. Se reemplaza por la
/// implementación HTTP sin tocar las pantallas.
class FakeEnrollmentRepository implements EnrollmentRepository {
  FakeEnrollmentRepository({this.latency = const Duration(milliseconds: 700)});

  /// Demora simulada, para que se vea el estado de carga como con red real.
  final Duration latency;

  /// Códigos ya usados en esta sesión. En el backend esto vive en la base de
  /// datos: el código es de un solo uso.
  final Set<String> _redeemed = <String>{};

  /// Punto de encuentro del Bloque A, según el plan de evacuación del colegio.
  static const MeetingPoint _cancha = MeetingPoint(
    code: 'P1',
    name: 'Cancha central',
    routeHint: 'Desde Aula 7 · 60 m por el corredor sur',
    distanceMeters: 60,
    walkMinutes: 1,
  );

  static final Map<String, Enrollment> _enrollments = <String, Enrollment>{
    '7K4P2Q9M': StudentEnrollment(
      code: PersonalCode.tryParse('7K4P2Q9M')!,
      fullName: 'Laura Camila Pérez Gómez',
      grade: '10° B',
      shift: 'Mañana',
      homeroomTeacher: 'Carlos Jaimes',
      classroom: 'Aula 7 · Bloque A',
      meetingPoint: _cancha,
      guardians: const <GuardianLink>[
        GuardianLink(fullName: 'Martha Gómez', relationship: 'Madre'),
        GuardianLink(fullName: 'Jorge Pérez', relationship: 'Padre'),
      ],
    ),
    '3HW8X4LD': GuardianEnrollment(
      code: PersonalCode.tryParse('3HW8X4LD')!,
      fullName: 'Martha Gómez Ardila',
      maskedPhone: '310 ••• 4521',
      children: const <LinkedStudent>[
        LinkedStudent(
          fullName: 'Laura Camila Pérez Gómez',
          grade: '10° B',
          shift: 'Mañana',
        ),
        LinkedStudent(
          fullName: 'Andrés Felipe Pérez Gómez',
          grade: '6° A',
          shift: 'Mañana',
        ),
      ],
    ),
    '8JK3T6RE': StudentEnrollment(
      code: PersonalCode.tryParse('8JK3T6RE')!,
      fullName: 'Sofía Arenas Villamizar',
      grade: '10° B',
      shift: 'Mañana',
      homeroomTeacher: 'Carlos Jaimes',
      classroom: 'Aula 7 · Bloque A',
      meetingPoint: _cancha,
      guardians: const <GuardianLink>[
        GuardianLink(fullName: 'Luz Villamizar', relationship: 'Madre'),
      ],
    ),
  };

  @override
  Future<Enrollment> findByCode(PersonalCode code) async {
    await Future<void>.delayed(latency);

    if (_redeemed.contains(code.digits)) {
      throw const CodeAlreadyUsed();
    }

    final Enrollment? enrollment = _enrollments[code.digits];
    if (enrollment == null) {
      throw const CodeNotFound();
    }
    return enrollment;
  }

  @override
  Future<Session> confirmIdentity(PersonalCode code) async {
    await Future<void>.delayed(latency);

    final Enrollment? enrollment = _enrollments[code.digits];
    if (enrollment == null) {
      throw const CodeNotFound();
    }
    if (_redeemed.contains(code.digits)) {
      throw const CodeAlreadyUsed();
    }
    _redeemed.add(code.digits);

    // El token lo emite el servidor. Este es de mentira y por eso dura poco:
    // que nadie se acostumbre a tratarlo como real.
    return Session(
      token: 'demo-${code.digits}',
      profile: enrollment,
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }
}
