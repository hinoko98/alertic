import '../../alerts/domain/hazard.dart';

/// En qué va un reporte de emergencia.
enum IncidentStatus {
  /// Recién llegó y nadie lo ha visto.
  open(wire: 'nuevo'),

  /// Alguien fue a verlo y lo resolvió.
  handled(wire: 'atendido'),

  /// Se vio y no ameritaba nada.
  dismissed(wire: 'descartado'),

  /// Coordinación lo convirtió en una alerta para todo el colegio.
  escalated(wire: 'escalado');

  const IncidentStatus({required this.wire});

  final String wire;

  static IncidentStatus? tryParse(String? value) {
    for (final IncidentStatus status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// Un reporte de emergencia que hizo alguien de la comunidad.
///
/// Un estudiante ve humo y lo avisa. **Nunca emite una alerta**: avisa, y un
/// docente o coordinación decide si se convierte en una para 1.248 personas.
class Incident {
  const Incident({
    required this.id,
    required this.hazard,
    required this.status,
    required this.createdAt,
    required this.reporterName,
    this.reporterGrade,
    this.details,
    this.handledBy,
  });

  final String id;
  final Hazard hazard;
  final IncidentStatus status;
  final DateTime createdAt;

  /// Quién lo reportó. Lo ven docentes y coordinación, para saber a dónde ir.
  final String reporterName;
  final String? reporterGrade;

  /// Una frase corta que escribió quien reportó, si quiso: «detrás del bloque B».
  final String? details;

  /// Quién lo resolvió, si ya se resolvió.
  final String? handledBy;

  bool get isOpen => status == IncidentStatus.open;
}

/// Reportes de emergencia.
///
/// Una sola interfaz con operaciones de dos públicos distintos: **quien
/// reporta** (estudiante, docente) y **quien atiende** (docente, coordinación).
/// El servidor es quien decide qué ve cada quien: un docente solo recibe los
/// reportes de sus grupos, y quien reporta no ve los de nadie más.
abstract interface class IncidentRepository {
  /// Avisa de una emergencia.
  ///
  /// Lanza si **no** llegó al servidor. Es lo que importa de esta operación: un
  /// estudiante que reporta un incendio y ve «enviado» sin que haya salido nada
  /// cree que ya avisó, y nadie se entera.
  Future<void> report(Hazard hazard, {String? details});

  /// Los reportes sin atender que le tocan a quien pregunta.
  Future<List<Incident>> loadOpen();

  /// Da un reporte por atendido o descartado.
  Future<void> handle(String incidentId, IncidentStatus status);
}

/// Cómo se nombra cada amenaza en un reporte: en singular y como cosa que pasa,
/// no como categoría («INCENDIO», no «INCENDIOS»).
extension HazardReportLabel on Hazard {
  String get reportLabel => switch (this) {
        Hazard.lluvia => 'LLUVIA FUERTE',
        Hazard.inundacion => 'INUNDACIÓN',
        Hazard.sismo => 'SISMO',
        Hazard.incendio => 'INCENDIO',
      };
}
