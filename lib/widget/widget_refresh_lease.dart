import 'dart:convert';
import 'dart:math';

/// Persistent cross-isolate lease so the UI isolate and a WorkManager
/// headless isolate cannot run two status/packages refreshes at once.
class WidgetRefreshLease {
  const WidgetRefreshLease({
    required this.owner,
    required this.generation,
    required this.expiresAt,
  });

  final String owner;
  final int generation;
  final DateTime expiresAt;

  static const storageKey = 'widget_refresh_lease';
  static const defaultTtl = Duration(minutes: 2);

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  Map<String, Object?> toJson() => {
        'owner': owner,
        'generation': generation,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory WidgetRefreshLease.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('lease is not a map');
    }
    final map = Map<String, dynamic>.from(decoded);
    return WidgetRefreshLease(
      owner: map['owner'] as String? ?? '',
      generation: (map['generation'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(map['expires_at'] as String).toUtc(),
    );
  }
}

class WidgetLeaseStore {
  const WidgetLeaseStore({
    required this.readRaw,
    required this.writeRaw,
  });

  final Future<String?> Function() readRaw;
  final Future<void> Function(String raw) writeRaw;

  /// Try to become the owner. Returns the new lease, or null if another
  /// unexpired owner holds it.
  Future<WidgetRefreshLease?> tryAcquire({
    required String owner,
    required DateTime now,
    Duration ttl = WidgetRefreshLease.defaultTtl,
  }) async {
    final existing = await _read();
    if (existing != null && !existing.isExpired(now)) {
      return null;
    }
    final generation = (existing?.generation ?? 0) + 1;
    final lease = WidgetRefreshLease(
      owner: owner,
      generation: generation,
      expiresAt: now.toUtc().add(ttl),
    );
    await writeRaw(lease.toJsonString());
    return lease;
  }

  /// Write is allowed only if we still own [expected] (same owner + generation).
  Future<bool> stillOwns(WidgetRefreshLease expected, DateTime now) async {
    final current = await _read();
    if (current == null) {
      return false;
    }
    if (current.isExpired(now)) {
      return false;
    }
    return current.owner == expected.owner &&
        current.generation == expected.generation;
  }

  Future<void> release(WidgetRefreshLease expected) async {
    final current = await _read();
    if (current == null) {
      return;
    }
    if (current.owner != expected.owner ||
        current.generation != expected.generation) {
      return;
    }
    await writeRaw(
      WidgetRefreshLease(
        owner: '',
        generation: expected.generation,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ).toJsonString(),
    );
  }

  Future<WidgetRefreshLease?> _read() async {
    final raw = await readRaw();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return WidgetRefreshLease.fromJsonString(raw);
    } on FormatException {
      return null;
    }
  }
}

String newLeaseOwner() {
  final rand = Random();
  return 'lease-${DateTime.now().toUtc().microsecondsSinceEpoch}-${rand.nextInt(1 << 32)}';
}
