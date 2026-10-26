import 'dart:convert';

import 'package:alertic/core/cache/response_cache.dart';
import 'package:alertic/core/network/api_client.dart';
import 'package:alertic/features/alerts/data/api_alert_repository.dart';
import 'package:alertic/features/alerts/domain/hazard.dart';
import 'package:alertic/features/alerts/domain/protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// La caché local: guarda lo que se consulta sin red y solo responde cuando el
/// servidor no contesta.
void main() {
  /// Un servidor que se puede apagar a mitad de la prueba.
  late bool online;
  late int status;
  late Map<String, Object?> body;

  ApiClient client() => ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((http.Request request) async {
          if (!online) throw http.ClientException('Sin red', request.url);
          return http.Response(
            jsonEncode(body),
            status,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

  setUp(() {
    online = true;
    status = 200;
    body = <String, Object?>{'value': 1};
  });

  test('con servidor responde el servidor y guarda la respuesta', () async {
    final MemoryResponseCache cache = MemoryResponseCache();
    final Map<String, dynamic> got = await cachedGet(client(), cache, '/protocols');

    expect(got['value'], 1);
    await Future<void>.delayed(Duration.zero);
    expect((await cache.read('/protocols'))?['value'], 1);
  });

  test('sin servidor devuelve lo último guardado', () async {
    final MemoryResponseCache cache = MemoryResponseCache();
    final ApiClient api = client();
    await cachedGet(api, cache, '/protocols');
    await Future<void>.delayed(Duration.zero);

    online = false;
    body = <String, Object?>{'value': 2};
    final Map<String, dynamic> got = await cachedGet(api, cache, '/protocols');
    expect(got['value'], 1);
  });

  test('sin servidor y sin nada guardado, el error sigue', () async {
    online = false;
    expect(
      () => cachedGet(client(), MemoryResponseCache(), '/protocols'),
      throwsA(isA<ApiException>()),
    );
  });

  test('si el servidor responde con error, la caché no lo tapa', () async {
    final MemoryResponseCache cache = MemoryResponseCache();
    await cache.write('/protocols', <String, dynamic>{'value': 1});
    status = 401;
    body = <String, Object?>{'error': 'sesion_vencida', 'message': 'Tu sesión venció.'};

    expect(
      () => cachedGet(client(), cache, '/protocols'),
      throwsA(isA<ApiException>().having((ApiException e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('los protocolos se leen sin red después de haberlos visto una vez', () async {
    body = <String, Object?>{
      'protocols': <Object?>[
        <String, Object?>{
          'hazard': 'sismo',
          'beforeSteps': <String>['Ubica tu punto'],
          'duringSteps': <String>['Agáchate, cúbrete y sujétate'],
          'afterSteps': <String>['Sal con tu grupo'],
        },
      ],
    };
    final ApiAlertRepository repository = ApiAlertRepository(client(), cache: MemoryResponseCache());
    await repository.loadProtocols();
    await Future<void>.delayed(Duration.zero);

    online = false;
    final List<Protocol> offline = await repository.loadProtocols();
    expect(offline.single.hazard, Hazard.sismo);
  });
}
