import 'package:alertic/features/account/domain/account_repository.dart';
import 'package:alertic/features/onboarding/domain/school.dart';

/// Ajustes, contactos e historial en memoria, solo para pruebas.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.latency = Duration.zero});

  final Duration latency;

  AccountSettings settings = const AccountSettings(
    criticalAlerts: true,
    shareLocation: true,
    notifyFamily: true,
  );

  String? medical;

  final List<FamilyContact> contacts = <FamilyContact>[
    const FamilyContact(
      id: 'a1',
      fullName: 'Martha Gómez Rueda',
      relationship: 'Madre',
      fromSchool: true,
      maskedPhone: '310 ••• 45 21',
    ),
  ];

  List<FeedItem> feed = <FeedItem>[];

  bool failNext = false;
  int _next = 1;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw StateError('sin conexión');
    }
  }

  @override
  Future<School> loadSchool() async => const School(
        name: 'Instituto Integrado de Comercio',
        city: 'Barbosa, Santander',
      );

  @override
  Future<AccountSettings> loadSettings() async {
    await _wait();
    return AccountSettings(
      criticalAlerts: settings.criticalAlerts,
      shareLocation: settings.shareLocation,
      notifyFamily: settings.notifyFamily,
      medicalInfo: medical,
    );
  }

  @override
  Future<AccountSettings> updateSettings({
    bool? criticalAlerts,
    bool? shareLocation,
    bool? notifyFamily,
    String? medicalInfo,
    bool clearMedicalInfo = false,
  }) async {
    await _wait();
    settings = settings.copyWith(
      criticalAlerts: criticalAlerts,
      shareLocation: shareLocation,
      notifyFamily: notifyFamily,
    );
    if (clearMedicalInfo) medical = null;
    if (medicalInfo != null) medical = medicalInfo;
    return loadSettings();
  }

  @override
  Future<List<FamilyContact>> loadContacts() async {
    await _wait();
    return List<FamilyContact>.of(contacts);
  }

  @override
  Future<List<FamilyContact>> addContact(NewContact contact) async {
    await _wait();
    contacts.add(
      FamilyContact(
        id: 'n${_next++}',
        fullName: contact.fullName,
        relationship: contact.relationship,
        fromSchool: false,
        maskedPhone: '315 ••• 45 67',
      ),
    );
    return List<FamilyContact>.of(contacts);
  }

  @override
  Future<List<FamilyContact>> removeContact(String id) async {
    await _wait();
    contacts.removeWhere((FamilyContact c) => c.id == id && !c.fromSchool);
    return List<FamilyContact>.of(contacts);
  }

  @override
  Future<List<FeedItem>> loadFeed() async {
    await _wait();
    return List<FeedItem>.of(feed);
  }
}
