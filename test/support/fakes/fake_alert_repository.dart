import 'dart:async';

import 'package:alertic/features/alerts/domain/alert.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/alert_repository.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/meeting_point.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:alertic/features/alerts/domain/safety_report.dart';
import 'package:alertic/features/teacher/domain/teacher_repository.dart';

/// Alertas de prueba, en memoria, con el contenido del diseño.
///
/// Permite recorrer los tres niveles sin backend. Se reemplaza por la
/// implementación contra la API sin tocar las pantallas.
class FakeAlertRepository implements AlertRepository {
  FakeAlertRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  final StreamController<Alert?> _active =
      StreamController<Alert?>.broadcast()..add(null);

  final List<Alert> _history = <Alert>[];

  Alert? _current;

  /// Última alerta publicada por un docente. Lo usan las pruebas para
  /// comprobar qué se emitió, sin tener que espiar el flujo.
  Alert? get lastPublished => _lastPublished;
  Alert? _lastPublished;

  @override
  Stream<Alert?> watchActiveAlert() async* {
    // Quien se suscriba después de que la alerta llegó tiene que verla igual,
    // así que primero se emite el estado actual.
    yield _current;
    yield* _active.stream;
  }

  @override
  Future<void> acknowledge(String alertId) async {
    await Future<void>.delayed(latency);
    // El servidor anota quién leyó la alerta. Aquí solo se simula la llamada.
  }

  @override
  Future<void> submitSafetyReport(SafetyReport report) async {
    await Future<void>.delayed(latency);
  }

  @override
  Future<List<Alert>> loadHistory() async {
    await Future<void>.delayed(latency);
    if (_history.isEmpty) {
      return _seedHistory();
    }
    return List<Alert>.unmodifiable(_history.reversed);
  }

  @override
  Future<List<Protocol>> loadProtocols() async {
    await Future<void>.delayed(latency);
    return <Protocol>[for (final Protocol p in _protocols) _edited[p.hazard] ?? p];
  }

  /// Lo que coordinación editó en esta instancia. Va aparte de la lista estática
  /// para que una prueba no le cambie los protocolos a la siguiente.
  final Map<Hazard, Protocol> _edited = <Hazard, Protocol>{};

  /// Reemplaza el protocolo de una amenaza, como el `PUT /protocols/:hazard`.
  void replaceProtocol(Protocol protocol) => _edited[protocol.hazard] = protocol;

  @override
  Future<List<MeetingPoint>> loadMeetingPoints() async {
    await Future<void>.delayed(latency);
    return const <MeetingPoint>[
      MeetingPoint(
        code: 'P1',
        name: 'Cancha central',
        routeHint: 'Por el corredor sur',
        distanceMeters: 60,
        walkMinutes: 1,
      ),
      MeetingPoint(
        code: 'P2',
        name: 'Placa alta',
        routeHint: 'Subiendo por la escalera',
        distanceMeters: 120,
        walkMinutes: 2,
        onlyFor: Hazard.inundacion,
      ),
    ];
  }

  /// Dispara una alerta de prueba, para ensayar cómo llega cada nivel.
  void simulate(AlertLevel level) {
    final Alert alert = _sampleFor(level);
    _current = alert;
    _history.add(alert);
    _active.add(alert);
  }

  /// Publica una alerta que armó un docente.
  ///
  /// Es el equivalente de `POST /alerts` en el servidor de verdad.
  Alert publish(AlertDraft draft) {
    final Alert alert = Alert.validated(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      level: draft.level,
      hazard: draft.hazard,
      title: draft.title,
      scope: draft.scope,
      // Como el servidor: una roja sin punto usa el principal del colegio.
      meetingPoint: draft.meetingPoint ?? (draft.level == AlertLevel.roja ? 'P1' : null),
      instructions: draft.instructions,
      issuedAt: DateTime.now(),
    );

    _current = alert;
    _lastPublished = alert;
    _history.add(alert);
    _active.add(alert);
    return alert;
  }

  /// Cierra la alerta activa.
  void clear() {
    _current = null;
    _active.add(null);
  }

  void dispose() => _active.close();

  static Alert _sampleFor(AlertLevel level) {
    final DateTime now = DateTime.now();
    return switch (level) {
      AlertLevel.amarilla => Alert.validated(
          id: 'demo-amarilla',
          level: AlertLevel.amarilla,
          hazard: Hazard.lluvia,
          title: 'LLUVIA FUERTE',
          scope: 'Todo el instituto',
          instructions: <String>[
            'Quédate en tu salón',
            'No cruces el patio ni la quebrada',
            'Espera nuevas indicaciones',
          ],
          coordinatorNote: 'IDEAM reporta lluvias hasta las 16:00. '
              'Salida normal por ahora.',
          issuedBy: 'Coord. Gestión del Riesgo',
          issuedAt: now,
        ),
      AlertLevel.naranja => Alert.validated(
          id: 'demo-naranja',
          level: AlertLevel.naranja,
          hazard: Hazard.inundacion,
          title: 'CRECIENTE DE LA QUEBRADA',
          scope: 'Bloque B',
          instructions: <String>[
            'Guarda tus cosas',
            'Ubícate cerca de la puerta con tu grupo',
            'Si sube a roja, ve al punto P2',
          ],
          issuedBy: 'Coord. Gestión del Riesgo',
          issuedAt: now,
        ),
      AlertLevel.roja => Alert.validated(
          id: 'demo-roja',
          level: AlertLevel.roja,
          hazard: Hazard.sismo,
          title: 'SISMO',
          scope: 'Todo el instituto',
          meetingPoint: 'P1',
          instructions: <String>[
            'Cúbrete hasta que pare',
            'Sal en fila, sin correr',
            'Ve a la cancha central',
          ],
          issuedBy: 'Carlos Jaimes',
          issuedAt: now,
        ),
    };
  }

  static List<Alert> _seedHistory() {
    final DateTime today = DateTime.now();
    return <Alert>[
      Alert.validated(
        id: 'hist-1',
        level: AlertLevel.amarilla,
        hazard: Hazard.lluvia,
        title: 'LLUVIA FUERTE',
        scope: 'Todo el instituto',
        instructions: <String>['Quédate en tu salón'],
        issuedBy: 'Coord. Gestión del Riesgo',
        issuedAt: today.subtract(const Duration(days: 2)),
      ),
      Alert.validated(
        id: 'hist-2',
        level: AlertLevel.roja,
        hazard: Hazard.sismo,
        title: 'SIMULACRO DE SISMO',
        scope: 'Todo el instituto',
        meetingPoint: 'P1',
        instructions: <String>['Sal en fila, sin correr'],
        issuedBy: 'Defensa Civil Barbosa',
        issuedAt: today.subtract(const Duration(days: 15)),
      ),
    ];
  }

  static final List<Protocol> _protocols = <Protocol>[
    const Protocol(
      hazard: Hazard.sismo,
      beforeSteps: <String>[
        'Ubica la salida más cercana a tu salón',
        'Aprende dónde queda el punto P1',
      ],
      duringSteps: <String>[
        'Cúbrete bajo el pupitre hasta que pare',
        'Aléjate de ventanas y estantes',
        'No corras ni uses las escaleras mientras tiembla',
      ],
      afterSteps: <String>[
        'Sal en fila con tu grupo',
        'Ve al punto P1 y marca que estás bien',
      ],
    ),
    const Protocol(
      hazard: Hazard.inundacion,
      beforeSteps: <String>['No cruces la quebrada cuando llueva fuerte'],
      duringSteps: <String>[
        'Sube al punto P2, en la placa alta',
        'No intentes recuperar cosas',
      ],
      afterSteps: <String>['Espera la autorización para bajar'],
    ),
    const Protocol(
      hazard: Hazard.incendio,
      beforeSteps: <String>['Ubica los extintores de tu bloque'],
      duringSteps: <String>[
        'Sal agachado si hay humo',
        'No uses el ascensor ni vuelvas por nada',
      ],
      afterSteps: <String>['Repórtate en el punto de encuentro'],
    ),
    const Protocol(
      hazard: Hazard.lluvia,
      beforeSteps: <String>['Revisa la alerta antes de salir del colegio'],
      duringSteps: <String>[
        'Quédate bajo techo',
        'No cruces el patio ni la quebrada',
      ],
      afterSteps: <String>['Sigue las indicaciones de tu docente'],
    ),
  ];
}
