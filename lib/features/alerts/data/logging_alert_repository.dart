import '../../../core/errors/error_reporter.dart';
import '../../../core/security/redaction.dart';
import '../domain/alert.dart';
import '../domain/alert_repository.dart';
import '../domain/meeting_point.dart';
import '../domain/protocol.dart';
import '../domain/safety_report.dart';

/// Decorador que registra cada llamada al repositorio de alertas.
///
/// Patrón estructural *Decorator*: envuelve otro [AlertRepository] y le agrega
/// registro y medición de tiempos sin que el repositorio envuelto ni las
/// pantallas sepan que existe. Se puede apilar con otros decoradores (caché,
/// reintentos) en cualquier orden.
///
/// Todo lo que registra pasa por [Redact]: en una emergencia estos logs se
/// revisan con el colegio, y ahí no puede quedar información de un menor.
class LoggingAlertRepository implements AlertRepository {
  const LoggingAlertRepository(this._inner);

  final AlertRepository _inner;

  @override
  Stream<Alert?> watchActiveAlert() {
    return _inner.watchActiveAlert().map((Alert? alert) {
      ErrorReporter.trace(
        alert == null
            ? 'sin alerta activa'
            : 'alerta activa ${alert.level.wire} (${alert.id})',
        context: 'alertas',
      );
      return alert;
    });
  }

  @override
  Future<void> acknowledge(String alertId) {
    return _timed(
      'acknowledge($alertId)',
      () => _inner.acknowledge(alertId),
    );
  }

  @override
  Future<void> submitSafetyReport(SafetyReport report) {
    final String location = Redact.coordinates(
      report.coordinates?.latitude,
      report.coordinates?.longitude,
    );
    return _timed(
      'reporte ${report.status.wire} desde ${report.location.wire} ($location)',
      () => _inner.submitSafetyReport(report),
    );
  }

  @override
  Future<List<Alert>> loadHistory() =>
      _timed('loadHistory()', _inner.loadHistory);

  @override
  Future<List<Protocol>> loadProtocols() =>
      _timed('loadProtocols()', _inner.loadProtocols);

  @override
  Future<List<MeetingPoint>> loadMeetingPoints() =>
      _timed('loadMeetingPoints()', _inner.loadMeetingPoints);

  Future<T> _timed<T>(String label, Future<T> Function() action) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      final T result = await action();
      ErrorReporter.trace(
        '$label ok en ${watch.elapsedMilliseconds} ms',
        context: 'alertas',
      );
      return result;
    } catch (error, stack) {
      ErrorReporter.report(
        error,
        stack,
        context: 'alertas · $label tras ${watch.elapsedMilliseconds} ms',
      );
      rethrow;
    }
  }
}
