import '../../../core/network/api_client.dart';
import '../../alerts/domain/safety_report.dart';
import '../domain/guardian_repository.dart';

/// Los hijos del acudiente, contra la API real.
///
/// El servidor resuelve la consulta partiendo del vínculo que registró el
/// colegio, con el identificador de la sesión: no existe ninguna forma de pedir
/// los datos de un menor ajeno, ni siquiera modificando la app.
class ApiGuardianRepository implements GuardianRepository {
  const ApiGuardianRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ChildStatus>> loadChildren(String? alertId) async {
    final Map<String, dynamic> response = await _api.get(
      alertId == null
          ? '/children'
          : '/children?alertId=${Uri.encodeQueryComponent(alertId)}',
    );

    final Object? raw = response['children'];
    if (raw is! List<Object?>) {
      return const <ChildStatus>[];
    }

    return <ChildStatus>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) _child(item),
    ];
  }

  @override
  Future<String?> loadSchoolPhone() async {
    final Map<String, dynamic> response = await _api.get('/school');
    final Object? phone = response['phone'];
    return phone is String && phone.trim().isNotEmpty ? phone.trim() : null;
  }

  ChildStatus _child(Map<String, dynamic> item) {
    return ChildStatus(
      fullName: item['fullName'] as String? ?? '',
      grade: item['grade'] as String? ?? '',
      shift: item['shift'] as String? ?? '',
      homeroomTeacher: item['homeroomTeacher'] as String? ?? '',
      meetingPoint: item['meetingPoint'] as String? ?? '',
      status: _status(item['status'] as String?),
      location: _location(item['location'] as String?),
      reportedAt: DateTime.tryParse(item['reportedAt'] as String? ?? '')?.toLocal(),
      note: item['note'] as String?,
    );
  }

  static SafetyStatus? _status(String? wire) {
    for (final SafetyStatus status in SafetyStatus.values) {
      if (status.wire == wire) return status;
    }
    return null;
  }

  static ReportedLocation? _location(String? wire) {
    for (final ReportedLocation location in ReportedLocation.values) {
      if (location.wire == wire) return location;
    }
    return null;
  }
}
