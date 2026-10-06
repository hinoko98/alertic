import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../alerts/domain/hazard.dart';
import '../../student/presentation/widgets/hazard_report_sheet.dart';
import '../domain/incident.dart';

/// Reportar una emergencia que el colegio todavía no vio: «huelo humo», «siento
/// que tiembla».
///
/// Pregunta qué se ve (opciones cerradas) y se lo manda al director de grupo y a
/// coordinación, que deciden si suena una alerta. **Nunca emite una alerta**:
/// avisa. Solo dice «enviado» cuando el servidor lo confirmó.
Future<void> reportEmergency(BuildContext context) async {
  final Hazard? hazard = await showModalBottomSheet<Hazard>(
    context: context,
    // Que pueda usar toda la altura que necesite: con el límite por omisión
    // (poco más de la mitad) las opciones no caben en un celular bajo.
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) => const HazardReportSheet(),
  );
  if (hazard == null || !context.mounted) return;

  // Se toman antes de esperar: después de un `await` el contexto puede ya no
  // estar, y el mensaje tiene que salir de todos modos.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final IncidentRepository? repository = AppScope.of(context).incidentRepository;

  void say(String message) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  if (repository == null) {
    say('No se pudo enviar el reporte. Avisa a tu docente en persona.');
    return;
  }

  try {
    await repository.report(hazard);
    // Solo se dice «enviado» cuando el servidor lo confirmó. Un reporte de
    // incendio que parece haber salido y no salió es peor que un error: quien lo
    // hizo cree que ya avisó, y nadie se entera.
    say(
      'Reporte de ${hazard.reportLabel.toLowerCase()} enviado. Tu docente y '
      'coordinación ya lo ven.',
    );
  } catch (error, stack) {
    ErrorReporter.report(error, stack, context: 'reportar emergencia');
    say(
      error is ApiException && error.statusCode != null
          ? error.message
          : 'No se pudo enviar el reporte. Avisa a tu docente en persona.',
    );
  }
}
