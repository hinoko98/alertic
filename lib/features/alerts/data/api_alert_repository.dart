import 'dart:async';

import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../domain/alert.dart';
import '../domain/alert_repository.dart';
import '../domain/hazard.dart';
import '../domain/meeting_point.dart';
import '../domain/protocol.dart';
import '../domain/safety_report.dart';
import 'alert_mapper.dart';
import 'api_event_hub.dart';

/// Alertas reales, contra la API del colegio.
///
/// Todo lo que llega del servidor pasa por `Alert.validated`: una alerta mal
/// formada se descarta antes de llegar a la pantalla, en vez de mostrarse a
/// medias en mitad de una emergencia.
class ApiAlertRepository implements AlertRepository {
  /// [hub] es el canal en vivo compartido. Si no se pasa se crea uno propio, que
  /// sirve para una prueba suelta pero no comparte la conexión con el resto.
  ApiAlertRepository(this._api, {ApiEventHub? hub}) : _hub = hub ?? ApiEventHub(_api);

  final ApiClient _api;
  final ApiEventHub _hub;

  @override
  Stream<Alert?> watchActiveAlert() async* {
    // Primero el estado actual, por si el flujo tarda en abrir.
    try {
      final Map<String, dynamic> response = await _api.get('/alerts/active');
      yield AlertMapper.parse(response['alert']);
    } on ApiException catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'alerta activa');
      yield null;
    }

    // Y después, lo que vaya empujando el servidor.
    await for (final Map<String, dynamic> event in _hub.events) {
      if (event['type'] == 'estado') {
        yield AlertMapper.parse(event['alert']);
      }
    }
  }

  @override
  Future<void> acknowledge(String alertId) async {
    await _api.post('/alerts/$alertId/ack');
  }

  @override
  Future<void> submitSafetyReport(SafetyReport report) async {
    final GeoPoint? point = report.coordinates;

    await _api.post(
      '/alerts/${report.alertId}/reports',
      body: <String, dynamic>{
        'status': report.status.wire,
        'location': report.location.wire,
        // La ubicación solo se manda si la persona dio permiso. Sin permiso el
        // reporte vale igual.
        if (point != null) 'latitude': point.latitude,
        if (point != null) 'longitude': point.longitude,
        if (point != null) 'accuracyMeters': point.accuracyMeters,
      },
    );
  }

  @override
  Future<List<Alert>> loadHistory() async {
    final Map<String, dynamic> response = await _api.get('/alerts/history');
    final Object? raw = response['alerts'];
    if (raw is! List<Object?>) {
      return const <Alert>[];
    }

    return <Alert>[
      for (final Object? item in raw)
        if (AlertMapper.parse(item) case final Alert alert) alert,
    ];
  }

  @override
  Future<List<Protocol>> loadProtocols() async {
    final Map<String, dynamic> response = await _api.get('/protocols');
    final Object? raw = response['protocols'];
    if (raw is! List<Object?>) {
      return const <Protocol>[];
    }

    final List<Protocol> protocols = <Protocol>[];
    for (final Object? item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final Hazard? hazard = Hazard.tryParse(item['hazard'] as String?);
      if (hazard == null) continue;

      protocols.add(
        Protocol(
          hazard: hazard,
          beforeSteps: AlertMapper.steps(item['beforeSteps']),
          duringSteps: AlertMapper.steps(item['duringSteps']),
          afterSteps: AlertMapper.steps(item['afterSteps']),
        ),
      );
    }
    return protocols;
  }

  @override
  Future<List<MeetingPoint>> loadMeetingPoints() async {
    final Map<String, dynamic> response = await _api.get('/meeting-points');
    final Object? raw = response['meetingPoints'];
    if (raw is! List<Object?>) {
      return const <MeetingPoint>[];
    }

    return <MeetingPoint>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>)
          MeetingPoint(
            code: item['code'] as String? ?? '',
            name: item['name'] as String? ?? '',
            routeHint: item['routeHint'] as String? ?? '',
            distanceMeters: (item['distanceMeters'] as num?)?.toInt() ?? 0,
            walkMinutes: (item['walkMinutes'] as num?)?.toInt() ?? 0,
            onlyFor: Hazard.tryParse(item['onlyFor'] as String?),
          ),
    ];
  }
}
