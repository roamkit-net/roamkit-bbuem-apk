import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';

void main() {
  const externalId = 'b8e6b629-abc1-4554-a0b1-77946afcf4a2';
  const credential = 'super-secret-credential-value';

  Map<String, dynamic> sampleCoverage() => {
        'device_external_id': externalId,
        'coverage_type': 'regional',
        'coverage': [
          {
            'country_code': 'HR',
            'country_name': 'Croatia',
            'operators': ['A1', 'Telemach'],
          },
          {
            'country_code': 'SI',
            'country_name': null,
            'operators': [],
          },
        ],
        'checked_at': '2026-08-09T00:00:00Z',
      };

  test('posts PR18 coverage body and parses countries', () async {
    late http.Request captured;
    final client = HttpDeviceCoverageClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(sampleCoverage()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final coverage = await client.fetchCoverage(
      deviceExternalId: externalId,
      credential: credential,
    );

    expect(
      captured.url.toString(),
      'https://api.example.test/api/v1/device/coverage/',
    );
    expect(captured.method, 'POST');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['device_external_id'], externalId);
    expect(body['credential'], credential);
    expect(body.containsKey('device_serial'), isFalse);
    expect(body.containsKey('esim_id'), isFalse);
    expect(coverage.coverageType, 'regional');
    expect(coverage.coverage, hasLength(2));
    expect(coverage.coverage![0].countryName, 'Croatia');
    expect(coverage.coverage![0].operators, ['A1', 'Telemach']);
    expect(coverage.coverage![1].displayName, 'SI');
    expect(coverage.coverage![1].operators, isEmpty);
  });

  test('posts serial-only body when deviceSerial is set', () async {
    const serial = '36281JEGR04531';
    late http.Request captured;
    final client = HttpDeviceCoverageClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(sampleCoverage()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.fetchCoverage(
      deviceSerial: serial,
      deviceExternalId: externalId,
      credential: credential,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, {'device_serial': serial});
  });

  test('legacy null coverage parses', () async {
    final client = HttpDeviceCoverageClient(
      apiBaseUrl: 'https://api.example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'device_external_id': externalId,
            'coverage_type': 'regional',
            'coverage': null,
            'checked_at': '2026-08-09T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final coverage = await client.fetchCoverage(
      deviceExternalId: externalId,
      credential: credential,
    );
    expect(coverage.coverage, isNull);
  });

  test('404 does not echo credential', () async {
    final client = HttpDeviceCoverageClient(
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
      await client.fetchCoverage(
        deviceExternalId: externalId,
        credential: credential,
      );
      fail('expected exception');
    } on DeviceStatusNotFoundException catch (error) {
      expect(error.message.contains(credential), isFalse);
    }
  });
}
