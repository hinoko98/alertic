import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/shell_scope.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/support/presentation/support_chat_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// La barra superior de cada pantalla: título, una línea de contexto y, a la
/// derecha, el chat con el colegio y el botón «Ayuda».
///
/// Va **dentro** del cuerpo y no como `AppBar`: así puede llevar la insignia de
/// mensajes sin leer y se ve igual en las pestañas y en las pantallas que se
/// abren encima.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.showHelp = true,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Con valor, muestra la flecha de volver.
  final VoidCallback? onBack;

  /// Muestra el chat y «Ayuda». Se apaga en las pantallas de emergencia, donde
  /// nada debe competir con lo que hay que hacer.
  final bool showHelp;

  /// Botones propios de la pantalla, antes de los de siempre.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ShellScope? shell = ShellScope.maybeOf(context);

    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.md,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: InkResponse(
                      onTap: onBack,
                      radius: 22,
                      child: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headerTitle,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
                ...actions,
                if (showHelp && shell != null) ...<Widget>[
                  if (shell.chatInHeader) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    _ChatButton(unread: shell.chatUnread),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  const HelpPill(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El botón rosado «Ayuda»: abre el asistente de riesgos.
class HelpPill extends StatelessWidget {
  const HelpPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => pushInShell<void>(context, (_) => const AssistantScreen()),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.brand),
              SizedBox(width: 6),
              Text(
                'Ayuda',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.unread});

  final ValueListenable<int> unread;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unread,
      builder: (BuildContext context, int count, _) {
        return Semantics(
          button: true,
          label: count == 0
              ? 'Chat con el colegio'
              : 'Chat con el colegio, $count sin leer',
          child: InkResponse(
            key: const Key('abrir-chat'),
            radius: 24,
            onTap: () async {
              final ShellScope? shell = ShellScope.maybeOf(context);
              await pushInShell<void>(context, (_) => const SupportChatScreen());
              shell?.refreshChatUnread();
            },
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forum_outlined,
                      size: 19,
                      color: AppColors.ink,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBrand,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
