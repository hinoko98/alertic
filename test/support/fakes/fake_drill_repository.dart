import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/drills/domain/drill_repository.dart';

/// Simulacros en memoria, solo para pruebas.
class FakeDrillRepository implements DrillRepository {
  FakeDrillRepository({this.latency = Duration.zero});

  final Duration latency;

  final List<Drill> upcoming = <Drill>[];
  final List<DrillResult> history = <DrillResult>[];
  int _next = 1;

  @override
  Future<DrillOverview> load() async {
    await Future<void>.delayed(latency);
    return DrillOverview(
      goalSeconds: 300,
      upcoming: List<Drill>.of(upcoming),
      history: List<DrillResult>.of(history),
    );
  }

  @override
  Future<Drill> schedule({
    required Hazard hazard,
    required DateTime at,
    String scope = 'Todo el colegio',
    String? note,
  }) async {
    await Future<void>.delayed(latency);
    final Drill drill = Drill(
      id: 'd${_next++}',
      hazard: hazard,
      scheduledAt: at,
      scope: scope,
      note: note,
    );
    upcoming
      ..add(drill)
      ..sort((Drill a, Drill b) => a.scheduledAt.compareTo(b.scheduledAt));
    return drill;
  }

  @override
  Future<void> cancel(String id) async {
    await Future<void>.delayed(latency);
    upcoming.removeWhere((Drill d) => d.id == id);
  }
}
