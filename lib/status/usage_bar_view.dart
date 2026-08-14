/// Aggregate usage bar from device-status remaining + used (never package rows).
///
/// Pure Dart — no Flutter imports.
enum UsageBarKind { metered, unlimited, unavailable }

enum UsageBarColor { green, orange, red, grey }

class UsageBarView {
  const UsageBarView._({
    required this.kind,
    this.remainingMb,
    this.usedMb,
    this.totalMb,
    this.remainingPercent,
    required this.color,
  });

  const UsageBarView.unlimited()
      : this._(kind: UsageBarKind.unlimited, color: UsageBarColor.grey);

  const UsageBarView.unavailable()
      : this._(kind: UsageBarKind.unavailable, color: UsageBarColor.grey);

  const UsageBarView.metered({
    required double remainingMb,
    required double usedMb,
    required double totalMb,
    required int remainingPercent,
    required UsageBarColor color,
  }) : this._(
          kind: UsageBarKind.metered,
          remainingMb: remainingMb,
          usedMb: usedMb,
          totalMb: totalMb,
          remainingPercent: remainingPercent,
          color: color,
        );

  final UsageBarKind kind;
  final double? remainingMb;
  final double? usedMb;
  final double? totalMb;
  final int? remainingPercent;
  final UsageBarColor color;

  bool get isLowRemaining =>
      kind == UsageBarKind.metered &&
      remainingPercent != null &&
      remainingPercent! < 10;
}

final _quantityUnit = RegExp(
  r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*(MB|GB)\s*$',
  caseSensitive: false,
);

/// Build the hero usage bar from status `data_remaining` + `data_used`.
UsageBarView buildUsageBarView({
  required String? dataRemaining,
  required String? dataUsed,
}) {
  if (_isUnlimited(dataRemaining)) {
    return const UsageBarView.unlimited();
  }

  final remainingMb = parseQuantityToMb(dataRemaining);
  final usedMb = parseQuantityToMb(dataUsed);
  if (remainingMb == null || usedMb == null) {
    return const UsageBarView.unavailable();
  }

  final totalMb = remainingMb + usedMb;
  if (totalMb <= 0) {
    return const UsageBarView.unavailable();
  }

  final remainingPercent = ((remainingMb / totalMb) * 100).round();
  return UsageBarView.metered(
    remainingMb: remainingMb,
    usedMb: usedMb,
    totalMb: totalMb,
    remainingPercent: remainingPercent,
    color: usageBarColorForPercent(remainingPercent),
  );
}

/// Green `>30%`, orange `10–30%`, red `<10%`.
UsageBarColor usageBarColorForPercent(int remainingPercent) {
  if (remainingPercent > 30) {
    return UsageBarColor.green;
  }
  if (remainingPercent >= 10) {
    return UsageBarColor.orange;
  }
  return UsageBarColor.red;
}

/// Parse a status quantity string to MB. Null for empty / unlimited / malformed.
double? parseQuantityToMb(String? raw) {
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.toLowerCase() == 'unlimited') {
    return null;
  }
  final match = _quantityUnit.firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount < 0) {
    return null;
  }
  final unit = match.group(2)!.toUpperCase();
  if (unit == 'GB') {
    return amount * 1024;
  }
  return amount;
}

bool _isUnlimited(String? raw) {
  return raw != null && raw.trim().toLowerCase() == 'unlimited';
}

/// Format MB for display (`1926` → `1.88 GB`, `122` → `122 MB`).
String formatDataMb(double mb) {
  if (!mb.isFinite) {
    return '—';
  }
  final abs = mb.abs();
  if (abs >= 1024) {
    final gb = mb / 1024;
    return '${_formatAmount(gb)} GB';
  }
  return '${mb.round()} MB';
}

String usageRemainingCaption(UsageBarView bar) {
  if (bar.kind == UsageBarKind.unlimited) {
    return 'Unlimited';
  }
  if (bar.kind != UsageBarKind.metered ||
      bar.remainingMb == null ||
      bar.totalMb == null) {
    return 'Usage not synced';
  }
  return '${formatDataMb(bar.remainingMb!)} of ${formatDataMb(bar.totalMb!)} remaining';
}

String usageUsedCaption(UsageBarView bar) {
  if (bar.kind != UsageBarKind.metered || bar.usedMb == null) {
    return '';
  }
  return '${formatDataMb(bar.usedMb!)} used';
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.round().toString();
  }
  final fixed = amount.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
