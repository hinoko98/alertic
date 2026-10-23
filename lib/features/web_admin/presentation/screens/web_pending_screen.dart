import 'package:flutter/material.dart';

import '../web_nav.dart';
import '../web_style.dart';

/// Lo que se ve en una página del menú cuya pantalla todavía no está
/// construida. Dice qué falta en vez de fingir que existe.
class WebPendingScreen extends StatelessWidget {
  const WebPendingScreen({required this.page, super.key});

  final WebPage page;

  @override
  Widget build(BuildContext context) {
    return WebPageFrame(
      title: page.label,
      subtitle: 'Esta pantalla del panel web está en construcción.',
      children: <Widget>[
        WebPanel(
          child: Row(
            children: <Widget>[
              WebIconBubble(page.icon, tone: WebChipTone.neutral),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Todavía no está disponible en la versión web. Mientras tanto '
                  'puedes hacerlo desde la app del celular.',
                  style: TextStyle(fontSize: 14, color: WebColors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
