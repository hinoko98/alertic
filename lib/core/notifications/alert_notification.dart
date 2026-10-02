import '../../features/alerts/domain/alert_level.dart';

/// Qué avisa una notificación.
enum PushKind {
  alertaNueva(wire: 'alerta_nueva'),
  alertaFinalizada(wire: 'alerta_finalizada'),
  hijoNecesitaAyuda(wire: 'hijo_necesita_ayuda'),

  /// Un estudiante reportó una emergencia. Le llega a su director de grupo y a
  /// coordinación, que deciden si se convierte en alerta.
  reporteEmergencia(wire: 'reporte_emergencia');

  const PushKind({required this.wire});

  final String wire;

  static PushKind? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim().toLowerCase();
    for (final PushKind kind in values) {
      if (kind.wire == normalized) {
        return kind;
      }
    }
    return null;
  }
}

/// Una notificación que llegó de Firebase, ya revisada.
///
/// La carga de un push es **entrada no confiable**: viaja por la red y llega a
/// un aislado sin pantalla donde un error no se puede mostrar ni reportar. Por
/// eso [tryFrom] nunca lanza: devuelve `null` y no se dibuja nada, que es mejor
/// que un aviso a medias o un texto de mil caracteres empujando la pantalla.
///
/// Es la misma idea que `Alert.validated`, pero más estricta en un punto: aquí
/// no se rechaza por falta de datos opcionales, porque el detalle completo lo
/// trae la app al abrirse consultando `/alerts/active`. La notificación solo
/// tiene que alcanzar para decidir si suena y qué dice el renglón de arriba.
class AlertNotification {
  const AlertNotification._({
    required this.kind,
    required this.title,
    required this.body,
    required this.takesOverScreen,
    required this.isPrivate,
    this.alertId,
    this.level,
  });

  /// Máximos de lo que cabe en un aviso de Android sin que se corte raro.
  static const int maxTitleLength = 60;
  static const int maxBodyLength = 160;

  final PushKind kind;

  /// Alerta a la que se refiere. La app la vuelve a pedir al servidor al abrir:
  /// lo que llega en el push es un aviso, no la fuente de verdad.
  final String? alertId;

  final AlertLevel? level;

  final String title;
  final String body;

  /// Si el aviso debe tomar la pantalla completa aunque el celular esté
  /// bloqueado. Lo decide el servidor según el rol, no la app.
  final bool takesOverScreen;

  /// Si el contenido no debe verse en la pantalla bloqueada.
  ///
  /// Se usa para los avisos con el nombre de un menor: quien tenga el teléfono
  /// en la mano ve que hay algo de ALERTIC, y el nombre aparece al desbloquear.
  final bool isPrivate;

  /// Interpreta la carga del push. Devuelve `null` si no se puede mostrar.
  static AlertNotification? tryFrom(Map<String, dynamic> data) {
    final PushKind? kind = PushKind.tryParse(_string(data['tipo']));
    if (kind == null) {
      // Un tipo que esta versión de la app no conoce. Puede venir de un
      // servidor más nuevo: se ignora en silencio en vez de mostrar un aviso
      // vacío que la persona no sabría qué hacer con él.
      return null;
    }

    final String title = _clean(_string(data['titulo']), maxTitleLength);
    if (title.isEmpty) {
      return null;
    }

    final String firstStep = _clean(_string(data['primerPaso']), maxBodyLength);
    final String scope = _clean(_string(data['alcance']), maxBodyLength);
    final String meetingPoint = _clean(_string(data['puntoEncuentro']), 10);

    // El cuerpo se arma con lo más útil que haya llegado, en ese orden: qué
    // hacer, luego a dónde ir, luego a quién cobija.
    final String body = switch (firstStep) {
      '' => meetingPoint.isNotEmpty ? 'Punto de encuentro $meetingPoint' : scope,
      _ => firstStep,
    };

    return AlertNotification._(
      kind: kind,
      alertId: _clean(_string(data['alertId']), 64).isEmpty
          ? null
          : _clean(_string(data['alertId']), 64),
      level: AlertLevel.tryParse(_string(data['nivel'])),
      title: title,
      body: body.isEmpty ? 'Abre ALERTIC para ver el detalle.' : body,
      takesOverScreen: _string(data['tomarPantalla']) == 'true',
      isPrivate: _string(data['privado']) == 'true',
    );
  }

  /// Lo que se guarda en el aviso de Android para saber, al tocarlo, a qué
  /// alerta se refería. Solo el identificador: nada personal se queda en la
  /// bandeja de notificaciones del sistema.
  String get tapPayload => alertId ?? '';

  /// Nunca imprime el cuerpo, que puede llevar el nombre de un menor.
  @override
  String toString() => 'AlertNotification(${kind.wire}, nivel: ${level?.wire})';

  /// Los valores de un push siempre llegan como texto, pero el mapa es
  /// `dynamic`: si alguien manda un número o un mapa anidado, no se revienta.
  static String? _string(Object? value) => value is String ? value : null;

  /// Quita caracteres de control y recorta.
  ///
  /// Aquí se recorta en vez de rechazar, al contrario que en `Alert.validated`:
  /// un título largo en una pantalla se ve mal, pero en un aviso que avisa de un
  /// sismo vale más medio título que ningún aviso.
  static String _clean(String? value, int maxLength) {
    if (value == null) {
      return '';
    }
    final String clean =
        value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
    return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
  }
}
