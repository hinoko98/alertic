import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/network/server_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Una línea que dice con quién habla la app.
///
/// - **Datos de prueba**: no hay servidor. Nada de lo que se haga llega a nadie.
/// - **Conectado a `192.168.1.4:3000`**: el servidor respondió.
/// - **Sin conexión con `10.0.2.2:3000`**: no respondió. Toca para reintentar.
///
/// Es pequeña a propósito. No es una pantalla de configuración: es lo mínimo
/// para que quien ve «no funciona» sepa si es la red, la dirección o que nunca
/// se configuró un servidor.
class ServerStatusBadge extends StatefulWidget {
  const ServerStatusBadge({super.key});

  @override
  State<ServerStatusBadge> createState() => _ServerStatusBadgeState();
}

enum _Phase { checking, ok, down }

class _ServerStatusBadgeState extends State<ServerStatusBadge> {
  _Phase _phase = _Phase.checking;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _check();
    }
  }

  Future<void> _check() async {
    final ServerStatus status = AppScope.of(context).serverStatus;
    if (status.isDemo) {
      return;
    }

    setState(() => _phase = _Phase.checking);
    final bool alive = await status.check();
    if (mounted) {
      setState(() => _phase = alive ? _Phase.ok : _Phase.down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServerStatus status = AppScope.of(context).serverStatus;

    final (Color color, String text) = status.isDemo
        ? (
            AppColors.levelOrange,
            'DATOS DE PRUEBA · la app se lanzó sin ALERTIC_API, no usa el '
                'servidor. Nada de esto le llega a nadie.',
          )
        : switch (_phase) {
            _Phase.checking => (AppColors.inkFaint, 'Conectando con ${status.address}…'),
            _Phase.ok => (_okGreen, 'Conectado · ${status.address}'),
            _Phase.down => (
                AppColors.brand,
                'Sin conexión con ${status.address}. Toca para reintentar.',
              ),
          };

    return Semantics(
      label: text,
      child: InkWell(
        onTap: status.isDemo || _phase == _Phase.checking ? null : _check,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: color == AppColors.inkFaint ? AppColors.inkMuted : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _okGreen = Color(0xFF1E8E3E);
}
