import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamkit_device/api/device_status_client.dart';
import 'package:roamkit_device/api/device_status_errors.dart';

void main() {
  const externalId = 'b8e6b629-abc1-4554-a0b1-77946afcf4a2';
  const credential = 'super-secret-credential-value';

  test('posts status body and parses snapshot', () async {
    late http.Request captured;
    final client = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'device_external_id': externalId,
            'binding_status': 'active',
            'esim': {'id': 1, 'iccid': '8910', 'status': 'ACTIVE'},
            'usage': {
              'data_remaining': '100 MB',
              'data_used': '50 MB',
              'expires_at': '2026-09-01T00:00:00Z',
            },
            'auto_topup': {'enabled': true},
            'checked_at': '2026-08-09T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final status = await client.fetchStatus(
      deviceExternalId: externalId,
      credential: credential,
    );

    expect(captured.url.toString(), 'https://api.example.test/api/v1/device/status/');
    expect(captured.method, 'POST');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['device_external_id'], externalId);
    expect(body['credential'], credential);
    expect(status.esim.status, 'ACTIVE');
    expect(status.usage.dataRemaining, '100 MB');
    expect(status.autoTopup.enabled, isTrue);
  });

  test('maps 404/429/network failures without echoing credential', () async {
    final notFound = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((_) async => http.Response('{"detail":"Nope"}', 404)),
    );
    await expectLater(
      notFound.fetchStatus(deviceExternalId: externalId, credential: credential),
      throwsA(isA<DeviceStatusNotFoundException>()),
    );

    final limited = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((_) async => http.Response('rate', 429)),
    );
    await expectLater(
      limited.fetchStatus(deviceExternalId: externalId, credential: credential),
      throwsA(isA<DeviceStatusRateLimitedException>()),
    );

    final network = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((_) async => throw http.ClientException('down')),
    );
    await expectLater(
      network.fetchStatus(deviceExternalId: externalId, credential: credential),
      throwsA(
        isA<DeviceStatusNetworkException>().having(
          (e) => e.message,
          'message',
          contains('api.example.test'),
        ),
      ),
    );
  });

  test('redactCredential removes secret from text', () {
    expect(
      redactCredential('failed with $credential in message', credential),
      'failed with [redacted] in message',
    );
  });
}
