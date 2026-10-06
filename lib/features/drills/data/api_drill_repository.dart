import '../../../core/network/api_client.dart';
import '../../alerts/domain/hazard.dart';
import '../domain/drill_repository.dart';

/// Simulacros contra la API.
class ApiDrillRepository implements DrillRepository {
  const ApiDrillRepository(this._api);

  final ApiClient _api;

  @override
  Future<DrillOverview> load() async {
    final Map<String, dynamic> raw = await _api.get('/drills');
    final Object? upcoming = raw['upcoming'];
    final Object? history = raw['history'];

    return DrillOverview(
      goalSeconds: (raw['goalSeconds'] as num?)?.toInt() ?? 300,
      upcoming: <Drill>[
        if (upcoming is List<Object?>)
          for (final Object? item in upcoming)
            if (item is Map<String, dynamic>) ?_drill(item),
      ],
      history: <DrillResult>[
        if (history is List<Object?>)
          for (final Object? item in history)
            if (item is Map<String, dynamic>) ?_result(item),
      ],
    );
  }

  @override
  Future<Drill> schedule({
    required Hazard hazard,
    required DateTime at,
    String scope = 'Todo el colegio',
    String? note,
  }) async {
    final Map<String, dynamic> raw = await _api.post(
      '/drills',
      body: <String, dynamic>{
        'hazard': hazard.wire,
        'scheduledAt': at.toUtc().toIso8601String(),
        'scope': scope,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _drill(raw['drill'] as Map<String, dynamic>)!;
  }

  @override
  Future<void> cancel(String id) async {
    await _api.delete('/drills/${Uri.encodeComponent(id)}');
  }

  static Drill? _drill(Map<String, dynamic> item) {
    final Hazard? hazard = Hazard.tryParse(item['hazard'] as String?);
    final DateTime? at = DateTime.tryParse(item['scheduledAt'] as String? ?? '');
    if (hazard == null || at == null) return null;

    return Drill(
      id: item['id'] as String? ?? '',
      hazard: hazard,
      scheduledAt: at.toLocal(),
      scope: item['scope'] as String? ?? 'Todo el colegio',
      note: item['note'] as String?,
    );
  }

  static DrillResult? _result(Map<String, dynamic> item) {
    final Hazard? hazard = Hazard.tryParse(item['hazard'] as String?);
    final DateTime? at = DateTime.tryParse(item['at'] as String? ?? '');
    if (hazard == null || at == null) return null;

    return DrillResult(
      alertId: item['alertId'] as String? ?? '',
      hazard: hazard,
      at: at.toLocal(),
      mySeconds: (item['mySeconds'] as num?)?.toInt(),
      onTime: item['onTime'] as bool?,
      schoolPercent: (item['schoolPercent'] as num?)?.toInt() ?? 0,
    );
  }
}
