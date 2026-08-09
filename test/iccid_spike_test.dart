import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/iccid_spike/iccid_spike_reader.dart';
import 'package:roamkit_device/iccid_spike/iccid_spike_snapshot.dart';
import 'package:roamkit_device/ui/iccid_spike_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IccidSpikeSnapshot.fromChannelMap', () {
    test('parses successful ICCID read', () {
      final snapshot = IccidSpikeSnapshot.fromChannelMap({
        'androidVersion': '16',
        'androidSdkInt': 36,
        'defaultDataSubscriptionId': 2,
        'readPhoneStateGranted': true,
        'isManagedProfile': true,
        'isProfileOwnerApp': false,
        'isDeviceOwnerApp': false,
        'iccid': '8900424101001825931',
        'failureReason': null,
      });

      expect(snapshot.hasIccid, isTrue);
      expect(snapshot.iccid, '8900424101001825931');
      expect(snapshot.failureReason, isNull);
      expect(snapshot.defaultDataSubscriptionId, 2);
      expect(snapshot.isManagedProfile, isTrue);
    });

    test('maps known failure reasons', () {
      for (final reason in IccidSpikeSnapshot.knownFailureReasons) {
        final snapshot = IccidSpikeSnapshot.fromChannelMap({
          'androidVersion': '16',
          'androidSdkInt': 36,
          'defaultDataSubscriptionId': -1,
          'readPhoneStateGranted': false,
          'isManagedProfile': true,
          'isProfileOwnerApp': false,
          'isDeviceOwnerApp': false,
          'iccid': '',
          'failureReason': reason,
        });
        expect(snapshot.failureReason, reason);
        expect(snapshot.hasIccid, isFalse);
      }
    });

    test('treats invalid subscription id as null', () {
      final snapshot = IccidSpikeSnapshot.fromChannelMap({
        'androidVersion': '16',
        'androidSdkInt': 36,
        'defaultDataSubscriptionId': -1,
        'readPhoneStateGranted': true,
        'isManagedProfile': false,
        'isProfileOwnerApp': false,
        'isDeviceOwnerApp': false,
        'iccid': null,
        'failureReason': IccidSpikeSnapshot.noDefaultDataSubscription,
      });
      expect(snapshot.defaultDataSubscriptionId, isNull);
    });
  });

  group('ChannelIccidSpikeReader', () {
    const channel = MethodChannel('net.roamkit.device/iccid_spike');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('requestReadPhoneState and read use channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'requestReadPhoneState':
            return true;
          case 'getIccidSpikeSnapshot':
            return <String, Object?>{
              'androidVersion': '16',
              'androidSdkInt': 36,
              'defaultDataSubscriptionId': 1,
              'readPhoneStateGranted': true,
              'isManagedProfile': true,
              'isProfileOwnerApp': false,
              'isDeviceOwnerApp': false,
              'iccid': '8900424101001825931',
              'failureReason': null,
            };
          default:
            fail('unexpected method ${call.method}');
        }
      });

      final reader = ChannelIccidSpikeReader();
      expect(await reader.requestReadPhoneState(), isTrue);
      final snapshot = await reader.read();
      expect(snapshot.iccid, '8900424101001825931');
    });
  });

  testWidgets('ICCID spike page shows DoD match', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IccidSpikePage(
          reader: _FakeIccidReader(
            const IccidSpikeSnapshot(
              androidVersion: '16',
              androidSdkInt: 36,
              defaultDataSubscriptionId: 1,
              readPhoneStateGranted: true,
              isManagedProfile: true,
              isProfileOwnerApp: false,
              isDeviceOwnerApp: false,
              iccid: '8900424101001825931',
              failureReason: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ICCID spike'), findsOneWidget);
    expect(find.text('Android version'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(
      find.textContaining('DoD match: APK ICCID == UEM report'),
      findsOneWidget,
    );
  });

  testWidgets('ICCID spike page shows failure reason', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IccidSpikePage(
          reader: _FakeIccidReader(
            const IccidSpikeSnapshot(
              androidVersion: '16',
              androidSdkInt: 36,
              defaultDataSubscriptionId: null,
              readPhoneStateGranted: false,
              isManagedProfile: true,
              isProfileOwnerApp: false,
              isDeviceOwnerApp: false,
              iccid: null,
              failureReason: IccidSpikeSnapshot.permissionDenied,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('ICCID not readable. Reason: permission_denied'),
      findsOneWidget,
    );
    expect(find.text('READ_PHONE_STATE'), findsOneWidget);
    expect(find.text('denied'), findsOneWidget);
  });
}

class _FakeIccidReader implements IccidSpikeReader {
  _FakeIccidReader(this.snapshot);

  final IccidSpikeSnapshot snapshot;

  @override
  Future<bool> requestReadPhoneState() async => snapshot.readPhoneStateGranted;

  @override
  Future<IccidSpikeSnapshot> read() async => snapshot;
}
