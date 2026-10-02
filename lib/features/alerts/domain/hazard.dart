/// Amenazas que cubre el sistema. Salen del plan de gestión del riesgo del
/// colegio; agregar una es una decisión del comité, no de la app.
enum Hazard {
  lluvia(wire: 'lluvia', label: 'LLUVIAS'),
  inundacion(wire: 'inundacion', label: 'INUNDACIÓN'),
  sismo(wire: 'sismo', label: 'SISMOS'),
  incendio(wire: 'incendio', label: 'INCENDIOS');

  const Hazard({required this.wire, required this.label});

  final String wire;
  final String label;

  static Hazard? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim().toLowerCase();
    for (final Hazard hazard in values) {
      if (hazard.wire == normalized) {
        return hazard;
      }
    }
    return null;
  }
}
