import '../../../core/network/api_client.dart';
import '../domain/risk_repository.dart';

/// Reportes de riesgo contra la API.
class ApiRiskRepository implements RiskRepository {
  const ApiRiskRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> report({
    required RiskKind kind,
    required String place,
    String? details,
  }) async {
    await _api.post(
      '/risks',
      body: <String, dynamic>{
        'kind': kind.wire,
        'place': place.trim(),
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }

  @override
  Future<List<RiskReport>> loadMine() async => _list(await _api.get('/risks/mine'));

  @override
  Future<List<RiskReport>> loadInbox() async => _list(await _api.get('/risks'));

  @override
  Future<void> setStatus(String id, RiskStatus status) async {
    await _api.patch(
      '/risks/${Uri.encodeComponent(id)}',
      body: <String, dynamic>{'status': status.wire},
    );
  }

  static List<RiskReport> _list(Map<String, dynamic> raw) {
    final Object? items = raw['reports'];
    return <RiskReport>[
      if (items is List<Object?>)
        for (final Object? item in items)
          if (item is Map<String, dynamic>) ?_parse(item),
    ];
  }

  /// Un reporte sin tipo o sin fecha no se muestra a medias.
  static RiskReport? _parse(Map<String, dynamic> item) {
    final RiskKind? kind = RiskKind.tryParse(item['kind'] as String?);
    final RiskStatus? status = RiskStatus.tryParse(item['status'] as String?);
    final DateTime? at = DateTime.tryParse(item['createdAt'] as String? ?? '');
    if (kind == null || status == null || at == null) return null;

    final Object? reporter = item['reporter'];
    return RiskReport(
      id: item['id'] as String? ?? '',
      kind: kind,
      place: item['place'] as String? ?? '',
      status: status,
      createdAt: at.toLocal(),
      details: item['details'] as String?,
      handledBy: item['handledBy'] as String?,
      reporterName: reporter is Map<String, dynamic> ? reporter['fullName'] as String? : null,
      reporterRole: reporter is Map<String, dynamic> ? reporter['role'] as String? : null,
      reporterGrade: reporter is Map<String, dynamic> ? reporter['grade'] as String? : null,
    );
  }
}
