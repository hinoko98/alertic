import 'alert_level.dart';
import 'hazard.dart';

/// Una alerta emitida por el colegio.
///
/// Solo se construye con [Alert.validated], que rechaza lo que llegue mal
/// armado: una alerta incompleta en una emergencia es peor que ninguna, porque
/// deja a la persona sin saber qué hacer.
class Alert {
  const Alert._({
    required this.id,
    required this.level,
    required this.hazard,
    required this.title,
    required this.scope,
    required this.instructions,
    required this.issuedAt,
    this.meetingPoint,
    this.coordinatorNote,
    this.issuedBy,
  });

  /// Máximos que acepta la app. Un texto más largo no se recorta en pantalla:
  /// se rechaza la alerta, porque significa que algo viene mal desde el panel.
  static const int maxTitleLength = 60;
  static const int maxInstructions = 6;
  static const int maxInstructionLength = 120;

  final String id;
  final AlertLevel level;
  final Hazard hazard;

  /// Qué pasa, en mayúsculas: `LLUVIA FUERTE`, `SISMO`.
  final String title;

  /// A quién cobija: `Todo el instituto`, `Bloque B`.
  final String scope;

  /// Punto de encuentro, cuando el nivel obliga a salir.
  final String? meetingPoint;

  /// Qué hacer, en orden. Cortas y numeradas.
  final List<String> instructions;

  /// Nota del coordinador de gestión del riesgo, si la hay.
  final String? coordinatorNote;

  /// Quién la emitió: un docente o coordinación.
  final String? issuedBy;

  final DateTime issuedAt;

  /// Construye la alerta validando cada campo.
  ///
  /// Lanza [InvalidAlertData] si algo no cuadra. Se usa tanto para los datos
  /// que llegan del servidor como para los de prueba: la validación no cambia
  /// según de dónde vengan.
  factory Alert.validated({
    required String? id,
    required AlertLevel? level,
    required Hazard? hazard,
    required String? title,
    required String? scope,
    required List<String>? instructions,
    required DateTime? issuedAt,
    String? meetingPoint,
    String? coordinatorNote,
    String? issuedBy,
  }) {
    final String safeId = _requireText(id, 'id', maxLength: 64);
    final String safeTitle = _requireText(title, 'title', maxLength: maxTitleLength);
    final String safeScope = _requireText(scope, 'scope', maxLength: maxTitleLength);

    if (level == null) {
      throw const InvalidAlertData('nivel de alerta desconocido');
    }
    if (hazard == null) {
      throw const InvalidAlertData('tipo de amenaza desconocido');
    }
    if (issuedAt == null) {
      throw const InvalidAlertData('la alerta no trae hora de emisión');
    }
    if (instructions == null || instructions.isEmpty) {
      throw const InvalidAlertData('la alerta no trae instrucciones');
    }
    if (instructions.length > maxInstructions) {
      throw const InvalidAlertData('la alerta trae demasiadas instrucciones');
    }

    final List<String> safeInstructions = instructions
        .map((String step) =>
            _requireText(step, 'instrucción', maxLength: maxInstructionLength))
        .toList(growable: false);

    if (level.requiresResponse && (meetingPoint == null || meetingPoint.trim().isEmpty)) {
      throw const InvalidAlertData(
        'una alerta roja tiene que decir a qué punto de encuentro ir',
      );
    }

    return Alert._(
      id: safeId,
      level: level,
      hazard: hazard,
      title: safeTitle,
      scope: safeScope,
      instructions: safeInstructions,
      issuedAt: issuedAt,
      meetingPoint: meetingPoint?.trim(),
      coordinatorNote: _optionalText(coordinatorNote, maxLength: 240),
      issuedBy: _optionalText(issuedBy, maxLength: 80),
    );
  }

  /// Exige texto con contenido y recorta espacios. Quita caracteres de control
  /// para que nada de lo que llegue del servidor altere cómo se ve la pantalla.
  static String _requireText(
    String? value,
    String field, {
    required int maxLength,
  }) {
    final String clean = _clean(value);
    if (clean.isEmpty) {
      throw InvalidAlertData('la alerta no trae $field');
    }
    if (clean.length > maxLength) {
      throw InvalidAlertData('$field viene más largo de lo que cabe en pantalla');
    }
    return clean;
  }

  static String? _optionalText(String? value, {required int maxLength}) {
    final String clean = _clean(value);
    if (clean.isEmpty) {
      return null;
    }
    return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
  }

  static String _clean(String? value) {
    if (value == null) {
      return '';
    }
    return value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
  }

  /// Hora en formato corto para el encabezado: `9:28`.
  String get issuedAtLabel {
    final String minutes = issuedAt.minute.toString().padLeft(2, '0');
    return '${issuedAt.hour}:$minutes';
  }
}

/// La alerta que llegó no se puede mostrar.
class InvalidAlertData implements Exception {
  const InvalidAlertData(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidAlertData: $reason';
}
