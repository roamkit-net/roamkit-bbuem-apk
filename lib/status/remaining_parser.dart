/// Fail-closed data-remaining parser for operational status.
///
/// Pure Dart — no Flutter imports. Never throws.
enum RemainingUsability { usable, unusable }

/// Result of parsing a remaining string for display + usability.
class RemainingParseResult {
  const RemainingParseResult({
    required this.usability,
    required this.display,
  });

  final RemainingUsability usability;

  /// Normalized display value, or null when input was empty/null.
  final String? display;

  bool get isUsable => usability == RemainingUsability.usable;
}

final _quantityUnit = RegExp(
  r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*(MB|GB)\s*$',
  caseSensitive: false,
);

/// Parse API `data_remaining` for operational usability.
///
/// Rules (locked):
/// - null / empty / whitespace → unusable
/// - "unlimited" (trim, case-insensitive) → usable
/// - positive MB/GB → usable
/// - zero / negative / unknown unit / malformed → unusable
RemainingParseResult parseDataRemaining(String? raw) {
  if (raw == null) {
    return const RemainingParseResult(
      usability: RemainingUsability.unusable,
      display: null,
    );
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const RemainingParseResult(
      usability: RemainingUsability.unusable,
      display: null,
    );
  }

  if (trimmed.toLowerCase() == 'unlimited') {
    return const RemainingParseResult(
      usability: RemainingUsability.usable,
      display: 'Unlimited',
    );
  }

  final match = _quantityUnit.firstMatch(trimmed);
  if (match == null) {
    return RemainingParseResult(
      usability: RemainingUsability.unusable,
      display: trimmed,
    );
  }

  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0) {
    return RemainingParseResult(
      usability: RemainingUsability.unusable,
      display: trimmed,
    );
  }

  final unit = match.group(2)!.toUpperCase();
  return RemainingParseResult(
    usability: RemainingUsability.usable,
    display: '${_formatAmount(amount)} $unit',
  );
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.round().toString();
  }
  final fixed = amount.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
