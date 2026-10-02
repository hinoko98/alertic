import '../../session/domain/session.dart';
import '../domain/enrollment.dart';
import '../domain/personal_code.dart';

/// Acceso a la matrícula que cargó el colegio.
///
/// Hoy lo resuelve [FakeEnrollmentRepository] en memoria. Cuando exista el
/// backend, se implementa esta misma interfaz contra la API y no cambia nada
/// de la interfaz de usuario.
abstract interface class EnrollmentRepository {
  /// Busca el perfil al que apunta el código.
  ///
  /// Lanza un [EnrollmentFailure] si el código no existe, ya se usó o no se
  /// pudo consultar.
  Future<Enrollment> findByCode(PersonalCode code);

  /// Quema el código y abre la sesión.
  ///
  /// El servidor es quien marca el código como usado y quien emite el token con
  /// el rol: hacerlo en el celular permitiría usar un mismo código dos veces o
  /// entrar con un rol que no corresponde.
  Future<Session> confirmIdentity(PersonalCode code);
}
