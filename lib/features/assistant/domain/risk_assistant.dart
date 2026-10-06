import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/protocol.dart';

/// A dónde manda una respuesta del asistente, además de contestar.
enum AssistantAction {
  /// Abrir «Reportar un riesgo».
  reportRisk,

  /// Abrir el chat con el colegio.
  talkToSomeone,
}

/// Lo que contesta el asistente.
class AssistantReply {
  const AssistantReply(this.text, {this.action});

  final String text;
  final AssistantAction? action;
}

/// El asistente de riesgos.
///
/// **No inventa nada.** Contesta con los pasos del protocolo que coordinación
/// publicó para cada amenaza —los mismos de la pestaña Guía— y, si no entiende,
/// lo dice y ofrece hablar con una persona. Corre en el celular, sin conexión: es
/// la ayuda que tiene que estar cuando no hay señal.
///
/// Por eso es una lista de reglas y no un modelo: ante una emergencia importa más
/// que la respuesta sea exactamente la del plan del colegio que que suene natural.
class RiskAssistant {
  const RiskAssistant(this.protocols);

  final List<Protocol> protocols;

  /// Frases cortas que se ofrecen como botones.
  static const List<String> quickReplies = <String>[
    'Sismo',
    'Inundación',
    'Incendio',
    'Lluvias fuertes',
    'Reportar un riesgo',
    'Hablar con una persona',
  ];

  static const String greeting =
      'Hola, soy el asistente de riesgos de ALERTIC. Puedo decirte qué hacer '
      'ante lluvias, inundaciones, sismos o incendios, y ayudarte a reportar '
      'algo raro en el colegio.';

  static const Map<Hazard, List<String>> _keywords = <Hazard, List<String>>{
    Hazard.sismo: <String>['sismo', 'temblor', 'terremoto', 'tiembla', 'temblando'],
    Hazard.inundacion: <String>['inunda', 'rio', 'río', 'crece', 'desborda', 'agua sube'],
    Hazard.incendio: <String>['incendio', 'fuego', 'humo', 'quema', 'llamas', 'candela'],
    Hazard.lluvia: <String>['lluvia', 'llueve', 'tormenta', 'rayo', 'rayos', 'aguacero', 'granizo'],
  };

  AssistantReply answer(String question) {
    final String text = _normalize(question);

    if (_has(text, const <String>['persona', 'humano', 'coordinacion', 'coordinación', 'hablar con', 'docente', 'profe'])) {
      return const AssistantReply(
        'Claro. Te abro el chat con el colegio: te responde coordinación o tu '
        'director de grupo.',
        action: AssistantAction.talkToSomeone,
      );
    }
    if (_has(text, const <String>['reportar', 'reporte', 'riesgo', 'grieta', 'cable', 'gotera', 'raro', 'peligro'])) {
      return const AssistantReply(
        'Cuéntanos qué viste y dónde: llega al comité de gestión del riesgo. Te '
        'llevo a «Reportar un riesgo».',
        action: AssistantAction.reportRisk,
      );
    }

    for (final MapEntry<Hazard, List<String>> entry in _keywords.entries) {
      if (_has(text, entry.value)) {
        return _protocolReply(entry.key);
      }
    }

    return const AssistantReply(
      'No estoy seguro de haberte entendido. Elige un tema de los botones o '
      'escribe, por ejemplo, «qué hago si tiembla». Si prefieres, puedes '
      'hablar con una persona del colegio.',
    );
  }

  AssistantReply _protocolReply(Hazard hazard) {
    final Protocol? protocol = protocols
        .cast<Protocol?>()
        .firstWhere((Protocol? p) => p!.hazard == hazard, orElse: () => null);

    if (protocol == null || protocol.duringSteps.isEmpty) {
      return AssistantReply(
        'El colegio todavía no publicó el protocolo de ${hazard.label.toLowerCase()}. '
        'Habla con una persona de coordinación.',
        action: AssistantAction.talkToSomeone,
      );
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < protocol.duringSteps.length; i++) {
      buffer.writeln('${i + 1}. ${protocol.duringSteps[i]}');
    }
    buffer.write('Cuando estés a salvo, márcalo en la app para avisar a tu familia.');
    return AssistantReply(buffer.toString());
  }

  /// ¿Aparece alguna de [words] al principio de una palabra? Sin esto, «rio»
  /// (el río) se encontraba dentro de «serio» y contestaba lo que no era.
  static bool _has(String text, List<String> words) => words.any(
        (String word) =>
            RegExp(r'\b' + RegExp.escape(_normalize(word))).hasMatch(text),
      );

  static String _normalize(String raw) => raw
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .trim();
}
