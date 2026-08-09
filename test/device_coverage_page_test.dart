import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage_client.dart';
import 'package:roamkit_bbuem_apk/ui/device_coverage_page.dart';

class _FakeCoverageClient implements DeviceCoverageClient {
  _FakeCoverageClient(this.coverage);

  DeviceCoverage coverage;
  int calls = 0;

  @override
  Future<DeviceCoverage> fetchCoverage({
    required String deviceExternalId,
    required String credential,
  }) async {
    calls += 1;
    return coverage;
  }
}

void main() {
  testWidgets('renders countries summary and operators; empty ops omit line', (
    tester,
  ) async {
    final client = _FakeCoverageClient(
      DeviceCoverage(
        deviceExternalId: 'dev-1',
        coverageType: 'regional',
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

    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('2 countries'), findsOneWidget);
    expect(find.text('Croatia'), findsOneWidget);
    expect(find.text('A1 · Telemach'), findsOneWidget);
    expect(find.text('SI'), findsOneWidget);
    expect(find.text(' · '), findsNothing);
    expect(client.calls, 1);
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
    await tester.scrollUntilVisible(find.text('Country 119'), 500);
    expect(find.text('Country 119'), findsOneWidget);
  });
}
