import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamkit_bbuem_apk/api/device_status_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';

void main() {
  const externalId = 'b8e6b629-abc1-4554-a0b1-77946afcf4a2';
  const credential = 'super-secret-credential-value';

  Map<String, dynamic> sampleSnapshot() => {
        'device_external_id': externalId,
        'binding_status': 'active',
        'esim': {'id': 1, 'iccid': '8910', 'status': 'ACTIVE'},
        'usage': {
          'data_remaining': '100 MB',
          'data_used': '50 MB',
          'expires_at': '2026-09-01T00:00:00Z',
        },
        'auto_topup': {'enabled': true},
        'plan': {
          'title': 'Cronet (Croatia)',
          'data_allowance': 'Unlimited',
          'validity_days': 3,
          'country_code': 'HR',
          'coverage_type': 'local',
          'location_title': 'Croatia',
        },
        'checked_at': '2026-08-09T00:00:00Z',
      };

  test('posts PR18 status body and parses snapshot', () async {
    late http.Request captured;
    final client = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(sampleSnapshot()),
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
    expect(body.containsKey('device_serial'), isFalse);
    expect(status.esim.status, 'ACTIVE');
    expect(status.usage.dataRemaining, '100 MB');
    expect(status.autoTopup.enabled, isTrue);
    expect(status.plan?.title, 'Cronet (Croatia)');
    expect(status.plan?.coverageType, 'local');
  });

  test('posts serial-only body when deviceSerial is set', () async {
    const serial = '36281JEGR04531';
    late http.Request captured;
    final client = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(sampleSnapshot()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final status = await client.fetchStatus(
      deviceSerial: serial,
      // PR18 fields must not be mixed into the body when serial is preferred.
      deviceExternalId: externalId,
      credential: credential,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, {'device_serial': serial});
    expect(status.esim.iccid, '8910');
  });

  test('maps 404 with code=iccid_not_found to ICCID miss message', () async {
    final client = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': 'No RoamKit data for this ICCID.',
            'code': 'iccid_not_found',
          }),
          404,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.fetchStatus(deviceExternalId: externalId, credential: credential),
      throwsA(
        isA<DeviceStatusIccidNotFoundException>().having(
          (e) => e.message,
          'message',
          'No RoamKit.net data for this ICCID',
        ),
      ),
    );
  });

  test('maps generic 404 without code to binding/credential message', () async {
    final client = HttpDeviceStatusClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((_) async => http.Response('{"detail":"Nope"}', 404)),
    );

    await expectLater(
      client.fetchStatus(deviceExternalId: externalId, credential: credential),
      throwsA(
        isA<DeviceStatusNotFoundException>().having(
          (e) => e.message,
          'message',
          'Device binding not found or credential invalid.',
        ),
      ),
    );
  });

  test(
    'maps 503 with code=uem_inventory_unavailable to inventory message',
    () async {
      final client = HttpDeviceStatusClient(
        apiBaseUrl: 'https://api.example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'detail': 'UEM telephony inventory unavailable',
              'code': 'uem_inventory_unavailable',
            }),
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.fetchStatus(deviceExternalId: externalId, credential: credential),
        throwsA(
          isA<DeviceStatusUemInventoryUnavailableException>().having(
            (e) => e.message,
            'message',
            'UEM SIM inventory is temporarily unavailable.',
          ),
        ),
      );
    },
  );

  test('maps 429/network failures without echoing credential', () async {
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

  test('statusErrorCodeFromBody reads code safely', () {
    expect(
      statusErrorCodeFromBody('{"code":"iccid_not_found","detail":"x"}'),
      'iccid_not_found',
    );
    expect(statusErrorCodeFromBody('{"detail":"Nope"}'), isNull);
    expect(statusErrorCodeFromBody('not-json'), isNull);
    expect(statusErrorCodeFromBody(''), isNull);
  });

  test('redactCredential removes secret from text', () {
    expect(
      redactCredential('failed with $credential in message', credential),
      'failed with [redacted] in message',
    );
  });
}
