import 'dart:async';

import 'package:alertic/features/alerts/domain/live_updates.dart';
import 'package:alertic/features/risks/domain/risk_repository.dart';

/// Reportes de riesgo en memoria, solo para pruebas.
class FakeRiskRepository implements RiskRepository, LiveUpdates {
  FakeRiskRepository({this.latency = Duration.zero});

  final Duration latency;

  final List<RiskReport> reports = <RiskReport>[];
  final StreamController<LiveChange> _changes =
      StreamController<LiveChange>.broadcast();

  bool failNext = false;
  int _next = 1;

  @override
  Stream<LiveChange> get changes => _changes.stream;

  @override
  Future<void> report({
    required RiskKind kind,
    required String place,
    String? details,
  }) async {
    await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw StateError('sin conexión');
    }
    reports.insert(
      0,
      RiskReport(
        id: 'r${_next++}',
        kind: kind,
        place: place.trim(),
        status: RiskStatus.nuevo,
        createdAt: DateTime.now(),
        details: details,
        reporterName: 'Laura Camila Pérez Gómez',
        reporterRole: 'estudiante',
        reporterGrade: '10° B',
      ),
    );
    _changes.add(LiveChange.riskReports);
  }

  @override
  Future<List<RiskReport>> loadMine() async {
    await Future<void>.delayed(latency);
    return List<RiskReport>.of(reports);
  }

  @override
  Future<List<RiskReport>> loadInbox() async {
    await Future<void>.delayed(latency);
    return List<RiskReport>.of(reports);
  }

  @override
  Future<void> setStatus(String id, RiskStatus status) async {
    await Future<void>.delayed(latency);
    final int index = reports.indexWhere((RiskReport r) => r.id == id);
    if (index < 0) return;
    final RiskReport old = reports[index];
    reports[index] = RiskReport(
      id: old.id,
      kind: old.kind,
      place: old.place,
      status: status,
      createdAt: old.createdAt,
      details: old.details,
      reporterName: old.reporterName,
      reporterRole: old.reporterRole,
      reporterGrade: old.reporterGrade,
      handledBy: 'Coordinación',
    );
    _changes.add(LiveChange.myRiskReport);
  }

  void dispose() => _changes.close();
}
