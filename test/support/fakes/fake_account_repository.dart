import 'package:alertic/features/account/domain/account_repository.dart';
import 'package:alertic/features/account/domain/evacuation_support.dart';
import 'package:alertic/features/onboarding/domain/guardian_link.dart';
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

  /// El apoyo que pidió la persona y los compañeros que le asignó el colegio.
  SupportSettings? support;
  List<SupportBuddy> buddies = const <SupportBuddy>[
    SupportBuddy(fullName: 'Mateo Pinzón', detail: 'Compañero · 9.° B'),
  ];

  /// Las solicitudes de hijo que mandó la persona: documento y parentesco.
  final List<({String document, GuardianRelationship relationship})> childRequests =
      <({String document, GuardianRelationship relationship})>[];

  @override
  Future<StudentMatch> lookupChild(String document) async {
    await _wait();
    if (document.replaceAll(RegExp(r'\D'), '') != '1098765434') {
      throw StateError('estudiante_no_encontrado');
    }
    return const StudentMatch(
      maskedName: 'Sofía A••••• V•••••',
      grade: '10° B',
      shift: 'Mañana',
      maskedDocument: '•••5434',
      document: '1098765434',
    );
  }

  @override
  Future<void> requestChild(String document, GuardianRelationship relationship) async {
    await _wait();
    childRequests.add((document: document, relationship: relationship));
  }

  @override
  Future<SupportOverview> loadSupport() async {
    await _wait();
    return SupportOverview(settings: support, buddies: buddies);
  }

  @override
  Future<SupportOverview> saveSupport(SupportSettings settings) async {
    await _wait();
    support = settings;
    return SupportOverview(settings: support, buddies: buddies);
  }

  @override
  Future<SupportOverview> clearSupport() async {
    await _wait();
    support = null;
    return SupportOverview(buddies: buddies);
  }

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
      notifyChildSafe: settings.notifyChildSafe,
      medicalInfo: medical,
    );
  }

  @override
  Future<AccountSettings> updateSettings({
    bool? criticalAlerts,
    bool? shareLocation,
    bool? notifyFamily,
    bool? notifyChildSafe,
    String? medicalInfo,
    bool clearMedicalInfo = false,
  }) async {
    await _wait();
    settings = settings.copyWith(
      criticalAlerts: criticalAlerts,
      shareLocation: shareLocation,
      notifyFamily: notifyFamily,
      notifyChildSafe: notifyChildSafe,
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
