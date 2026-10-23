/// «¿Cómo te fue en la evacuación?», con tres opciones cerradas.
///
/// No es una evaluación de la persona: sirve para que coordinación mejore las
/// rutas. Por eso son tres botones y no un campo de texto.
enum EvacuationRating {
  good(wire: 'bien', label: 'Bien'),
  fair(wire: 'regular', label: 'Regular'),
  bad(wire: 'mal', label: 'Mal');

  const EvacuationRating({required this.wire, required this.label});

  final String wire;
  final String label;
}
