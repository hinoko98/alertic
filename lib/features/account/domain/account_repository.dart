import '../../onboarding/domain/school.dart';

/// Los ajustes de una persona.
class AccountSettings {
  const AccountSettings({
    required this.criticalAlerts,
    required this.shareLocation,
    required this.notifyFamily,
    this.medicalInfo,
  });

  /// Que las alertas críticas suenen aunque el celular esté en silencio.
  final bool criticalAlerts;

  /// Compartir la ubicación durante una alerta.
  final bool shareLocation;

  /// Avisar a la familia cuando la persona confirma que está a salvo.
  final bool notifyFamily;

  /// Lo que la persona anotó para un brigadista: alergias, medicamentos.
  final String? medicalInfo;

  AccountSettings copyWith({
    bool? criticalAlerts,
    bool? shareLocation,
    bool? notifyFamily,
  }) =>
      AccountSettings(
        criticalAlerts: criticalAlerts ?? this.criticalAlerts,
        shareLocation: shareLocation ?? this.shareLocation,
        notifyFamily: notifyFamily ?? this.notifyFamily,
        medicalInfo: medicalInfo,
      );
}

/// Un contacto de familia.
class FamilyContact {
  const FamilyContact({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.fromSchool,
    this.maskedPhone,
  });

  final String id;
  final String fullName;
  final String relationship;

  /// Lo cargó el colegio: no se puede quitar desde la app.
  final bool fromSchool;

  /// `300 ••• 12 34`. El número completo nunca llega al celular.
  final String? maskedPhone;
}

/// Un contacto que la persona quiere sumar.
class NewContact {
  const NewContact({
    required this.fullName,
    required this.relationship,
    required this.phone,
  });

  final String fullName;
  final String relationship;
  final String phone;
}

/// Un elemento del historial «Alertas y avisos».
class FeedItem {
  const FeedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.at,
    this.hazard,
    this.myStatus,
    this.mySeconds,
    this.active = false,
    this.riskStatus,
  });

  final String id;

  /// `alerta`, `simulacro` o `reporte_riesgo`.
  final String kind;
  final String title;
  final DateTime at;
  final String? hazard;

  /// Cómo respondió la persona: `a_salvo`, `necesita_ayuda` o nada.
  final String? myStatus;

  /// Lo que tardó en confirmar que estaba a salvo.
  final int? mySeconds;
  final bool active;

  /// Estado de un reporte de riesgo: `nuevo`, `en_revision`, `atendido`…
  final String? riskStatus;
}

/// Lo propio de cada persona: ajustes, contactos y su historial de avisos.
abstract interface class AccountRepository {
  /// El colegio de quien tiene sesión.
  Future<School> loadSchool();

  Future<AccountSettings> loadSettings();

  /// Cambia solo lo que se pase. Devuelve cómo quedó.
  Future<AccountSettings> updateSettings({
    bool? criticalAlerts,
    bool? shareLocation,
    bool? notifyFamily,
    String? medicalInfo,
    bool clearMedicalInfo = false,
  });

  Future<List<FamilyContact>> loadContacts();
  Future<List<FamilyContact>> addContact(NewContact contact);
  Future<List<FamilyContact>> removeContact(String id);

  Future<List<FeedItem>> loadFeed();
}
