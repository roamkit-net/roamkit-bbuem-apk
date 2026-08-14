import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_status.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';
import 'package:roamkit_bbuem_apk/status/operational_status_view.dart';
import 'package:roamkit_bbuem_apk/status/plan_badge.dart';
import 'package:roamkit_bbuem_apk/widget/widget_snapshot.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 12);

  test('home_widget provider FQCNs use net.roamkit.bbuem', () {
    expect(
      WidgetSnapshot.compactProvider,
      'net.roamkit.bbuem.RoamKitCompactWidgetProvider',
    );
    expect(
      WidgetSnapshot.wideProvider,
      'net.roamkit.bbuem.RoamKitWideWidgetProvider',
    );
  });

  OperationalStatusView greenView() {
    return evaluateOperationalView(
      DeviceStatus(
        deviceExternalId: 'dev-1',
        bindingStatus: 'active',
        esim: const DeviceStatusEsim(id: 1, iccid: '8910', status: 'in_use'),
        usage: DeviceStatusUsage(
          dataRemaining: 'Unlimited',
          dataUsed: '0 MB',
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        autoTopup: const DeviceStatusAutoTopup(enabled: false),
        checkedAt: now,
      ),
      now: now,
    );
  }

  test('atomic JSON includes schema revision and plan fields', () {
    final plan = buildPlanBadgeView(
      const DeviceStatusPlan(
        title: 'Cronet (Croatia)',
        dataAllowance: 'Unlimited',
        validityDays: 3,
        countryCode: 'HR',
        coverageType: 'local',
      ),
    );
    final snap = WidgetSnapshot.fromViews(
      view: greenView(),
      plan: plan,
      revision: 7,
      generatedAt: now,
    );
    expect(snap.schema, 1);
    expect(snap.revision, 7);
    expect(snap.surface, 'green');
    expect(snap.hero, 'ACTIVE');
    expect(snap.remaining, 'Unlimited');
    expect(snap.expires, isNot(''));
    expect(snap.planTitle, 'Cronet (Croatia)');
    expect(snap.planSubtitle, '');
    expect(snap.planFlag, '🇭🇷');
    expect(snap.planIcon, 'flag');
    expect(snap.containsForbiddenKeys, isFalse);

    final encoded = snap.toJsonString();
    expect(encoded.contains('widget_snapshot'), isFalse);
    final roundTrip = WidgetSnapshot.fromJsonString(encoded);
    expect(roundTrip.hero, 'ACTIVE');
    expect(roundTrip.revision, 7);
    expect(roundTrip.schema, 1);
  });

  test('plan null clears plan fields', () {
    final snap = WidgetSnapshot.fromViews(
      view: greenView(),
      plan: null,
      revision: 1,
      generatedAt: now,
    );
    expect(snap.planTitle, '');
    expect(snap.planSubtitle, '');
    expect(snap.planIcon, '');
  });

  test('slate error snapshot never green', () {
    final view = OperationalStatusView.fromException(
      const MissingManagedConfigException(),
    );
    final snap = WidgetSnapshot.fromViews(
      view: view,
      plan: null,
      revision: 2,
      generatedAt: now,
    );
    expect(snap.surface, 'slateError');
    expect(snap.hero, 'UNAVAILABLE');
    expect(snap.surface, isNot('green'));
  });

  test('red expired snapshot', () {
    final view = evaluateOperationalView(
      DeviceStatus(
        deviceExternalId: 'dev-1',
        bindingStatus: 'active',
        esim: const DeviceStatusEsim(id: 1, iccid: '8910', status: 'in_use'),
        usage: DeviceStatusUsage(
          dataRemaining: '12 MB',
          dataUsed: '88 MB',
          expiresAt: DateTime.utc(2026, 8, 1),
        ),
        autoTopup: const DeviceStatusAutoTopup(enabled: false),
        checkedAt: now,
      ),
      now: now,
    );
    final snap = WidgetSnapshot.fromViews(
      view: view,
      plan: null,
      revision: 3,
      generatedAt: now,
    );
    expect(snap.surface, 'red');
    expect(snap.hero, 'EXPIRED');
  });

  test('shortExpiresLabel strips year', () {
    expect(shortExpiresLabel('12 Aug 2026'), '12 Aug');
    expect(shortExpiresLabel('—'), '—');
  });

  test('widget_snapshot_v1 contract unchanged (no coverage keys)', () {
    final plan = buildPlanBadgeView(
      const DeviceStatusPlan(
        title: 'Europe',
        dataAllowance: '5 GB',
        validityDays: 30,
        coverageType: 'regional',
        coverageSummary: DeviceStatusCoverageSummary(
          available: true,
          countryCount: 120,
        ),
      ),
    );
    final snap = WidgetSnapshot.fromViews(
      view: greenView(),
      plan: plan,
      revision: 1,
      generatedAt: now,
    );
    final keys = snap.toJson().keys.toSet();
    expect(
      keys,
      {
        'schema',
        'revision',
        'surface',
        'hero',
        'remaining',
        'expires',
        'plan_title',
        'plan_subtitle',
        'plan_flag',
        'plan_icon',
        'detail',
        'generated_at',
      },
    );
    expect(keys.contains('coverage'), isFalse);
    expect(keys.contains('coverage_summary'), isFalse);
    expect(keys.contains('operators'), isFalse);
    expect(snap.toJsonString().contains('coverage'), isFalse);
  });
}
