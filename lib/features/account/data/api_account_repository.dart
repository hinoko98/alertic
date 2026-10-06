import '../../../core/network/api_client.dart';
import '../../onboarding/domain/school.dart';
import '../domain/account_repository.dart';

/// Ajustes, contactos e historial de avisos contra la API.
class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository(this._api);

  final ApiClient _api;

  @override
  Future<School> loadSchool() async {
    final Map<String, dynamic> raw = await _api.get('/school');
    return School(
      name: raw['name'] as String? ?? '',
      city: raw['city'] as String? ?? '',
    );
  }

  @override
  Future<AccountSettings> loadSettings() async =>
      _settings((await _api.get('/me/settings'))['settings']);

  @override
  Future<AccountSettings> updateSettings({
    bool? criticalAlerts,
    bool? shareLocation,
    bool? notifyFamily,
    String? medicalInfo,
    bool clearMedicalInfo = false,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'criticalAlerts': ?criticalAlerts,
      'shareLocation': ?shareLocation,
      'notifyFamily': ?notifyFamily,
      if (clearMedicalInfo) 'medicalInfo': null else 'medicalInfo': ?medicalInfo,
    };
    return _settings((await _api.patch('/me/settings', body: body))['settings']);
  }

  @override
  Future<List<FamilyContact>> loadContacts() async =>
      _contacts(await _api.get('/me/contacts'));

  @override
  Future<List<FamilyContact>> addContact(NewContact contact) async => _contacts(
        await _api.post(
          '/me/contacts',
          body: <String, dynamic>{
            'fullName': contact.fullName,
            'relationship': contact.relationship,
            'phone': contact.phone,
          },
        ),
      );

  @override
  Future<List<FamilyContact>> removeContact(String id) async =>
      _contacts(await _api.delete('/me/contacts/${Uri.encodeComponent(id)}'));

  @override
  Future<List<FeedItem>> loadFeed() async {
    final Object? items = (await _api.get('/me/feed'))['items'];
    return <FeedItem>[
      if (items is List<Object?>)
        for (final Object? item in items)
          if (item is Map<String, dynamic>) ?_feedItem(item),
    ];
  }

  static AccountSettings _settings(Object? raw) {
    final Map<String, dynamic> map = raw as Map<String, dynamic>;
    return AccountSettings(
      criticalAlerts: map['criticalAlerts'] as bool? ?? true,
      shareLocation: map['shareLocation'] as bool? ?? true,
      notifyFamily: map['notifyFamily'] as bool? ?? true,
      medicalInfo: map['medicalInfo'] as String?,
    );
  }

  static List<FamilyContact> _contacts(Map<String, dynamic> raw) {
    final Object? items = raw['contacts'];
    return <FamilyContact>[
      if (items is List<Object?>)
        for (final Object? item in items)
          if (item is Map<String, dynamic>)
            FamilyContact(
              id: item['id'] as String? ?? '',
              fullName: item['fullName'] as String? ?? '',
              relationship: item['relationship'] as String? ?? '',
              maskedPhone: item['maskedPhone'] as String?,
              fromSchool: item['source'] == 'colegio',
            ),
    ];
  }

  /// Un elemento que no se entiende se descarta: en un historial, una fila sin
  /// fecha ni título no le dice nada a nadie.
  static FeedItem? _feedItem(Map<String, dynamic> item) {
    final DateTime? at = DateTime.tryParse(item['at'] as String? ?? '');
    final String? kind = item['kind'] as String?;
    if (at == null || kind == null) return null;

    return FeedItem(
      id: item['id'] as String? ?? '',
      kind: kind,
      title: item['title'] as String? ?? '',
      at: at.toLocal(),
      hazard: item['hazard'] as String?,
      myStatus: item['myStatus'] as String?,
      mySeconds: (item['mySeconds'] as num?)?.toInt(),
      active: item['active'] as bool? ?? false,
      riskStatus: item['status'] as String?,
    );
  }
}
