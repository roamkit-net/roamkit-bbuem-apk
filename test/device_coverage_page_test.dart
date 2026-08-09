import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage_client.dart';
import 'package:roamkit_bbuem_apk/ui/device_coverage_page.dart';

class _FakeCoverageClient implements DeviceCoverageClient {
  _FakeCoverageClient(this.coverage);

  DeviceCoverage coverage;
  int calls = 0;
  String? lastSerial;
  String? lastExternalId;
  String? lastCredential;

  @override
  Future<DeviceCoverage> fetchCoverage({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    calls += 1;
    lastSerial = deviceSerial;
    lastExternalId = deviceExternalId;
    lastCredential = credential;
    return coverage;
  }
}

DeviceCoverage _sampleCoverage({String type = 'regional'}) {
  return DeviceCoverage(
    deviceExternalId: 'dev-1',
    coverageType: type,
    coverage: const [
      DeviceCoverageCountry(
        countryCode: 'HR',
        countryName: 'Croatia',
        operators: ['A1', 'Telemach'],
      ),
      DeviceCoverageCountry(
        countryCode: 'SI',
        countryName: null,
        operators: [],
      ),
    ],
    checkedAt: DateTime.utc(2026, 8, 9),
  );
}

void main() {
  testWidgets('renders countries summary and operators; empty ops omit line', (
    tester,
  ) async {
    final client = _FakeCoverageClient(_sampleCoverage());

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCoveragePage(
          deviceExternalId: 'dev-1',
          credential: 'secret',
          coverageClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('2 countries'), findsOneWidget);
    expect(find.text('Croatia'), findsOneWidget);
    expect(find.text('A1 · Telemach'), findsOneWidget);
    expect(find.text('SI'), findsOneWidget);
    expect(find.text(' · '), findsNothing);
    expect(client.calls, 1);
    expect(client.lastExternalId, 'dev-1');
    expect(client.lastCredential, 'secret');
    expect(client.lastSerial, isNull);
  });

  testWidgets('serial path posts device_serial only', (tester) async {
    final client = _FakeCoverageClient(_sampleCoverage());

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCoveragePage(
          deviceSerial: '36281JEGR04531',
          deviceExternalId: 'dev-1',
          credential: 'secret-must-not-be-sent',
          coverageClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.calls, 1);
    expect(client.lastSerial, '36281JEGR04531');
    expect(client.lastExternalId, isNull);
    expect(client.lastCredential, isNull);
    expect(find.text('Croatia'), findsOneWidget);
  });

  testWidgets('handles 100+ countries without crash', (tester) async {
    final countries = [
      for (var i = 0; i < 120; i++)
        DeviceCoverageCountry(
          countryCode: String.fromCharCodes([
            0x41 + (i ~/ 26),
            0x41 + (i % 26),
          ]),
          countryName: 'Country $i',
          operators: const ['OpA', 'OpB', 'OpC'],
        ),
    ];
    final client = _FakeCoverageClient(
      DeviceCoverage(
        deviceExternalId: 'dev-1',
        coverageType: 'global',
        coverage: countries,
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCoveragePage(
          deviceExternalId: 'dev-1',
          credential: 'secret',
          coverageClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('120 countries'), findsOneWidget);
    expect(find.text('Country 0'), findsOneWidget);
  });
}
