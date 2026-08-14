import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/widget/widget_refresh_lease.dart';

void main() {
  test('second acquire fails while lease is live', () async {
    String? stored;
    final store = WidgetLeaseStore(
      readRaw: () async => stored,
      writeRaw: (raw) async => stored = raw,
    );
    final now = DateTime.utc(2026, 8, 14, 12);
    final first = await store.tryAcquire(owner: 'a', now: now);
    expect(first, isNotNull);
    final second = await store.tryAcquire(owner: 'b', now: now);
    expect(second, isNull);
    expect(await store.stillOwns(first!, now), isTrue);
  });

  test('expired lease can be taken by another owner', () async {
    String? stored;
    final store = WidgetLeaseStore(
      readRaw: () async => stored,
      writeRaw: (raw) async => stored = raw,
    );
    final now = DateTime.utc(2026, 8, 14, 12);
    final first = await store.tryAcquire(
      owner: 'a',
      now: now,
      ttl: const Duration(minutes: 2),
    );
    final later = now.add(const Duration(minutes: 3));
    expect(await store.stillOwns(first!, later), isFalse);
    final second = await store.tryAcquire(owner: 'b', now: later);
    expect(second, isNotNull);
    expect(second!.generation, first.generation + 1);
    expect(await store.stillOwns(first, later), isFalse);
  });

  test('release allows the next acquire', () async {
    String? stored;
    final store = WidgetLeaseStore(
      readRaw: () async => stored,
      writeRaw: (raw) async => stored = raw,
    );
    final now = DateTime.utc(2026, 8, 14, 12);
    final first = await store.tryAcquire(owner: 'a', now: now);
    await store.release(first!);
    final second = await store.tryAcquire(owner: 'b', now: now);
    expect(second, isNotNull);
  });
}
