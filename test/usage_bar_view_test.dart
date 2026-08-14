import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/status/usage_bar_view.dart';

void main() {
  group('buildUsageBarView', () {
    test('metered remaining + used from status only', () {
      final bar = buildUsageBarView(
        dataRemaining: '1.88 GB',
        dataUsed: '122 MB',
      );
      expect(bar.kind, UsageBarKind.metered);
      expect(bar.remainingMb, closeTo(1.88 * 1024, 0.01));
      expect(bar.usedMb, 122);
      expect(bar.totalMb, closeTo(1.88 * 1024 + 122, 0.01));
      expect(bar.color, UsageBarColor.green);
      expect(usageRemainingCaption(bar), '1.88 GB of 2 GB remaining');
      expect(usageUsedCaption(bar), '122 MB used');
    });

    test('does not sum package rows — missing used is unavailable', () {
      final bar = buildUsageBarView(
        dataRemaining: '1926 MB',
        dataUsed: null,
      );
      expect(bar.kind, UsageBarKind.unavailable);
      expect(usageRemainingCaption(bar), 'Usage not synced');
    });

    test('unlimited is grey with no MB math', () {
      final bar = buildUsageBarView(
        dataRemaining: 'Unlimited',
        dataUsed: '12 MB',
      );
      expect(bar.kind, UsageBarKind.unlimited);
      expect(bar.color, UsageBarColor.grey);
      expect(bar.remainingPercent, isNull);
      expect(usageRemainingCaption(bar), 'Unlimited');
    });

    test('bar colors: green >30, orange 10-30, red <10', () {
      expect(usageBarColorForPercent(31), UsageBarColor.green);
      expect(usageBarColorForPercent(30), UsageBarColor.orange);
      expect(usageBarColorForPercent(10), UsageBarColor.orange);
      expect(usageBarColorForPercent(9), UsageBarColor.red);
      expect(
        buildUsageBarView(dataRemaining: '5 MB', dataUsed: '95 MB').isLowRemaining,
        isTrue,
      );
    });
  });

  group('formatDataMb', () {
    test('formats GB and MB', () {
      expect(formatDataMb(1926), '1.88 GB');
      expect(formatDataMb(1024), '1 GB');
      expect(formatDataMb(122), '122 MB');
    });
  });
}
