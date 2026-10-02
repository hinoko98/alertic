import 'alert.dart';
import 'meeting_point.dart';
import 'protocol.dart';
import 'safety_report.dart';

/// Alertas y protocolos del colegio.
///
/// Toda decisión vive del otro lado: qué alerta está activa, si la respuesta
/// quedó registrada y qué protocolos aplican los define el servidor. La app
/// solo muestra y reporta.
abstract interface class AlertRepository {
  /// Alerta activa en este momento, o `null` si el colegio está en calma.
  ///
  /// Es un flujo porque la alerta puede llegar en cualquier momento, incluso
  /// con la app abierta en otra pantalla.
  Stream<Alert?> watchActiveAlert();

  /// Avisa que la persona leyó la alerta. Aplica a amarilla y naranja.
  Future<void> acknowledge(String alertId);

  /// Manda el estado de la persona durante una alerta roja.
  Future<void> submitSafetyReport(SafetyReport report);

  /// Alertas anteriores, de la más reciente a la más vieja.
  Future<List<Alert>> loadHistory();

  /// Protocolos guardados para consultar sin conexión.
  Future<List<Protocol>> loadProtocols();

  /// Los puntos de encuentro del colegio, tal como los definió coordinación.
  Future<List<MeetingPoint>> loadMeetingPoints();
}
