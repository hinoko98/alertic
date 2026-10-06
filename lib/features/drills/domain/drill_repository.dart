import '../../alerts/domain/hazard.dart';

/// Un simulacro programado.
class Drill {
  const Drill({
    required this.id,
    required this.hazard,
    required this.scheduledAt,
    required this.scope,
    this.note,
  });

  final String id;
  final Hazard hazard;
  final DateTime scheduledAt;
  final String scope;
  final String? note;
}

/// Cómo salió un simulacro que ya se hizo.
class DrillResult {
  const DrillResult({
    required this.alertId,
    required this.hazard,
    required this.at,
    required this.schoolPercent,
    this.mySeconds,
    this.onTime,
  });

  final String alertId;
  final Hazard hazard;
  final DateTime at;

  /// Lo que tardó esta persona en confirmar que estaba a salvo. Nulo si no lo
  /// hizo.
  final int? mySeconds;

  /// ¿Llegó dentro de la meta?
  final bool? onTime;

  /// Qué porcentaje del colegio confirmó dentro de la meta.
  final int schoolPercent;
}

/// El calendario y los resultados de los simulacros.
class DrillOverview {
  const DrillOverview({
    required this.goalSeconds,
    required this.upcoming,
    required this.history,
  });

  /// La meta: confirmar a salvo dentro de este tiempo.
  final int goalSeconds;
  final List<Drill> upcoming;
  final List<DrillResult> history;

  Drill? get next => upcoming.isEmpty ? null : upcoming.first;
  DrillResult? get last => history.isEmpty ? null : history.first;
}

/// Simulacros: programarlos (coordinación) y ver cómo salió cada uno.
abstract interface class DrillRepository {
  Future<DrillOverview> load();

  /// Programa un simulacro. Solo coordinación.
  Future<Drill> schedule({
    required Hazard hazard,
    required DateTime at,
    String scope = 'Todo el colegio',
    String? note,
  });

  /// Cancela uno que todavía no se hizo. Solo coordinación.
  Future<void> cancel(String id);
}
