import 'package:flutter/foundation.dart';

/// Qué tipo de riesgo se ve.
enum RiskKind {
  grieta(wire: 'grieta', label: 'Grieta o daño'),
  cable(wire: 'cable', label: 'Cable o chispas'),
  agua(wire: 'agua', label: 'Agua o goteras'),
  humo(wire: 'humo', label: 'Humo u olor a gas'),
  arbol(wire: 'arbol', label: 'Árbol o talud'),
  otro(wire: 'otro', label: 'Otro');

  const RiskKind({required this.wire, required this.label});

  final String wire;
  final String label;

  static RiskKind? tryParse(String? value) {
    for (final RiskKind kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// En qué va un reporte de riesgo.
enum RiskStatus {
  nuevo(wire: 'nuevo', label: 'Nuevo'),
  enRevision(wire: 'en_revision', label: 'En revisión'),
  atendido(wire: 'atendido', label: 'Atendido'),
  descartado(wire: 'descartado', label: 'Descartado');

  const RiskStatus({required this.wire, required this.label});

  final String wire;
  final String label;

  static RiskStatus? tryParse(String? value) {
    for (final RiskStatus status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// Un reporte de riesgo: una grieta, un cable suelto, una gotera.
@immutable
class RiskReport {
  const RiskReport({
    required this.id,
    required this.kind,
    required this.place,
    required this.status,
    required this.createdAt,
    this.details,
    this.reporterName,
    this.reporterRole,
    this.reporterGrade,
    this.handledBy,
  });

  final String id;
  final RiskKind kind;
  final String place;
  final RiskStatus status;
  final DateTime createdAt;
  final String? details;

  /// Quién lo reportó. Solo lo ve el colegio.
  final String? reporterName;
  final String? reporterRole;
  final String? reporterGrade;
  final String? handledBy;

  bool get isOpen =>
      status == RiskStatus.nuevo || status == RiskStatus.enRevision;
}

/// Reportes de riesgo.
///
/// Quien reporta ve el estado de **sus** reportes; coordinación atiende la
/// bandeja completa y un docente ve la de sus grupos.
abstract interface class RiskRepository {
  /// Lanza si no llegó al servidor: quien reporta una grieta y ve «enviado» sin
  /// que haya salido nada cree que ya avisó.
  Future<void> report({
    required RiskKind kind,
    required String place,
    String? details,
  });

  Future<List<RiskReport>> loadMine();

  /// La bandeja del comité: coordinación y docentes.
  Future<List<RiskReport>> loadInbox();

  /// Solo coordinación.
  Future<void> setStatus(String id, RiskStatus status);
}
