import 'package:flutter/material.dart';

import '../core/session/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/onboarding/domain/enrollment.dart';
import '../features/session/domain/session.dart';
import '../features/student/presentation/screens/evacuation_map_screen.dart';
import '../features/student/presentation/screens/guide_screen.dart';
import '../features/student/presentation/screens/profile_screen.dart';
import '../features/guardian/presentation/screens/guardian_home_screen.dart';
import '../features/panel/presentation/screens/community_tab.dart';
import '../features/panel/presentation/screens/emergency_tab.dart';
import '../features/panel/presentation/screens/history_tab.dart';
import '../features/panel/presentation/screens/protocols_tab.dart';
import '../features/student/presentation/screens/student_home_screen.dart';
import '../features/teacher/presentation/screens/teacher_home_screen.dart';

/// Una pestaña de la barra inferior.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

/// La app que ve cada rol.
///
/// Patrón creacional *Abstract Factory*: cada rol produce su propia familia de
/// pantallas, y quien las usa ([AppShell]) no sabe cuál rol está mostrando.
/// Agregar el docente o el acudiente es escribir una fábrica más, sin tocar el
/// shell ni la navegación.
abstract interface class RoleExperience {
  UserRole get role;

  /// Pestañas de este rol, en orden.
  List<AppDestination> buildDestinations(Session session);
}

/// Elige la fábrica según el rol **que trae la sesión del servidor**.
abstract final class RoleExperiences {
  static RoleExperience forRole(UserRole role) {
    return switch (role) {
      UserRole.estudiante => const StudentExperience(),
      UserRole.docente => const TeacherExperience(),
      UserRole.acudiente => const GuardianExperience(),
      UserRole.administrador => const AdminExperience(),
    };
  }
}

/// Bloque C del diseño: la app del estudiante.
///
/// Inicio y Mapa son las dos que se usan durante una emergencia; Guía es lo que
/// se consulta sin señal; Perfil guarda el historial y los datos del colegio.
final class StudentExperience implements RoleExperience {
  const StudentExperience();

  @override
  UserRole get role => UserRole.estudiante;

  @override
  List<AppDestination> buildDestinations(Session session) {
    final Enrollment profile = session.profile;
    if (profile is! StudentEnrollment) {
      // El rol y el perfil vienen juntos del servidor. Si no concuerdan, algo
      // está mal del otro lado y es preferible fallar que mostrar la app
      // equivocada a un menor.
      throw StateError('La sesión dice estudiante pero el perfil no lo es.');
    }

    return <AppDestination>[
      AppDestination(
        label: 'Inicio',
        icon: Icons.home_outlined,
        builder: (BuildContext context) => StudentHomeScreen(student: profile),
      ),
      AppDestination(
        label: 'Mapa',
        icon: Icons.map_outlined,
        builder: (BuildContext context) =>
            EvacuationMapScreen(student: profile),
      ),
      AppDestination(
        label: 'Guía',
        icon: Icons.menu_book_outlined,
        builder: (BuildContext context) => const GuideScreen(),
      ),
      AppDestination(
        label: 'Perfil',
        icon: Icons.person_outline,
        builder: (BuildContext context) => ProfileScreen(student: profile),
      ),
    ];
  }
}

/// Bloque D: la app del docente.
///
/// Tres pestañas, y la última es la cuenta. El docente usa esto con el edificio
/// moviéndose y 32 estudiantes mirándolo: cada pestaña de más es una decisión de
/// más, y por eso salir y cambiar la contraseña viven fuera del camino de la
/// emergencia.
final class TeacherExperience implements RoleExperience {
  const TeacherExperience();

  @override
  UserRole get role => UserRole.docente;

  @override
  List<AppDestination> buildDestinations(Session session) {
    final Enrollment profile = session.profile;
    if (profile is! TeacherEnrollment) {
      throw StateError('La sesión dice docente pero el perfil no lo es.');
    }

    return <AppDestination>[
      AppDestination(
        label: 'Inicio',
        icon: Icons.home_outlined,
        builder: (BuildContext context) => TeacherHomeScreen(teacher: profile),
      ),
      AppDestination(
        label: 'Guía',
        icon: Icons.menu_book_outlined,
        builder: (BuildContext context) => const GuideScreen(),
      ),
      AppDestination(
        label: 'Cuenta',
        icon: Icons.person_outline,
        builder: (BuildContext context) => AccountScreen(enrollment: profile),
      ),
    ];
  }
}

/// Bloque E: la app del acudiente.
///
/// Una pantalla de respuesta y otra para la cuenta. La familia no necesita
/// navegar: necesita una respuesta, y por eso Inicio es lo primero y casi lo
/// único; Cuenta está para salir y ver con qué número está registrada.
final class GuardianExperience implements RoleExperience {
  const GuardianExperience();

  @override
  UserRole get role => UserRole.acudiente;

  @override
  List<AppDestination> buildDestinations(Session session) {
    final Enrollment profile = session.profile;
    if (profile is! GuardianEnrollment) {
      throw StateError('La sesión dice acudiente pero el perfil no lo es.');
    }

    return <AppDestination>[
      AppDestination(
        label: 'Inicio',
        icon: Icons.home_outlined,
        builder: (BuildContext context) =>
            GuardianHomeScreen(guardian: profile),
      ),
      AppDestination(
        label: 'Cuenta',
        icon: Icons.person_outline,
        builder: (BuildContext context) => AccountScreen(enrollment: profile),
      ),
    ];
  }
}

/// Bloque F en el celular: el panel del colegio.
///
/// Son **las mismas cuatro pantallas** que corren en el computador de
/// coordinación, no una versión reducida: se adaptan al ancho (ver
/// [PanelLayout]) en vez de duplicarse. Duplicarlas significaría que el día que
/// cambie el tablero hay que acordarse de cambiarlo en dos sitios, y en una
/// emergencia la versión olvidada es la que alguien está mirando.
///
/// El administrador necesita esto en el bolsillo porque la emergencia no lo
/// espera en su escritorio: puede estar en el patio cuando haya que finalizar la
/// alerta o ver quién pidió ayuda.
final class AdminExperience implements RoleExperience {
  const AdminExperience();

  @override
  UserRole get role => UserRole.administrador;

  @override
  List<AppDestination> buildDestinations(Session session) {
    final Enrollment profile = session.profile;
    if (profile is! AdminEnrollment) {
      throw StateError('La sesión dice administrador pero el perfil no lo es.');
    }

    return <AppDestination>[
      AppDestination(
        label: 'Emergencia',
        icon: Icons.warning_amber_outlined,
        builder: (BuildContext context) => const EmergencyTab(),
      ),
      AppDestination(
        label: 'Comunidad',
        icon: Icons.groups_outlined,
        builder: (BuildContext context) => const CommunityTab(),
      ),
      AppDestination(
        label: 'Historial',
        icon: Icons.history,
        builder: (BuildContext context) => const HistoryTab(),
      ),
      AppDestination(
        label: 'Protocolos',
        icon: Icons.menu_book_outlined,
        builder: (BuildContext context) => const ProtocolsTab(),
      ),
      AppDestination(
        label: 'Cuenta',
        icon: Icons.person_outline,
        builder: (BuildContext context) => AccountScreen(enrollment: profile),
      ),
    ];
  }
}

/// Lo que ve un rol cuya app todavía no está construida.
///
/// Es una pantalla honesta a propósito: dice qué falta en vez de fingir que la
/// app está completa.
class RolePendingScreen extends StatelessWidget {
  const RolePendingScreen({
    required this.role,
    required this.detail,
    super.key,
  });

  final UserRole role;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'APP DE ${role.label}',
                style: AppTextStyles.eyebrow.copyWith(color: AppColors.brand),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('EN CONSTRUCCIÓN', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.md),
              Text(detail, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
