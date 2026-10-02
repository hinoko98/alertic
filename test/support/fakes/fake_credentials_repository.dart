import 'package:alertic/features/session/domain/session.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:alertic/features/onboarding/domain/enrollment_failure.dart';
import 'package:alertic/features/onboarding/data/credentials_repository.dart';

/// Cuentas de prueba, para correr la app sin servidor.
///
/// Las contraseñas están aquí en claro, y eso está bien **porque no son
/// contraseñas de nadie**: son las mismas que siembra `npm run seed` en la base
/// de datos de desarrollo, y ahí sí viven hasheadas. En producción esta clase no
/// se usa: `AlerticApp` elige la implementación contra la API en cuanto hay un
/// servidor configurado.
class FakeCredentialsRepository implements CredentialsRepository {
  FakeCredentialsRepository({this.latency = const Duration(milliseconds: 500)});

  /// Se puede poner en cero en las pruebas, donde nadie mira una animación.
  final Duration latency;

  static final Map<String, _Account> _accounts = <String, _Account>{
    'carlos.jaimes@iic.edu.co': _Account(
      password: 'Contabilidad2026',
      profile: const TeacherEnrollment(
        fullName: 'Carlos Jaimes Duarte',
        subject: 'Contabilidad',
        groups: <String>['10° A', '10° B', '11° A'],
        homeroomGroup: '10° B',
        email: 'carlos.jaimes@iic.edu.co',
        groupSummaries: <GroupSummary>[
          GroupSummary(grade: '10° A', enrolled: 31, classroom: 'Aula 6 · Bloque A'),
          GroupSummary(grade: '10° B', enrolled: 34, classroom: 'Aula 7 · Bloque A'),
          GroupSummary(grade: '11° A', enrolled: 29, classroom: 'Aula 9 · Bloque B'),
        ],
      ),
    ),
    'nubia.silva@iic.edu.co': _Account(
      password: 'Matematicas2026',
      profile: const TeacherEnrollment(
        fullName: 'Nubia Silva Castro',
        subject: 'Matemáticas',
        groups: <String>['6° A', '7° B'],
        homeroomGroup: '6° A',
        email: 'nubia.silva@iic.edu.co',
        groupSummaries: <GroupSummary>[
          GroupSummary(grade: '6° A', enrolled: 36, classroom: 'Aula 2 · Bloque A'),
          GroupSummary(grade: '7° B', enrolled: 33, classroom: 'Aula 4 · Bloque A'),
        ],
      ),
    ),
    'coordinacion@iic.edu.co': _Account(
      password: 'Barbosa2026Riesgo',
      profile: const AdminEnrollment(
        fullName: 'Gloria Amparo Rueda Sánchez',
        scope: 'Todo el instituto',
        email: 'coordinacion@iic.edu.co',
      ),
    ),
  };

  /// Intentos fallidos, para que el doble también frene la fuerza bruta y las
  /// pruebas puedan comprobar ese comportamiento sin levantar el servidor.
  final Map<String, int> _failures = <String, int>{};

  static const int _maxFailures = 10;

  /// Contraseñas cambiadas durante esta sesión de prueba. Van aparte de
  /// `_accounts`, que es estático: cambiarlas ahí se le pegaría a la prueba
  /// siguiente.
  final Map<String, String> _changed = <String, String>{};

  String? _signedInEmail;

  @override
  Future<void> signOut() async => _signedInEmail = null;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);

    final String? email = _signedInEmail;
    if (email == null) {
      throw const EnrollmentUnavailable('no hay sesión');
    }
    if (currentPassword != _passwordOf(email)) {
      throw const WrongCurrentPassword();
    }
    if (newPassword.length < 10) {
      throw const PasswordRejected(
        'La contraseña nueva debe tener al menos 10 caracteres.',
      );
    }
    _changed[email] = newPassword;
  }

  String? _passwordOf(String email) => _changed[email] ?? _accounts[email]?.password;

  @override
  Future<Session> signIn(Credentials credentials) async {
    await Future<void>.delayed(latency);

    if ((_failures[credentials.email] ?? 0) >= _maxFailures) {
      throw const TooManyAttempts();
    }

    final _Account? account = _accounts[credentials.email];

    // Correo inexistente y contraseña mala fallan igual, como en el servidor.
    if (account == null || _passwordOf(credentials.email) != credentials.password) {
      _failures.update(
        credentials.email,
        (int count) => count + 1,
        ifAbsent: () => 1,
      );
      throw const InvalidCredentials();
    }

    _failures.remove(credentials.email);
    _signedInEmail = credentials.email;

    return Session(
      token: 'sesion-de-prueba-${account.profile.role.wire}',
      profile: account.profile,
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }
}

class _Account {
  const _Account({required this.password, required this.profile});

  final String password;
  final Enrollment profile;
}
