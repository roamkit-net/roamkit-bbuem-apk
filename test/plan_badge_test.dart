import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/api/device_status.dart';
import 'package:roamkit_device/status/operational_status_view.dart';
import 'package:roamkit_device/status/plan_badge.dart';

void main() {
  group('formatPlanSubtitle', () {
    test('joins allowance and validity with middle dot', () {
      expect(
        formatPlanSubtitle(dataAllowance: 'Unlimited', validityDays: 3),
        'Unlimited · 3 days',
      );
    });

    test('uses singular day for 1', () {
      expect(
        formatPlanSubtitle(dataAllowance: '300 MB', validityDays: 1),
        '300 MB · 1 day',
      );
    });

    test('omits missing parts without stray separator', () {
      expect(formatPlanSubtitle(dataAllowance: '5 GB', validityDays: null), '5 GB');
      expect(formatPlanSubtitle(dataAllowance: null, validityDays: 30), '30 days');
      expect(formatPlanSubtitle(dataAllowance: '  ', validityDays: null), isNull);
      expect(formatPlanSubtitle(dataAllowance: null, validityDays: null), isNull);
    });
  });

  group('countryFlagEmoji', () {
    test('HR → Croatia flag', () {
      expect(countryFlagEmoji('HR'), '🇭🇷');
      expect(countryFlagEmoji('hr'), '🇭🇷');
    });

    test('invalid codes return null', () {
      expect(countryFlagEmoji(null), isNull);
      expect(countryFlagEmoji(''), isNull);
      expect(countryFlagEmoji('H'), isNull);
      expect(countryFlagEmoji('H1'), isNull);
    });
  });

  group('buildPlanBadgeView', () {
    test('null plan hides badge', () {
      expect(buildPlanBadgeView(null), isNull);
    });

    test('empty title hides badge', () {
      expect(
        buildPlanBadgeView(const DeviceStatusPlan(title: '  ', dataAllowance: '1 GB')),
        isNull,
      );
    });

    test('full local plan', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(
          title: 'Cronet (Croatia)',
          dataAllowance: 'Unlimited',
          validityDays: 3,
          countryCode: 'HR',
          coverageType: 'local',
        ),
      );
      expect(badge, isNotNull);
      expect(badge!.title, 'Cronet (Croatia)');
      expect(badge.subtitle, 'Unlimited · 3 days');
      expect(badge.iconKind, PlanBadgeIconKind.flag);
      expect(badge.flagEmoji, '🇭🇷');
    });

    test('global → globe', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(
          title: 'Discover',
          dataAllowance: '300 MB',
          validityDays: 3,
          coverageType: 'global',
        ),
      );
      expect(badge!.iconKind, PlanBadgeIconKind.globe);
    });

    test('regional → regional icon', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(
          title: 'Eurolink',
          dataAllowance: '5 GB',
          validityDays: 30,
          coverageType: 'regional',
        ),
      );
      expect(badge!.iconKind, PlanBadgeIconKind.regional);
    });

    test('unknown coverage with country → flag', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(
          title: 'Legacy Local',
          countryCode: 'US',
        ),
      );
      expect(badge!.iconKind, PlanBadgeIconKind.flag);
      expect(badge.flagEmoji, '🇺🇸');
    });

    test('unknown coverage without country → neutral', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(title: 'Unknown Pack'),
      );
      expect(badge!.iconKind, PlanBadgeIconKind.neutral);
    });

    test('partial plan has no stray separator', () {
      final badge = buildPlanBadgeView(
        const DeviceStatusPlan(title: 'Discover', dataAllowance: '300 MB'),
      );
      expect(badge!.subtitle, '300 MB');
      expect(badge.subtitle!.contains('·'), isFalse);
    });
  });

  group('plan does not affect color', () {
    test('same usage/status with different plans stay green', () {
      final now = DateTime.utc(2026, 8, 9, 12);
      DeviceStatus base({DeviceStatusPlan? plan}) {
        return DeviceStatus(
          deviceExternalId: 'dev-1',
          bindingStatus: 'active',
          esim: const DeviceStatusEsim(id: 1, iccid: '8910', status: 'in_use'),
          usage: DeviceStatusUsage(
            dataRemaining: '12 MB',
            dataUsed: '1 MB',
            expiresAt: DateTime.utc(2026, 9, 1),
          ),
          autoTopup: const DeviceStatusAutoTopup(enabled: true),
          plan: plan,
          checkedAt: now,
        );
      }

      final a = evaluateOperationalView(
        base(
          plan: const DeviceStatusPlan(
            title: 'Cronet (Croatia)',
            coverageType: 'local',
            countryCode: 'HR',
          ),
        ),
        now: now,
      );
      final b = evaluateOperationalView(
        base(
          plan: const DeviceStatusPlan(
            title: 'Discover',
            coverageType: 'global',
          ),
        ),
        now: now,
      );
      expect(a.surface, StatusSurface.green);
      expect(b.surface, StatusSurface.green);
      expect(a.heroLabel, b.heroLabel);
    });
  });
}
