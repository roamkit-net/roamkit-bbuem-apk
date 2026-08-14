import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/status/expiry_countdown.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 12);

  test('more than 24h and >1 whole day → N days remaining', () {
    final view = buildExpiryCountdown(
      expiresAt: DateTime.utc(2026, 8, 26, 12),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, '12 days remaining');
    expect(view.isToday, isFalse);
    expect(view.combinedLine, contains('12 days remaining'));
  });

  test('more than 24h and 1 whole day → 1 day remaining', () {
    final view = buildExpiryCountdown(
      expiresAt: DateTime.utc(2026, 8, 15, 13),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, '1 day remaining');
    expect(view.isToday, isFalse);
  });

  test('23h is Expires today even if calendar date is tomorrow', () {
    final view = buildExpiryCountdown(
      expiresAt: DateTime.utc(2026, 8, 15, 11),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, 'Expires today');
    expect(view.isToday, isTrue);
    expect(view.warn, isTrue);
  });

  test('24h + 1s → 1 day remaining', () {
    final view = buildExpiryCountdown(
      expiresAt: now.add(const Duration(hours: 24, seconds: 1)),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, '1 day remaining');
  });

  test('47h 59m → 1 day remaining', () {
    final view = buildExpiryCountdown(
      expiresAt: now.add(const Duration(hours: 47, minutes: 59)),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, '1 day remaining');
  });

  test('exactly 24h is Expires today', () {
    final view = buildExpiryCountdown(
      expiresAt: now.add(const Duration(hours: 24)),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, 'Expires today');
  });

  test('past instant → Expired N days ago', () {
    final view = buildExpiryCountdown(
      expiresAt: DateTime.utc(2026, 8, 12, 12),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, 'Expired 2 days ago');
    expect(view.isExpired, isTrue);
  });

  test('expired within 24h → Expired today', () {
    final view = buildExpiryCountdown(
      expiresAt: now.subtract(const Duration(hours: 3)),
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, 'Expired today');
  });

  test('null expires + not yet in use → Starts on first use', () {
    final view = buildExpiryCountdown(
      expiresAt: null,
      now: now,
      notYetInUse: true,
    );
    expect(view.remainingLine, 'Starts on first use');
    expect(view.startsOnFirstUse, isTrue);
    expect(view.combinedLine, 'Starts on first use');
  });

  test('null expires while in use → no fake countdown', () {
    final view = buildExpiryCountdown(
      expiresAt: null,
      now: now,
      notYetInUse: false,
    );
    expect(view.remainingLine, '—');
    expect(view.startsOnFirstUse, isFalse);
  });

  test('esimNotYetInUse treats activated as first-use eligible', () {
    expect(esimNotYetInUse('activated'), isTrue);
    expect(esimNotYetInUse('in_use'), isFalse);
    expect(esimNotYetInUse('expired'), isFalse);
  });
}
