import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/design/screen_header.dart';
import '../domain/support_repository.dart';
import 'conversation_view.dart';

/// El chat de estudiantes y acudientes con el soporte del colegio.
///
/// Se abre desde el botón de la cabecera, encima de lo que se esté haciendo. Lo
/// que se escribe aquí lo lee coordinación o el docente al que se le asignó: la
/// cabecera dice cuál, para que la persona sepa con quién habla.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  SupportThread? _thread;

  @override
  Widget build(BuildContext context) {
    final SupportRepository repository = AppScope.of(context).supportRepository!;
    final String? who = _thread?.assignedTo?.fullName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          AppScreenHeader(
            title: 'Soporte del colegio',
            subtitle: who == null
                ? 'Te responde coordinación'
                : 'Te responde $who',
            onBack: () => Navigator.of(context).maybePop(),
            showHelp: false,
          ),
          Expanded(
            child: ConversationView(
              load: repository.loadMine,
              send: repository.sendMine,
              onLoaded: (SupportThread thread) {
                if (mounted) setState(() => _thread = thread);
              },
              emptyTitle: 'Escríbele al colegio',
              emptyHint: 'Pregunta lo que necesites. Si es una emergencia, '
                  'llama a la Línea 123.',
            ),
          ),
        ],
      ),
    );
  }
}
