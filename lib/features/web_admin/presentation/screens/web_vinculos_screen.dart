import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

/// Acudientes que pidieron vincularse a un estudiante y esperan la decisión del
/// colegio. Si su documento coincide con la matrícula quedan vinculados solos;
/// los demás llegan aquí.
class WebVinculosScreen extends StatefulWidget {
  const WebVinculosScreen({super.key});

  @override
  State<WebVinculosScreen> createState() => _WebVinculosScreenState();
}

class _WebVinculosScreenState extends State<WebVinculosScreen> {
  late Future<List<GuardianRequest>> _requests;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _requests = AppScope.of(context).panelRepository!.loadGuardianRequests());

  static String _reason(GuardianRequest r) =>
      r.matchesRoster ? 'Figura en la matrícula' : 'No figura en la matrícula';

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Vincular acudientes',
      subtitle: 'Los acudientes se registran en la app con el documento del estudiante. Aquí decides los que no coinciden con la matrícula.',
      children: <Widget>[
        WebFuture<List<GuardianRequest>>(
          future: _requests,
          onRetry: _reload,
          builder: (BuildContext context, List<GuardianRequest> list) => WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                WebPanelHeader(
                  title: 'Solicitudes por revisar',
                  trailing: WebChip('${list.length}', tone: list.isEmpty ? WebChipTone.neutral : WebChipTone.warn),
                ),
                const SizedBox(height: 8),
                WebTable(
                  headers: const <String>['Acudiente', 'Estudiante', 'Parentesco', 'Motivo', ''],
                  empty: 'No hay solicitudes pendientes.',
                  rows: <List<Widget>>[
                    for (final GuardianRequest r in list)
                      <Widget>[
                        WebTitleSub(
                          r.fullName,
                          sub: r.document == null ? null : '${r.documentType ?? ''} ${r.document}'.trim(),
                          onTap: () => nav.open(WebVinculoDetalleScreen(request: r)),
                        ),
                        Text('${r.studentName}${r.grade == null ? '' : ' · ${r.grade}'}'),
                        Text(r.relationship),
                        WebChip(_reason(r), tone: r.matchesRoster ? WebChipTone.good : WebChipTone.warn),
                        WebButton(
                          label: 'Revisar',
                          small: true,
                          onPressed: () => nav.open(WebVinculoDetalleScreen(request: r)),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const WebNotice('Antes de aprobar, confirma con el acudiente principal o con su documento en secretaría.'),
      ],
    );
  }
}

/// La solicitud completa y la decisión.
class WebVinculoDetalleScreen extends StatefulWidget {
  const WebVinculoDetalleScreen({required this.request, super.key});

  final GuardianRequest request;

  @override
  State<WebVinculoDetalleScreen> createState() => _WebVinculoDetalleScreenState();
}

class _WebVinculoDetalleScreenState extends State<WebVinculoDetalleScreen> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final GuardianRequest r = widget.request;
    final bool ok = await webConfirm(
      context,
      title: approve ? 'Aprobar vinculación' : 'Rechazar solicitud',
      message: approve
          ? '${r.fullName} quedará vinculado(a) a ${r.studentName} y recibirá sus avisos en una emergencia.'
          : 'La solicitud de ${r.fullName} se cierra y no se vincula a ${r.studentName}.',
      confirm: approve ? 'Aprobar' : 'Rechazar',
      danger: !approve,
    );
    if (!ok || !mounted) return;

    final WebNav nav = WebNav.of(context);
    final PanelRepository repo = AppScope.of(context).panelRepository!;
    setState(() => _busy = true);
    try {
      if (approve) {
        await repo.approveGuardianRequest(r.id);
      } else {
        await repo.rejectGuardianRequest(r.id);
      }
      nav.refreshBadges();
      nav.back();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'decidir vinculación (panel web)');
      if (mounted) webToast(context, 'No se pudo guardar la decisión.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuardianRequest r = widget.request;
    return WebPageFrame(
      title: 'Revisar solicitud de vinculación',
      subtitle: '${r.fullName} quiere vincularse a ${r.studentName} · ${Fmt.dayMonth(r.createdAt)} ${Fmt.hour(r.createdAt)}',
      actions: const <Widget>[WebBackButton()],
      children: <Widget>[
        WebGrid(minWidth: 340, children: <Widget>[
          WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WebPanelHeader(title: 'Lo que escribió en la app', trailing: WebChip('Por revisar', tone: WebChipTone.warn)),
                const SizedBox(height: 8),
                WebKeyValue('Nombre', r.fullName),
                if (r.document != null) WebKeyValue('Documento', '${r.documentType ?? ''} ${r.document}'.trim()),
                if (r.phone != null) WebKeyValue('Celular', r.phone!),
                if (r.email != null) WebKeyValue('Correo', r.email!),
                WebKeyValue('Parentesco', r.relationship),
                WebKeyValue('Estudiante buscado', '${r.studentName}${r.grade == null ? '' : ' · ${r.grade}'}'),
              ],
            ),
          ),
          WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WebPanelHeader(title: 'Lo que dice la matrícula'),
                const SizedBox(height: 12),
                if (r.matchesRoster)
                  const WebNotice('El documento ya figura como acudiente de este estudiante en la matrícula.', icon: Icons.check_circle_outline, tone: WebChipTone.good)
                else
                  const WebNotice(
                    'Ese documento no figura como acudiente de este estudiante. Confírmalo con otro acudiente o pide que se acerque a secretaría con su cédula.',
                    icon: Icons.warning_amber_outlined,
                    tone: WebChipTone.warn,
                  ),
              ],
            ),
          ),
        ]),
        WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const WebPanelHeader(title: 'Decisión'),
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 8, children: <Widget>[
                WebButton(label: 'Aprobar vinculación', busy: _busy, onPressed: () => _decide(true)),
                WebButton(label: 'Rechazar', secondary: true, onPressed: _busy ? null : () => _decide(false)),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
