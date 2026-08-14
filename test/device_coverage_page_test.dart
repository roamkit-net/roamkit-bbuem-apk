import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';
import 'package:roamkit_bbuem_apk/ui/device_coverage_page.dart';
import 'package:roamkit_bbuem_apk/ui/home_tokens.dart';

class _FakeCoverageClient implements DeviceCoverageClient {
  _FakeCoverageClient(this.coverage, {this.error});

  DeviceCoverage coverage;
  Object? error;
  int calls = 0;
  String? lastSerial;
  String? lastExternalId;
  String? lastCredential;
  Completer<DeviceCoverage>? delay;

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
    if (delay != null) {
      return delay!.future;
    }
    if (error != null) {
      throw error!;
    }
    return coverage;
  }
}

DeviceCoverageCountry _country(
  String code, {
  String? name,
  List<String> operators = const [],
}) {
  return DeviceCoverageCountry(
    countryCode: code,
    countryName: name,
    operators: operators,
  );
}

DeviceCoverage _sampleCoverage({String type = 'regional'}) {
  return DeviceCoverage(
    deviceExternalId: 'dev-1',
    coverageType: type,
    coverage: [
      _country('HR', name: 'Croatia', operators: ['A1', 'Telemach']),
      _country('SI'),
    ],
    checkedAt: DateTime.utc(2026, 8, 9),
  );
}

const _searchCodes = [
  'AT',
  'BE',
  'CI',
  'DE',
  'ES',
  'FR',
  'HR',
  'IT',
  'NL',
  'PL',
  'PT',
];

DeviceCoverage _manyCountries(int count) {
  return DeviceCoverage(
    deviceExternalId: 'dev-1',
    coverageType: 'regional',
    coverage: [
      for (var i = 0; i < count; i++)
        _country(
          _searchCodes[i],
          operators: i == 0 ? const ['A1'] : const [],
        ),
    ],
    checkedAt: DateTime.utc(2026, 8, 9),
  );
}

Future<void> _pumpCoverage(
  WidgetTester tester, {
  required DeviceCoverageClient client,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: DeviceCoveragePage(
          deviceExternalId: 'dev-1',
          credential: 'secret',
          coverageClient: client,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders countries summary and operators; empty ops omit line', (
    tester,
  ) async {
    final client = _FakeCoverageClient(_sampleCoverage());
    await _pumpCoverage(tester, client: client);

    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('2 countries'), findsOneWidget);
    expect(find.text('Croatia'), findsOneWidget);
    expect(find.text('A1 · Telemach'), findsOneWidget);
    expect(find.text('Slovenia'), findsOneWidget);
    expect(find.text('SI'), findsNothing);
    expect(find.text('Search country'), findsNothing);
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

  testWidgets('merges duplicate ISO rows into one card', (tester) async {
    final client = _FakeCoverageClient(
      DeviceCoverage(
        deviceExternalId: 'dev-1',
        coverageType: 'regional',
        coverage: [
          _country('HR', operators: ['A1']),
          _country('hr', operators: ['Telemach', 'A1']),
        ],
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    await _pumpCoverage(tester, client: client);
    expect(find.text('1 country'), findsOneWidget);
    expect(find.text('Croatia'), findsOneWidget);
    expect(find.text('A1 · Telemach'), findsOneWidget);
  });

  testWidgets('empty snapshot is No coverage available, not search miss', (
    tester,
  ) async {
    final client = _FakeCoverageClient(
      DeviceCoverage(
        deviceExternalId: 'dev-1',
        coverageType: 'regional',
        coverage: const [],
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    await _pumpCoverage(tester, client: client);
    expect(find.text('No coverage available'), findsOneWidget);
    expect(find.text('No countries found'), findsNothing);
    expect(find.text('Search country'), findsNothing);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('10 unique hides search', (tester) async {
    final ten = _FakeCoverageClient(_manyCountries(10));
    await _pumpCoverage(tester, client: ten);
    expect(find.text('10 countries'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('11 unique shows autocomplete', (tester) async {
    final eleven = _FakeCoverageClient(_manyCountries(11));
    await _pumpCoverage(tester, client: eleven);
    expect(find.text('11 countries'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cote');
    await tester.pump();
    expect(find.text("Côte d'Ivoire"), findsWidgets);
    expect(find.text('A1'), findsNothing);

    await tester.tap(find.text("Côte d'Ivoire").first);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        "Côte d'Ivoire");
    expect(find.text("Côte d'Ivoire"), findsWidgets);
  });

  testWidgets('search miss shows No countries found and Clear', (tester) async {
    final client = _FakeCoverageClient(_manyCountries(11));
    await _pumpCoverage(tester, client: client);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text('No countries found'), findsOneWidget);
    expect(find.text('No coverage available'), findsNothing);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('No countries found'), findsNothing);
    expect(find.text('11 countries'), findsOneWidget);
  });

  testWidgets('failed refresh keeps last-good and query', (tester) async {
    final client = _FakeCoverageClient(_manyCountries(11));
    await _pumpCoverage(tester, client: client);
    await tester.enterText(find.byType(TextField), 'croatia');
    await tester.pump();
    expect(find.text('Croatia'), findsWidgets);

    client.error = DeviceStatusNetworkException('down');
    await tester.tap(find.byTooltip('Reload coverage'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t refresh coverage'), findsOneWidget);
    expect(find.text('Croatia'), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'croatia',
    );
  });

  testWidgets('first-load fail is error pane', (tester) async {
    final client = _FakeCoverageClient(
      _sampleCoverage(),
      error: DeviceStatusNetworkException('down'),
    );
    await _pumpCoverage(tester, client: client);
    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.text('Croatia'), findsNothing);
    expect(find.text('No coverage available'), findsNothing);
  });

  testWidgets('late response after pop does not throw', (tester) async {
    final delay = Completer<DeviceCoverage>();
    final client = _FakeCoverageClient(_sampleCoverage())..delay = delay;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DeviceCoveragePage(
                      deviceExternalId: 'dev-1',
                      credential: 'secret',
                      coverageClient: client,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    Navigator.of(tester.element(find.byType(DeviceCoveragePage))).pop();
    await tester.pump();
    delay.complete(_sampleCoverage());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(DeviceCoveragePage), findsNothing);
  });

  testWidgets('font scale 200% does not overflow search and card', (
    tester,
  ) async {
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        fail(details.toString());
      }
      FlutterError.presentError(details);
    };
    final client = _FakeCoverageClient(_manyCountries(11));
    await _pumpCoverage(tester, client: client, textScale: 2);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Austria'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await _pumpCoverage(tester, client: client);
    expect(find.textContaining('countries'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('TalkBack label includes networks', (tester) async {
    final client = _FakeCoverageClient(_sampleCoverage());
    await _pumpCoverage(tester, client: client);
    expect(
      find.bySemanticsLabel('Croatia, networks A1 and Telemach'),
      findsOneWidget,
    );
  });

  testWidgets('dark scaffold on first load', (tester) async {
    final delay = Completer<DeviceCoverage>();
    final client = _FakeCoverageClient(_sampleCoverage())..delay = delay;
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCoveragePage(
          deviceExternalId: 'dev-1',
          credential: 'secret',
          coverageClient: client,
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, HomeTokens.background);
    delay.complete(_sampleCoverage());
    await tester.pumpAndSettle();
  });
}
