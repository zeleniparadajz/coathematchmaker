import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/services/api_client.dart';

void main() {
  test('Concurrent identical GET requests share one network call', () async {
    var count = 0;
    final response = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((_) {
        count++;
        return response.future;
      }),
    );
    addTearDown(api.close);
    final first = api.getJson('/api/players');
    final second = api.getJson('/api/players');
    response.complete(http.Response('{"players":[]}', 200));
    expect(await first, await second);
    expect(count, 1);
    await api.getJson('/api/players');
    expect(count, 2);
  });

  test(
    'HTML gateway errors and connectivity errors are actionable API errors',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response('<html>Bad gateway</html>', 502),
        ),
      );
      addTearDown(api.close);
      expect(api.getJson('/api/players'), throwsA(isA<ApiException>()));
      final offline = ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(offline.close);
      expect(offline.getJson('/api/players'), throwsA(isA<ApiException>()));
    },
  );
}
