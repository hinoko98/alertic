/// Qué apoyo necesita una persona para salir en una evacuación.
enum SupportNeed {
  mobility(wire: 'movilidad', label: 'Movilidad reducida'),
  lowVision(wire: 'vision', label: 'Baja visión'),
  hearing(wire: 'audicion', label: 'Discapacidad auditiva'),
  temporary(wire: 'temporal', label: 'Temporal (yeso, muletas)');

  const SupportNeed({required this.wire, required this.label});

  final String wire;
  final String label;

  static SupportNeed? tryParse(String? value) {
    for (final SupportNeed need in values) {
      if (need.wire == value) return need;
    }
    return null;
  }
}

/// Lo que la persona pidió: el apoyo y cómo quiere que le llegue la alerta.
class SupportSettings {
  const SupportSettings({
    required this.need,
    this.vibrate = true,
    this.flash = false,
    this.readAloud = false,
  });

  final SupportNeed need;

  /// Vibrar fuerte y en patrón, sin depender del sonido.
  final bool vibrate;

  /// Destello con la linterna.
  final bool flash;

  /// Leer las instrucciones en voz alta.
  final bool readAloud;

  SupportSettings copyWith({
    SupportNeed? need,
    bool? vibrate,
    bool? flash,
    bool? readAloud,
  }) {
    return SupportSettings(
      need: need ?? this.need,
      vibrate: vibrate ?? this.vibrate,
      flash: flash ?? this.flash,
      readAloud: readAloud ?? this.readAloud,
    );
  }
}

/// Alguien que va por la persona en cada alerta: un compañero que asignó el
/// colegio o su director de grupo.
class SupportBuddy {
  const SupportBuddy({required this.fullName, required this.detail});

  final String fullName;

  /// `Compañero · 9.° B` o `Director de grupo`.
  final String detail;
}

/// Lo que el colegio sabe del apoyo de esta persona.
class SupportOverview {
  const SupportOverview({this.settings, this.buddies = const <SupportBuddy>[]});

  /// `null` si la persona no pidió apoyo.
  final SupportSettings? settings;
  final List<SupportBuddy> buddies;
}
