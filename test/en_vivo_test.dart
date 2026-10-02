import 'dart:async';
import 'dart:convert';

import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/features/alerts/data/api_event_hub.dart';
import 'package:alertic/features/alerts/domain/live_updates.dart';
import 'package:alertic/features/guardian/data/api_guardian_repository.dart';
import 'package:alertic/features/guardian/domain/guardian_repository.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/safety_report.dart';
import 'package:alertic/features/incidents/data/api_incident_repository.dart';
import 'package:alertic/features/incidents/domain/incident.dart';
import 'package:alertic/features/teacher/data/api_teacher_repository.dart';
import 'package:alertic/features/teacher/domain/teacher_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// El canal en vivo y los adaptadores contra la API, sin servidor.
///
/// Un cliente HTTP simulado registra cada petición: qué ruta, con qué método y
/// con qué cuerpo. Es lo que permite comprobar que la app le habla al servidor
/// como el servidor espera, sin levantar nada.
void main() {
  group('el canal en vivo compartido', () {
    late StreamController<List<int>> wire;
    late int connections;
    late int closed;
    late ApiEventHub hub;

    /// Lo que el servidor «manda» por el canal.
    void serverSends(Map<String, Object?> event) {
      wire.add(utf8.encode('data: ${jsonEncode(event)}\n\n'));
    }

    setUp(() {
      connections = 0;
      closed = 0;
      wire = StreamController<List<int>>(onCancel: () => closed++);

      final MockClient client = MockClient.streaming(
        (http.BaseRequest request, http.ByteStream body) async {
          connections++;
          return http.StreamedResponse(wire.stream, 200);
        },
      );
      hub = ApiEventHub(ApiClient(baseUrl: 'http://colegio', httpClient: client));
    });

    tearDown(() async {
      if (!wire.isClosed) await wire.close();
    });

    test('varias partes de la app comparten UNA sola conexión', () async {
      // Sin esto, un celular tendría cuatro conexiones abiertas al servidor del
      // colegio —alerta, tablero, lista, hijos—, y 1.248 personas serían cinco
      // mil.
      final List<Map<String, dynamic>> a = <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> b = <Map<String, dynamic>>[];
      final StreamSubscription<Map<String, dynamic>> subA = hub.events.listen(a.add);
      final StreamSubscription<Map<String, dynamic>> subB = hub.events.listen(b.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      serverSends(<String, Object?>{'type': 'reporte', 'alertId': 'x'});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(connections, 1, reason: 'dos oyentes, una sola conexión');
      expect(a, hasLength(1));
      expect(b, hasLength(1), reason: 'los dos reciben lo mismo');

      await subA.cancel();
      await subB.cancel();
    });

    test('se cierra la conexión cuando se va el último oyente', () async {
      final StreamSubscription<Map<String, dynamic>> sub = hub.events.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(connections, 1);
      expect(closed, 0);

      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Una pantalla que se cierra no deja una conexión abierta contra el
      // servidor para siempre.
      expect(closed, 1);
    });

    test('traduce los mensajes del servidor a cambios', () async {
      final List<LiveChange> changes = <LiveChange>[];
      final StreamSubscription<LiveChange> sub =
          ApiLiveUpdates(hub).changes.listen(changes.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      serverSends(<String, Object?>{'type': 'reporte'});
      serverSends(<String, Object?>{'type': 'hijo_reporto'});
      serverSends(<String, Object?>{'type': 'aviso_externo'});
      serverSends(<String, Object?>{'type': 'incidente'});
      // Cosas que no son «algo cambió, vuelve a preguntar»: no son cambios.
      serverSends(<String, Object?>{'type': 'estado', 'alert': null});
      // Y un tipo que esta versión de la app no conoce, de un servidor más
      // nuevo: se ignora, no es un error.
      serverSends(<String, Object?>{'type': 'algo_del_futuro'});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(changes, <LiveChange>[
        LiveChange.reports,
        LiveChange.myChildren,
        LiveChange.hazardSignals,
        LiveChange.incidents,
      ]);

      await sub.cancel();
    });

    test('un mensaje ilegible no tumba el canal', () async {
      final List<Map<String, dynamic>> received = <Map<String, dynamic>>[];
      final StreamSubscription<Map<String, dynamic>> sub = hub.events.listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      wire.add(utf8.encode('data: {esto no es json\n\n'));
      serverSends(<String, Object?>{'type': 'reporte'});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // El roto se descarta; el siguiente llega. El estado completo se pide de
      // nuevo cada vez, así que perder uno no deja nada desactualizado.
      expect(received, hasLength(1));
      expect(received.single['type'], 'reporte');

      await sub.cancel();
    });
  });

  group('los adaptadores le hablan al servidor como lo espera', () {
    late List<http.Request> sent;
    late ApiClient api;

    /// Responde siempre con [body] y guarda lo que le mandaron.
    void serverAnswers(Object body, {int status = 200}) {
      sent = <http.Request>[];
      api = ApiClient(
        baseUrl: 'http://colegio',
        httpClient: MockClient((http.Request request) async {
          sent.add(request);
          return http.Response(
            jsonEncode(body),
            status,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      )..useToken('token-de-prueba');
    }

    test('el docente: la lista de un grupo codifica el grado', () async {
      serverAnswers(<String, Object?>{
        'students': <Object?>[
          <String, Object?>{
            'personId': 'p1',
            'fullName': 'Laura Camila Pérez Gómez',
            'status': 'a_salvo',
            'location': 'punto_encuentro',
            'reportedAt': '2026-09-30T21:04:00Z',
          },
          <String, Object?>{
            'personId': 'p2',
            'fullName': 'Sofía Arenas Villamizar',
            'status': null,
            'location': null,
            'reportedAt': null,
          },
        ],
      });

      final List<RosterEntry> roster =
          await ApiTeacherRepository(api).loadRoster('a1', '10° B');

      // «10° B» lleva grado y espacio: sin codificar, rompería la URL.
      expect(sent.single.url.path, '/alerts/a1/roster');
      expect(sent.single.url.queryParameters['grade'], '10° B');
      expect(sent.single.headers['authorization'], 'Bearer token-de-prueba');

      expect(roster, hasLength(2));
      expect(roster.first.status, SafetyStatus.safe);
      expect(roster.first.location, ReportedLocation.atMeetingPoint);
      expect(roster.last.hasResponded, isFalse, reason: 'sin reporte = sin responder');
    });

    test('el docente: marcar a salvo va a la ruta nueva, sin cuerpo', () async {
      serverAnswers(<String, Object?>{'ok': true});

      await ApiTeacherRepository(api).markSafe('a 1', 'p/1');

      expect(sent.single.method, 'POST');
      // Los identificadores van codificados: un `/` dentro de uno no puede
      // cambiar a qué ruta se le habla.
      expect(sent.single.url.path, '/alerts/a%201/roster/p%2F1/safe');
      expect(sent.single.body, isEmpty);
    });

    test('el docente: emitir manda lo que el servidor valida', () async {
      serverAnswers(<String, Object?>{
        'alert': <String, Object?>{
          'id': 'a1',
          'level': 'roja',
          'hazard': 'sismo',
          'title': 'SISMO',
          'scope': 'Todo el instituto',
          'meetingPoint': 'P1',
          'instructions': <String>['Sal en fila'],
          'issuedAt': '2026-09-30T21:04:00Z',
        },
      }, status: 201);

      await ApiTeacherRepository(api).issueAlert(
        const AlertDraft(
          level: AlertLevel.roja,
          hazard: Hazard.sismo,
          title: 'SISMO',
          scope: 'Todo el instituto',
          instructions: <String>['Sal en fila'],
          meetingPoint: 'P1',
          incidentId: 'inc-9',
        ),
      );

      final Map<String, dynamic> body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(sent.single.url.path, '/alerts');
      expect(body['level'], 'roja');
      expect(body['hazard'], 'sismo');
      expect(body['meetingPoint'], 'P1');
      expect(body['incidentId'], 'inc-9', reason: 'queda enlazada al reporte que la motivó');
    });

    test('el docente: si el servidor no confirma la alerta, no se finge', () async {
      serverAnswers(<String, Object?>{'alert': null}, status: 201);

      // Quien emite tiene que saber que no está seguro de haber avisado.
      await expectLater(
        ApiTeacherRepository(api).issueAlert(
          const AlertDraft(
            level: AlertLevel.amarilla,
            hazard: Hazard.lluvia,
            title: 'LLUVIA',
            scope: 'Todo el instituto',
            instructions: <String>['Atentos'],
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('el docente: el alcance es el que dice el servidor', () async {
      serverAnswers(<String, Object?>{'people': 8});
      expect(await ApiTeacherRepository(api).loadReach(), 8);

      serverAnswers(<String, Object?>{'people': 'muchos'});
      expect(await ApiTeacherRepository(api).loadReach(), isNull,
          reason: 'sin un número de verdad no se inventa uno');
    });

    test('el acudiente: en calma y con alerta son rutas distintas', () async {
      serverAnswers(<String, Object?>{
        'children': <Object?>[
          <String, Object?>{
            'fullName': 'Laura Camila Pérez Gómez',
            'grade': '10° B',
            'shift': 'Mañana',
            'homeroomTeacher': 'Carlos Jaimes',
            'meetingPoint': 'P1 · Cancha central',
            'status': 'necesita_ayuda',
            'location': 'salon',
            'reportedAt': '2026-09-30T21:05:00Z',
            'note': null,
          },
          <String, Object?>{
            'fullName': 'Andrés Felipe Pérez Gómez',
            'grade': '6° A',
            'shift': 'Mañana',
            'homeroomTeacher': 'Nubia Silva',
            'meetingPoint': 'P1 · Cancha central',
            'status': null,
            'location': null,
            'reportedAt': null,
            'note': 'Aún no confirma. Su director de grupo está pasando lista.',
          },
        ],
      });

      final List<ChildStatus> calm = await ApiGuardianRepository(api).loadChildren(null);
      expect(sent.last.url.toString(), 'http://colegio/children');

      await ApiGuardianRepository(api).loadChildren('a 1');
      expect(sent.last.url.path, '/children');
      expect(sent.last.url.queryParameters['alertId'], 'a 1');

      expect(calm.first.needsHelp, isTrue);
      expect(calm.last.isPending, isTrue);
      expect(calm.last.note, contains('pasando lista'));
    });

    test('el acudiente: sin teléfono publicado no se inventa uno', () async {
      serverAnswers(<String, Object?>{'name': 'IIC', 'phone': null});
      expect(await ApiGuardianRepository(api).loadSchoolPhone(), isNull);

      serverAnswers(<String, Object?>{'name': 'IIC', 'phone': '  (607) 555 0000 '});
      expect(await ApiGuardianRepository(api).loadSchoolPhone(), '(607) 555 0000');
    });

    test('los reportes: reportar manda solo lo que el servidor acepta', () async {
      serverAnswers(<String, Object?>{
        'incident': <String, Object?>{'id': 'i1', 'hazard': 'incendio', 'status': 'nuevo'},
      }, status: 201);

      await ApiIncidentRepository(api).report(Hazard.incendio);

      expect(sent.single.url.path, '/incidents');
      expect(jsonDecode(sent.single.body), <String, Object?>{'hazard': 'incendio'});
    });

    test('los reportes: si el servidor rechaza, el error llega a la pantalla', () async {
      serverAnswers(<String, Object?>{
        'error': 'demasiados_reportes',
        'message': 'Ya enviaste varios reportes y coordinación los está viendo.',
      }, status: 429);

      // Que NO se trague el error: la pantalla solo dice «enviado» si no lanza.
      await expectLater(
        ApiIncidentRepository(api).report(Hazard.sismo),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 429)
              .having((ApiException e) => e.message, 'message', contains('Ya enviaste')),
        ),
      );
    });

    test('los reportes: la bandeja descarta lo que no entiende', () async {
      serverAnswers(<String, Object?>{
        'incidents': <Object?>[
          <String, Object?>{
            'id': 'i1',
            'hazard': 'incendio',
            'details': 'detrás del bloque B',
            'status': 'nuevo',
            'createdAt': '2026-09-30T21:04:00Z',
            'handledBy': null,
            'reporter': <String, Object?>{
              'fullName': 'Laura Camila Pérez Gómez',
              'grade': '10° B',
              'role': 'estudiante',
            },
          },
          // Una amenaza que esta versión de la app no conoce.
          <String, Object?>{
            'id': 'i2',
            'hazard': 'zombis',
            'status': 'nuevo',
            'createdAt': '2026-09-30T21:04:00Z',
            'reporter': <String, Object?>{'fullName': 'X', 'grade': null, 'role': 'estudiante'},
          },
          // Sin quién lo reportó: una tarjeta sin eso no sirve de nada.
          <String, Object?>{
            'id': 'i3',
            'hazard': 'sismo',
            'status': 'nuevo',
            'createdAt': '2026-09-30T21:04:00Z',
          },
          'basura',
        ],
      });

      final List<Incident> open = await ApiIncidentRepository(api).loadOpen();

      expect(open, hasLength(1), reason: 'los otros tres se descartan, la bandeja no se rompe');
      expect(open.single.hazard, Hazard.incendio);
      expect(open.single.reporterName, startsWith('Laura'));
      expect(open.single.details, 'detrás del bloque B');
    });

    test('los reportes: atender va a la ruta del reporte, con el estado', () async {
      serverAnswers(<String, Object?>{'ok': true, 'status': 'atendido'});

      await ApiIncidentRepository(api).handle('inc 1', IncidentStatus.handled);

      expect(sent.single.url.path, '/incidents/inc%201/handle');
      expect(jsonDecode(sent.single.body), <String, Object?>{'status': 'atendido'});
    });
  });
}
