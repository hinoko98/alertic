/// Un mensaje de la conversación con el soporte del colegio.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.fromStaff,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.urgent = false,
  });

  final String id;

  /// Lo escribió el colegio (coordinación o el docente asignado), no la persona.
  final bool fromStaff;
  final String body;
  final DateTime createdAt;

  /// Un pedido de ayuda de la persona.
  final bool urgent;

  /// Quién del colegio lo escribió. Nulo en lo que escribe la persona.
  final String? senderName;
}

/// Quién del colegio atiende una conversación.
class SupportAssignee {
  const SupportAssignee({required this.id, required this.fullName});

  final String id;
  final String fullName;
}

/// Una conversación, tal como la ve quien la pide.
class SupportThread {
  const SupportThread({
    required this.id,
    required this.unread,
    this.urgent = false,
    this.assignedTo,
    this.lastPreview,
    this.lastFromStaff = false,
    this.lastMessageAt,
    this.personId,
    this.personName,
    this.personRole,
    this.personGrade,
  });

  final String id;

  /// Mensajes del otro lado que quien pregunta todavía no leyó.
  final int unread;

  /// Hay un pedido de ayuda sin leer. Solo lo ve el colegio.
  final bool urgent;
  final SupportAssignee? assignedTo;
  final String? lastPreview;
  final bool lastFromStaff;
  final DateTime? lastMessageAt;

  /// De quién es la conversación. Solo lo ve el colegio.
  final String? personId;
  final String? personName;
  final String? personRole;
  final String? personGrade;
}

/// Una conversación con sus mensajes.
class SupportConversation {
  const SupportConversation({required this.thread, required this.messages});

  final SupportThread thread;
  final List<SupportMessage> messages;
}

/// Chat entre una persona (estudiante o acudiente) y el soporte del colegio.
///
/// Dos públicos en una interfaz: **la persona**, que solo tiene su conversación
/// (`loadMine`, `sendMine`), y **el colegio**, que atiende las que le tocan. El
/// servidor decide qué ve cada quien.
abstract interface class SupportRepository {
  /// Mi conversación con el colegio. La primera vez nace vacía.
  Future<SupportConversation> loadMine();

  /// Escribirle al colegio. Lanza si no llegó. Con [urgent] es un pedido de
  /// ayuda: el colegio lo ve primero y recibe un aviso prioritario.
  Future<SupportMessage> sendMine(String body, {bool urgent = false});

  /// Cuántos mensajes del colegio no he leído. Alimenta la insignia.
  Future<int> unreadCount();

  /// Las conversaciones que le tocan al colegio, la más reciente primero.
  Future<List<SupportThread>> loadThreads();

  /// Una conversación completa. Al abrirla queda leída.
  Future<SupportConversation> loadThread(String id);

  /// Responder en una conversación.
  Future<SupportMessage> reply(String threadId, String body);

  /// Asignar la conversación a un docente, o dejarla solo con coordinación.
  /// Solo coordinación.
  Future<SupportThread> assign(String threadId, String? teacherId);

  /// Docentes a los que se puede asignar.
  Future<List<SupportAssignee>> loadAssignees();
}
