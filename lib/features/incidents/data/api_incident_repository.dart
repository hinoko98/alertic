import '../../../core/network/api_client.dart';
import '../../alerts/domain/hazard.dart';
import '../domain/incident.dart';

/// Reportes de emergencia contra la API real.
///
/// Los errores del servidor llegan como [ApiException] con el mensaje ya
/// escrito para quien lo lee: «Ya enviaste varios reportes y coordinación los
/// está viendo». Las pantallas lo muestran tal cual.
class ApiIncidentRepository implements IncidentRepository {
  const ApiIncidentRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> report(Hazard hazard, {String? details}) async {
    await _api.post(
      '/incidents',
      body: <String, dynamic>{
        'hazard': hazard.wire,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }

  @override
  Future<List<Incident>> loadOpen() async {
    final Map<String, dynamic> response = await _api.get('/incidents');
    final Object? raw = response['incidents'];
    if (raw is! List<Object?>) {
      return const <Incident>[];
    }

    return <Incident>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>)
          if (_parse(item) case final Incident incident) incident,
    ];
  }

  @override
  Future<void> handle(String incidentId, IncidentStatus status) async {
    await _api.post(
      '/incidents/${Uri.encodeComponent(incidentId)}/handle',
      body: <String, dynamic>{'status': status.wire},
    );
  }

  /// Un reporte que no se entiende se descarta en vez de mostrarse a medias: en
  /// la bandeja de coordinación, una tarjeta sin amenaza no sirve de nada.
  static Incident? _parse(Map<String, dynamic> item) {
    final Hazard? hazard = Hazard.tryParse(item['hazard'] as String?);
    final IncidentStatus? status = IncidentStatus.tryParse(item['status'] as String?);
    final DateTime? createdAt = DateTime.tryParse(item['createdAt'] as String? ?? '');
    final Object? reporter = item['reporter'];
    if (hazard == null ||
        status == null ||
        createdAt == null ||
        reporter is! Map<String, dynamic>) {
      return null;
    }

    return Incident(
      id: item['id'] as String? ?? '',
      hazard: hazard,
      status: status,
      createdAt: createdAt.toLocal(),
      reporterName: reporter['fullName'] as String? ?? '',
      reporterGrade: reporter['grade'] as String?,
      details: item['details'] as String?,
      handledBy: item['handledBy'] as String?,
    );
  }
}
