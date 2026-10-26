import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../onboarding/domain/credentials.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/enrollment_failure.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../../../session/domain/session.dart';
import '../../../teacher/domain/teacher_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

/// Nombre con el que el servidor identifica «todo el colegio».
const String _everyone = 'Todo el instituto';

/// Emitir una alerta a toda la comunidad.
///
/// Sigue las reglas de la app del docente: el título lo fija el sistema según la
/// amenaza (en una emergencia un texto libre que le llega a mil personas es un
/// riesgo que no hace falta correr), y lo que se escribe es el mensaje, una
/// instrucción por línea.
class WebAlertaScreen extends StatefulWidget {
  const WebAlertaScreen({
    required this.session,
    this.hazard,
    this.level,
    this.incidentId,
    this.drillId,
    super.key,
  });

  final Session session;

  /// Valores con los que arranca el formulario (una plantilla, un aviso externo).
  final Hazard? hazard;
  final AlertLevel? level;
  final String? incidentId;
  final String? drillId;

  @override
  State<WebAlertaScreen> createState() => _WebAlertaScreenState();
}

class _WebAlertaScreenState extends State<WebAlertaScreen> {
  late Hazard _hazard = widget.hazard ?? Hazard.sismo;
  late AlertLevel _level = widget.level ?? AlertLevel.roja;
  late bool _drill = widget.drillId != null;
  String _scope = _everyone;
  String? _meetingPoint;
  final TextEditingController _message = TextEditingController();

  List<Protocol> _protocols = const <Protocol>[];
  List<MeetingPoint> _points = const <MeetingPoint>[];
  List<GroupInfo> _groups = const <GroupInfo>[];
  int? _reach;
  bool _started = false;
  bool _edited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadContext();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final AppScope scope = AppScope.of(context);
    try {
      _protocols = await scope.alertRepository.loadProtocols();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'protocolos (alerta web)');
    }
    try {
      _points = await scope.alertRepository.loadMeetingPoints();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'puntos (alerta web)');
    }
    try {
      _groups = await scope.panelRepository?.loadGroups() ?? const <GroupInfo>[];
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'grupos (alerta web)');
    }
    try {
      _reach = await scope.teacherRepository?.loadReach();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'alcance (alerta web)');
    }
    if (!mounted) return;
    setState(_suggestMessage);
  }

  /// El mensaje por omisión sale del protocolo publicado, como en el celular:
  /// lo que se edita en Guías es exactamente lo que llega.
  void _suggestMessage() {
    if (_edited) return;
    _message.text = defaultInstructions(_hazard, _level, _protocols).join('\n');
  }

  static List<String> defaultInstructions(Hazard hazard, AlertLevel level, List<Protocol> protocols) {
    if (level == AlertLevel.roja) {
      for (final Protocol p in protocols) {
        if (p.hazard == hazard && p.duringSteps.isNotEmpty) {
          return <String>[
            for (final String step in p.duringSteps.take(6))
              step.length > 120 ? step.substring(0, 120) : step,
          ];
        }
      }
      return const <String>[
        'Sal con tu grupo, en fila y sin correr',
        'No vuelvas por nada',
        'Ve a tu punto de encuentro',
      ];
    }
    if (level == AlertLevel.naranja) {
      return const <String>[
        'Guarda tus cosas',
        'Ubícate cerca de la puerta con tu grupo',
        'Espera la indicación de salir',
      ];
    }
    return const <String>[
      'Mantente atento a las indicaciones de tu docente',
      'No hace falta salir del salón',
    ];
  }

  static String titleFor(Hazard hazard, AlertLevel level, {bool drill = false}) {
    if (drill) {
      return switch (hazard) {
        Hazard.sismo => 'SIMULACRO DE SISMO',
        Hazard.incendio => 'SIMULACRO DE INCENDIO',
        Hazard.inundacion => 'SIMULACRO DE INUNDACIÓN',
        Hazard.lluvia => 'SIMULACRO DE LLUVIAS',
      };
    }
    return switch (hazard) {
      Hazard.sismo => level == AlertLevel.roja ? 'SISMO' : 'SISMO REPORTADO',
      Hazard.incendio => 'INCENDIO',
      Hazard.inundacion => 'CRECIENTE DE LA QUEBRADA',
      Hazard.lluvia => 'LLUVIA FUERTE',
    };
  }

  List<String> get _lines => _message.text
      .split('\n')
      .map((String l) => l.trim())
      .where((String l) => l.isNotEmpty)
      .toList();

  String? get _problem {
    final List<String> lines = _lines;
    if (lines.isEmpty) return 'Escribe al menos una instrucción.';
    if (lines.length > Alert.maxInstructions) {
      return 'Máximo ${Alert.maxInstructions} instrucciones (una por línea).';
    }
    if (lines.any((String l) => l.length > Alert.maxInstructionLength)) {
      return 'Cada instrucción puede tener hasta ${Alert.maxInstructionLength} caracteres.';
    }
    return null;
  }

  AlertDraft _draft() => AlertDraft(
        level: _level,
        hazard: _hazard,
        title: titleFor(_hazard, _level, drill: _drill),
        scope: _scope,
        meetingPoint: _meetingPoint,
        instructions: _lines,
        incidentId: widget.incidentId,
        drill: _drill,
        drillId: widget.drillId,
      );

  void _template(Hazard hazard, AlertLevel level, {String scope = _everyone}) {
    setState(() {
      _hazard = hazard;
      _level = level;
      _scope = scope;
      _edited = false;
      _suggestMessage();
    });
  }

  static const Map<AlertLevel, (String, Color)> _levels = <AlertLevel, (String, Color)>{
    AlertLevel.amarilla: ('Informativo', Color(0xFF5B6670)),
    AlertLevel.naranja: ('Precaución', Color(0xFFC98A00)),
    AlertLevel.roja: ('Evacuar', WebColors.brand),
  };

  @override
  Widget build(BuildContext context) {
    final String? problem = _problem;
    final Map<String, String> scopes = <String, String>{
      _everyone: 'Todo el colegio',
      for (final GroupInfo g in _groups) g.grade: g.grade,
    };
    final Map<String?, String> points = <String?, String>{
      null: 'El principal del colegio',
      for (final MeetingPoint p in _points) p.code: '${p.code} · ${p.name}',
    };

    return WebPageFrame(
      title: 'Emitir alerta',
      subtitle: 'Llega a todos los celulares del colegio en segundos',
      actions: const <Widget>[WebChip('Revisa antes de enviar: no se puede deshacer', tone: WebChipTone.warn)],
      children: <Widget>[
        WebSplit(
          main: WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                WebLabeled(
                  label: 'Tipo de evento',
                  child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    for (final Hazard h in Hazard.values)
                      WebOption(
                        label: _hazardName(h),
                        selected: h == _hazard,
                        onTap: () => setState(() {
                          _hazard = h;
                          _suggestMessage();
                        }),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                WebLabeled(
                  label: 'Nivel',
                  child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    for (final MapEntry<AlertLevel, (String, Color)> e in _levels.entries)
                      WebOption(
                        label: e.value.$1,
                        dot: e.value.$2,
                        selected: e.key == _level,
                        onTap: () => setState(() {
                          _level = e.key;
                          _suggestMessage();
                        }),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                WebGrid(
                  minWidth: 260,
                  children: <Widget>[
                    WebSelect<String>(
                      label: 'Zona afectada',
                      value: _scope,
                      items: scopes,
                      onChanged: (String? v) => setState(() => _scope = v ?? _everyone),
                    ),
                    WebSelect<String?>(
                      label: 'Punto de encuentro',
                      value: _meetingPoint,
                      items: points,
                      onChanged: (String? v) => setState(() => _meetingPoint = v),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                WebTextArea(
                  label: 'Mensaje para la comunidad (una instrucción por línea)',
                  controller: _message,
                  minLines: 4,
                  onChanged: (_) => setState(() => _edited = true),
                ),
                const SizedBox(height: 4),
                Text(
                  problem ?? '${_lines.length} de ${Alert.maxInstructions} instrucciones',
                  style: WebText.small.copyWith(color: problem == null ? WebColors.inkMuted : WebColors.brand),
                ),
                const SizedBox(height: 14),
                WebToggleRow(
                  title: 'Es un simulacro',
                  subtitle: 'Se marca como práctica en todas las pantallas',
                  value: _drill,
                  onChanged: widget.drillId != null ? null : (bool v) => setState(() => _drill = v),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 50,
                    child: WebButton(
                      label: _reach == null ? 'Enviar alerta' : 'Enviar alerta a ${_thousands(_reach!)} personas',
                      icon: Icons.send_outlined,
                      onPressed: problem != null
                          ? null
                          : () => WebNav.of(context).open(
                                WebAlertaConfirmScreen(session: widget.session, draft: _draft(), reach: _reach),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          side: Column(
            children: <Widget>[
              WebPanel(
                child: Column(
                  children: <Widget>[
                    const WebPanelHeader(title: 'Así lo verán', trailing: WebChip('Vista previa')),
                    const SizedBox(height: 14),
                    _PhonePreview(
                      title: titleFor(_hazard, _level, drill: _drill),
                      scope: _scope == _everyone ? 'Evacuación de todo el colegio' : _scope,
                      lines: _lines,
                      level: _level,
                      drill: _drill,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const WebPanelHeader(title: 'Plantillas rápidas'),
                    const SizedBox(height: 12),
                    WebButton(
                      label: 'Sismo · Evacuar todo el colegio',
                      secondary: true,
                      onPressed: () => _template(Hazard.sismo, AlertLevel.roja),
                    ),
                    const SizedBox(height: 8),
                    WebButton(
                      label: 'Lluvias · Precaución',
                      secondary: true,
                      onPressed: () => _template(Hazard.lluvia, AlertLevel.naranja),
                    ),
                    const SizedBox(height: 8),
                    WebButton(
                      label: 'Incendio · Evacuar',
                      secondary: true,
                      onPressed: () => _template(Hazard.incendio, AlertLevel.roja),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _hazardName(Hazard h) => switch (h) {
        Hazard.sismo => 'Sismo',
        Hazard.inundacion => 'Inundación',
        Hazard.lluvia => 'Lluvias fuertes',
        Hazard.incendio => 'Incendio',
      };
}

String _thousands(int value) {
  final String s = value.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

/// El celular con la alerta tal como la verá la gente.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({
    required this.title,
    required this.scope,
    required this.lines,
    required this.level,
    required this.drill,
  });

  final String title;
  final String scope;
  final List<String> lines;
  final AlertLevel level;
  final bool drill;

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (level) {
      AlertLevel.roja => WebColors.brand,
      AlertLevel.naranja => const Color(0xFFEE7811),
      AlertLevel.amarilla => const Color(0xFFC98A00),
    };
    return Container(
      width: 220,
      height: 400,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF161E26), borderRadius: BorderRadius.circular(30)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  drill ? '● SIMULACRO' : '● ALERTA ACTIVA',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF8A1C2D)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(scope, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int i = 0; i < lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${i + 1}. ${lines[i]}', style: const TextStyle(fontSize: 10, color: Colors.white, height: 1.4)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                for (final String label in <String>['Estoy a salvo', 'Necesito ayuda'])
                  Expanded(
                    child: Container(
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «¿Enviar esta alerta real?»: repite lo que se va a enviar y pide la
/// contraseña, porque emitir una alerta no se puede deshacer.
class WebAlertaConfirmScreen extends StatefulWidget {
  const WebAlertaConfirmScreen({required this.session, required this.draft, this.reach, super.key});

  final Session session;
  final AlertDraft draft;
  final int? reach;

  @override
  State<WebAlertaConfirmScreen> createState() => _WebAlertaConfirmScreenState();
}

class _WebAlertaConfirmScreenState extends State<WebAlertaConfirmScreen> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final AppScope scope = AppScope.of(context);
    final WebNav nav = WebNav.of(context);
    final Enrollment profile = widget.session.profile;
    final String? email = profile is AdminEnrollment ? profile.email : null;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Pedir la contraseña de nuevo prueba que quien está frente a la pantalla es
      // quien abrió la sesión. Se comprueba entrando otra vez con ella.
      final (Credentials? credentials, String? problem) =
          Credentials.tryBuild(email: email ?? '', password: _password.text);
      if (credentials == null) {
        setState(() => _error = _password.text.isEmpty ? 'Escribe tu contraseña.' : problem);
        return;
      }
      final Session fresh = await scope.credentialsRepository.signIn(credentials);
      await scope.sessionStore.save(fresh);

      final Alert alert = await scope.teacherRepository!.issueAlert(widget.draft);
      ErrorReporter.trace('alerta ${alert.level.wire} emitida', context: 'panel web');
      nav.refreshBadges();
      nav.open(WebAlertaSentScreen(alert: alert));
    } on EnrollmentFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'emitir alerta (panel web)');
      if (mounted) setState(() => _error = 'No se pudo enviar la alerta. Revisa la conexión e inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AlertDraft d = widget.draft;
    final String level = switch (d.level) {
      AlertLevel.roja => 'Rojo · Evacuar',
      AlertLevel.naranja => 'Naranja · Precaución',
      AlertLevel.amarilla => 'Amarillo · Informativo',
    };
    return WebPageFrame(
      title: d.drill ? '¿Enviar este simulacro?' : '¿Enviar esta alerta real?',
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: WebPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  WebGrid(
                    minWidth: 200,
                    gap: 10,
                    children: <Widget>[
                      _Fact('Evento', d.title),
                      _Fact('Nivel', level),
                      _Fact('Zona', d.scope == _everyone ? 'Todo el colegio' : d.scope),
                      _Fact('Llega a', widget.reach == null ? 'Toda la comunidad' : '${_thousands(widget.reach!)} personas'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: WebColors.page, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int i = 0; i < d.instructions.length; i++)
                          Text('${i + 1}. ${d.instructions[i]}', style: WebText.body.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  WebField(
                    label: 'Escribe tu contraseña para confirmar',
                    controller: _password,
                    obscure: true,
                    enabled: !_busy,
                    onSubmitted: (_) => _send(),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      WebButton(label: 'Volver y corregir', secondary: true, onPressed: _busy ? null : WebNav.of(context).back),
                      WebButton(label: d.drill ? 'Sí, enviar simulacro' : 'Sí, enviar alerta', busy: _busy, onPressed: _send),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: WebColors.page, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: WebText.kpiLabel),
          Text(value, style: WebText.strong.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

/// La alerta ya salió: cómo va y qué sigue.
class WebAlertaSentScreen extends StatefulWidget {
  const WebAlertaSentScreen({required this.alert, super.key});

  final Alert alert;

  @override
  State<WebAlertaSentScreen> createState() => _WebAlertaSentScreenState();
}

class _WebAlertaSentScreenState extends State<WebAlertaSentScreen> {
  late Future<EmergencyBoard?> _board;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _board = _load();
  }

  Future<EmergencyBoard?> _load() async {
    try {
      return await AppScope.of(context).panelRepository?.loadBoard(widget.alert.id);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tablero tras emitir (panel web)');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Alert a = widget.alert;
    return WebPageFrame(
      title: a.isDrill ? 'Simulacro enviado' : 'Alerta enviada',
      subtitle: '${a.title} · ${a.level.meaning} · ${Fmt.hour(a.issuedAt)}',
      actions: <Widget>[
        WebButton(
          label: 'Ir al monitoreo en vivo',
          onPressed: () => WebNav.of(context).go(WebPage.monitoreo),
        ),
      ],
      children: <Widget>[
        WebPanel(
          child: FutureBuilder<EmergencyBoard?>(
            future: _board,
            builder: (BuildContext context, AsyncSnapshot<EmergencyBoard?> snap) {
              final EmergencyBoard? b = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WebPanelHeader(title: 'Estado al enviar', trailing: WebChip('● Entregando', tone: WebChipTone.good)),
                  const SizedBox(height: 12),
                  if (snap.connectionState != ConnectionState.done)
                    const WebLoadState()
                  else if (b == null)
                    Text('No pudimos consultar el tablero todavía. Míralo en el monitoreo en vivo.', style: WebText.small)
                  else ...<Widget>[
                    WebGrid(minWidth: 220, children: <Widget>[
                      WebStat(label: 'A salvo', value: _thousands(b.safe), valueColor: WebColors.good),
                      WebStat(label: 'Sin confirmar', value: _thousands(b.noResponse)),
                      WebStat(label: 'Piden ayuda', value: _thousands(b.needHelp), valueColor: b.needHelp > 0 ? WebColors.brand : WebColors.ink),
                    ]),
                    const SizedBox(height: 14),
                    WebMeter(fraction: b.total == 0 ? 0 : b.safe / b.total, color: WebColors.good, height: 14),
                  ],
                ],
              );
            },
          ),
        ),
        WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const WebPanelHeader(title: 'Próximos pasos'),
              const SizedBox(height: 12),
              for (final (int, String) step in <(int, String)>[
                (1, 'Sigue en el monitoreo quién confirma a salvo.'),
                (2, 'Revisa las listas que envían los docentes desde los puntos.'),
                (3, 'Cuando sea seguro, finaliza la alerta.'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      WebChip('${step.$1}', tone: WebChipTone.dark),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step.$2, style: WebText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
