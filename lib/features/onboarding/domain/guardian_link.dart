import 'dart:math';

import '../../session/domain/session.dart';
import 'person_name.dart';
import 'school.dart';

/// El parentesco del acudiente con el estudiante, tal como lo lee la persona y
/// como lo guarda el colegio.
enum GuardianRelationship {
  mother('Madre'),
  father('Padre'),
  grandparent('Abuelo o abuela'),
  other('Otro acudiente');

  const GuardianRelationship(this.label);

  final String label;
}

/// Tipos de documento que acepta el registro del acudiente.
enum GuardianDocumentType {
  cc('C.C.', 'CC'),
  ce('C.E.', 'CE'),
  passport('Pasaporte', 'PA');

  const GuardianDocumentType(this.label, this.wire);

  final String label;
  final String wire;
}

/// El estudiante que el servidor encontró con ese documento.
///
/// El apellido llega tapado (`Valentina R••••• G•••••`) y el documento con solo
/// los cuatro últimos dígitos: quien aún no demostró ser el acudiente no debe
/// ver más de lo necesario para reconocer a su hijo.
class StudentMatch {
  const StudentMatch({
    required this.maskedName,
    required this.grade,
    required this.shift,
    required this.maskedDocument,
    required this.document,
  });

  final String maskedName;
  final String grade;
  final String shift;
  final String maskedDocument;

  /// Lo que la persona escribió para buscarlo. Se vuelve a mandar al pedir la
  /// vinculación; no se muestra.
  final String document;

  String get firstName => maskedName.split(' ').first;

  String get initials => PersonName.initials(maskedName.replaceAll('•', ''));
}

/// Los datos de contacto del acudiente.
class GuardianContact {
  const GuardianContact({
    required this.fullName,
    required this.documentType,
    required this.document,
    required this.phone,
    this.email = '',
  });

  final String fullName;
  final GuardianDocumentType documentType;
  final String document;
  final String phone;
  final String email;
}

/// Lo que se va armando a lo largo de los cuatro pasos del registro.
class GuardianDraft {
  GuardianDraft({
    required this.schoolCode,
    required this.school,
    this.children = const <StudentMatch>[],
    this.relationship = GuardianRelationship.mother,
    String? claimSecret,
  }) : claimSecret = claimSecret ?? generateClaimSecret();

  final String schoolCode;
  final School school;

  /// Los hijos ya confirmados; el que se está mirando no está aquí todavía.
  final List<StudentMatch> children;
  final GuardianRelationship relationship;

  /// Lo genera este celular y solo el servidor guarda su hash. Con él, y solo
  /// con él, se reclama la sesión cuando el colegio aprueba la solicitud: quien
  /// conozca los documentos pero no este secreto no puede entrar.
  final String claimSecret;

  GuardianDraft copyWith({
    List<StudentMatch>? children,
    GuardianRelationship? relationship,
  }) {
    return GuardianDraft(
      schoolCode: schoolCode,
      school: school,
      children: children ?? this.children,
      relationship: relationship ?? this.relationship,
      claimSecret: claimSecret,
    );
  }

  static String generateClaimSecret() {
    const String alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final Random random = Random.secure();
    return List<String>.generate(
      43,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

/// Una solicitud ya enviada al colegio, por un hijo.
class LinkRequest {
  const LinkRequest({
    required this.id,
    required this.approved,
    required this.student,
  });

  final String id;

  /// El colegio ya la aprobó (el servidor puede hacerlo solo si el documento ya
  /// figuraba en la matrícula).
  final bool approved;
  final StudentMatch student;
}

/// Qué respondió el servidor cuando el celular preguntó por su solicitud.
sealed class ClaimOutcome {
  const ClaimOutcome();
}

/// El colegio todavía no la revisa.
final class ClaimPending extends ClaimOutcome {
  const ClaimPending();
}

/// El colegio no aprobó la vinculación.
final class ClaimRejected extends ClaimOutcome {
  const ClaimRejected();
}

/// Aprobada: trae la sesión ya abierta.
final class ClaimApproved extends ClaimOutcome {
  const ClaimApproved(this.session);

  final Session session;
}
