import 'operational_status_view.dart';

/// Instant-based expiry copy for the home hero (not calendar-date compare).
class ExpiryCountdown {
  const ExpiryCountdown({
    required this.dateLine,
    required this.remainingLine,
    required this.isExpired,
    required this.isToday,
    required this.startsOnFirstUse,
  });

  /// `26 Aug 2026`, or `—` when there is no instant.
  final String dateLine;

  /// `12 days remaining` / `Expires today` / `Expired 2 days ago` /
  /// `Starts on first use`.
  final String remainingLine;

  final bool isExpired;
  final bool isToday;
  final bool startsOnFirstUse;

  bool get warn => isExpired || isToday;

  /// `Expires 26 Aug 2026 · 12 days remaining`
  String get combinedLine {
    if (startsOnFirstUse) {
      return remainingLine;
    }
    if (dateLine == '—') {
      return remainingLine == '—' ? '—' : remainingLine;
    }
    if (remainingLine == '—' || remainingLine.isEmpty) {
      return 'Expires $dateLine';
    }
    if (isExpired) {
      return 'Expired $dateLine · $remainingLine';
    }
    return 'Expires $dateLine · $remainingLine';
  }
}

/// Remaining / expired copy from the exact [expiresAt] instant.
///
/// Whole days use [Duration.inDays] (truncated). A delta of 23h is
/// `Expires today` even when the calendar date is tomorrow.
ExpiryCountdown buildExpiryCountdown({
  required DateTime? expiresAt,
  required DateTime now,
  required bool notYetInUse,
}) {
  if (expiresAt == null) {
    if (notYetInUse) {
      return const ExpiryCountdown(
        dateLine: '—',
        remainingLine: 'Starts on first use',
        isExpired: false,
        isToday: false,
        startsOnFirstUse: true,
      );
    }
    return const ExpiryCountdown(
      dateLine: '—',
      remainingLine: '—',
      isExpired: false,
      isToday: false,
      startsOnFirstUse: false,
    );
  }

  final dateLine = formatExpiresDisplay(expiresAt);
  final delta = expiresAt.difference(now);

  if (delta.isNegative || delta == Duration.zero) {
    final elapsed = now.difference(expiresAt);
    return ExpiryCountdown(
      dateLine: dateLine,
      remainingLine: _expiredLine(elapsed),
      isExpired: true,
      isToday: false,
      startsOnFirstUse: false,
    );
  }

  if (delta <= const Duration(hours: 24)) {
    return ExpiryCountdown(
      dateLine: dateLine,
      remainingLine: 'Expires today',
      isExpired: false,
      isToday: true,
      startsOnFirstUse: false,
    );
  }

  final days = delta.inDays;
  final remainingLine = days == 1 ? '1 day remaining' : '$days days remaining';
  return ExpiryCountdown(
    dateLine: dateLine,
    remainingLine: remainingLine,
    isExpired: false,
    isToday: false,
    startsOnFirstUse: false,
  );
}

/// eSIM has not started consuming a package (null `expires_at` is expected).
bool esimNotYetInUse(String? esimStatus) {
  final key = (esimStatus ?? '').trim().toLowerCase();
  return key != 'in_use' && key != 'expired' && key != 'exhausted';
}

String _expiredLine(Duration elapsed) {
  if (elapsed <= const Duration(hours: 24)) {
    return 'Expired today';
  }
  final days = elapsed.inDays;
  if (days <= 1) {
    return 'Expired 1 day ago';
  }
  return 'Expired $days days ago';
}
