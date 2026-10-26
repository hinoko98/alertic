import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../panel/domain/community_admin.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

/// Los grupos del colegio con su director y su salón.
class WebGruposScreen extends StatefulWidget {
  const WebGruposScreen({super.key});

  @override
  State<WebGruposScreen> createState() => _WebGruposScreenState();
}

class _WebGruposScreenState extends State<WebGruposScreen> {
  late Future<List<GroupInfo>> _groups;
  bool _onlyWithout = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _groups = AppScope.of(context).panelRepository!.loadGroups());

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebFuture<List<GroupInfo>>(
      future: _groups,
      onRetry: _reload,
      builder: (BuildContext context, List<GroupInfo> groups) {
        final int without = groups.where((GroupInfo g) => g.director == null).length;
        final List<GroupInfo> shown =
            _onlyWithout ? groups.where((GroupInfo g) => g.director == null).toList() : groups;
        return WebPageFrame(
          title: 'Grupos',
          subtitle: 'Cada grupo con su director y su salón',
          actions: <Widget>[
            const WebBackButton(),
            WebButton(label: 'Ver docentes', onPressed: () => nav.go(WebPage.docentes)),
          ],
          children: <Widget>[
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              WebOption(label: 'Todos · ${groups.length}', selected: !_onlyWithout, onTap: () => setState(() => _onlyWithout = false)),
              WebOption(label: 'Sin director · $without', selected: _onlyWithout, onTap: () => setState(() => _onlyWithout = true)),
            ]),
            if (shown.isEmpty)
              Text('No hay grupos con ese filtro.', style: WebText.small)
            else
              WebGrid(
                minWidth: 260,
                children: <Widget>[
                  for (final GroupInfo g in shown)
                    WebPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(g.grade, style: WebText.panelTitle.copyWith(fontSize: 20)),
                          Text('${g.enrolled} estudiantes', style: WebText.small),
                          if (g.classroom != null) Text(g.classroom!, style: WebText.small),
                          const SizedBox(height: 14),
                          if (g.director != null)
                            Row(children: <Widget>[
                              WebAvatar(g.director!.fullName),
                              const SizedBox(width: 10),
                              Expanded(child: Text(g.director!.fullName, style: WebText.strong)),
                            ])
                          else
                            WebButton(label: 'Asignar director', small: true, onPressed: () => nav.go(WebPage.docentes)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
