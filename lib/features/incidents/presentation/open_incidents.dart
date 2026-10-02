import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/incident.dart';

/// Lo que ve quien dibuja la bandeja de reportes.
class OpenIncidentsState {
  const OpenIncidentsState({
    required this.incidents,
    required this.loading,
    required this.failed,
    required this.reload,
  });

  final List<Incident> incidents;

  /// Todavía no llegó la primera respuesta.
  final bool loading;

  /// La última consulta falló. Se conserva lo que ya había: una bandeja que se
  /// vacía porque se cayó el wifi haría creer que no hay reportes.
  final bool failed;

  final Future<void> Function() reload;
}

/// Carga los reportes abiertos y los mantiene al día.
///
/// Lo usan dos pantallas distintas —el contador del docente y la bandeja de
/// coordinación—, y las dos necesitan lo mismo: pedir la lista, volver a
/// pedirla cuando el servidor avisa de un reporte nuevo, y no pisar una
/// respuesta nueva con una vieja que llegó tarde.
class OpenIncidents extends StatefulWidget {
  const OpenIncidents({required this.builder, super.key});

  final Widget Function(BuildContext context, OpenIncidentsState state) builder;

  @override
  State<OpenIncidents> createState() => _OpenIncidentsState();
}

class _OpenIncidentsState extends State<OpenIncidents> {
  List<Incident> _incidents = <Incident>[];
  bool _loading = true;
  bool _failed = false;
  bool _started = false;

  /// Última consulta pedida. Si llegan dos y la vieja contesta de última, se
  /// descarta: mostraría un reporte ya atendido como si siguiera abierto.
  Object? _pending;

  StreamSubscription<LiveChange>? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
    // Cuando llega o cambia un reporte, la bandeja se actualiza sola.
    _live ??= AppScope.of(context).liveUpdates.changes
        .where((LiveChange change) => change == LiveChange.incidents)
        .listen((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final IncidentRepository? repository =
        AppScope.of(context).incidentRepository;
    if (repository == null) {
      setState(() => _loading = false);
      return;
    }

    final Object request = Object();
    _pending = request;

    try {
      final List<Incident> incidents = await repository.loadOpen();
      if (mounted && identical(_pending, request)) {
        setState(() {
          _incidents = incidents;
          _loading = false;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportes de emergencia');
      if (mounted && identical(_pending, request)) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      OpenIncidentsState(
        incidents: _incidents,
        loading: _loading,
        failed: _failed,
        reload: _load,
      ),
    );
  }
}
