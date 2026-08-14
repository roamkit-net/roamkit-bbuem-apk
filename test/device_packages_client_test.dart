import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamkit_bbuem_apk/api/device_packages_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';

void main() {
  const externalId = 'b8e6b629-abc1-4554-a0b1-77946afcf4a2';
  const credential = 'super-secret-credential-value';

  Map<String, dynamic> samplePackages() => {
        'device_external_id': externalId,
        'iccid': '8900424101001825931',
        'results': [
          {
            'id': '1',
            'kind': 'esim',
            'status': 'active',
            'data_allowance': '1 GB',
            'validity_days': 7,
            'is_unlimited': false,
            'remaining_mb': 900,
            'created_at': '2026-08-01T00:00:00Z',
            'activated_at': '2026-08-12T10:50:00+00:00',
            'expires_at': '2026-08-19T10:50:00+00:00',
            'paid_usd': '11.50',
            'currency': 'USD',
          },
        ],
        'checked_at': '2026-08-09T00:00:00Z',
      };

  test('posts PR18 body without iccid and parses paid_usd', () async {
    late http.Request captured;
    final client = HttpDevicePackagesClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(samplePackages()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final snapshot = await client.fetchPackages(
      deviceExternalId: externalId,
      credential: credential,
    );

    expect(
      captured.url.toString(),
      'https://api.example.test/api/v1/device/packages/',
    );
    expect(captured.method, 'POST');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['device_external_id'], externalId);
    expect(body['credential'], credential);
    expect(body.containsKey('iccid'), isFalse);
    expect(body.containsKey('esim_id'), isFalse);
    expect(snapshot.iccid, '8900424101001825931');
    expect(snapshot.results, hasLength(1));
    expect(snapshot.results.single.paidUsd, '11.50');
    expect(snapshot.results.single.status, 'active');
  });

  test('posts serial-only body when deviceSerial is set', () async {
    const serial = '36281JEGR04531';
    late http.Request captured;
    final client = HttpDevicePackagesClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(samplePackages()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.fetchPackages(
      deviceSerial: serial,
      deviceExternalId: externalId,
      credential: credential,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, {'device_serial': serial});
    expect(body.containsKey('iccid'), isFalse);
  });

  test('maps 503 provider_unavailable', () async {
    final client = HttpDevicePackagesClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'provider_unavailable', 'detail': 'down'}),
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(
      () => client.fetchPackages(
        deviceExternalId: externalId,
        credential: credential,
      ),
      throwsA(isA<DevicePackagesProviderUnavailableException>()),
    );
  });

  test('404 does not echo credential', () async {
    final client = HttpDevicePackagesClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Not found. $credential'}),
          404,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    try {
      await client.fetchPackages(
        deviceExternalId: externalId,
        credential: credential,
      );
      fail('expected exception');
    } on DeviceStatusNotFoundException catch (error) {
      expect(error.message.contains(credential), isFalse);
    }
  });
}
