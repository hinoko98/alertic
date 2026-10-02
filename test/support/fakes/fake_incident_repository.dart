import 'dart:async';

import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/live_updates.dart';
import 'package:alertic/features/incidents/domain/incident.dart';

/// Reportes en memoria, para correr la app sin servidor.
///
/// Es también [LiveUpdates]: cuando se reporta algo, avisa a quien esté mirando
/// la bandeja, así que en modo de prueba el flujo estudiante → docente se ve
/// moverse igual que con el servidor de verdad.
class FakeIncidentRepository implements IncidentRepository, LiveUpdates {
  FakeIncidentRepository({
    this.latency = const Duration(milliseconds: 300),
    this.reporterName = 'Laura Camila Pérez Gómez',
    this.reporterGrade = '10° B',
  });

  final Duration latency;
  final String reporterName;
  final String reporterGrade;

  final List<Incident> _incidents = <Incident>[];
  final StreamController<LiveChange> _changes =
      StreamController<LiveChange>.broadcast();

  @override
  Stream<LiveChange> get changes => _changes.stream;

  @override
  Future<void> report(Hazard hazard, {String? details}) async {
    await _simulateNetwork();
    _incidents.insert(
      0,
      Incident(
        id: 'prueba-${_incidents.length + 1}',
        hazard: hazard,
        status: IncidentStatus.open,
        createdAt: DateTime.now(),
        reporterName: reporterName,
        reporterGrade: reporterGrade,
        details: details,
      ),
    );
    _changes.add(LiveChange.incidents);
  }

  @override
  Future<List<Incident>> loadOpen() async {
    await _simulateNetwork();
    return _incidents.where((Incident i) => i.isOpen).toList(growable: false);
  }

  @override
  Future<void> handle(String incidentId, IncidentStatus status) async {
    await _simulateNetwork();
    final int index = _incidents.indexWhere((Incident i) => i.id == incidentId);
    if (index < 0) {
      return;
    }
    final Incident old = _incidents[index];
    _incidents[index] = Incident(
      id: old.id,
      hazard: old.hazard,
      status: status,
      createdAt: old.createdAt,
      reporterName: old.reporterName,
      reporterGrade: old.reporterGrade,
      details: old.details,
      handledBy: 'Tú',
    );
    _changes.add(LiveChange.incidents);
  }

  /// Con latencia cero no espera nada: en una prueba de widgets, un
  /// `Future.delayed(Duration.zero)` espera a un reloj falso que no avanza solo,
  /// y un `await` desde el cuerpo de la prueba se quedaría colgado.
  Future<void> _simulateNetwork() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  void dispose() => unawaited(_changes.close());
}
