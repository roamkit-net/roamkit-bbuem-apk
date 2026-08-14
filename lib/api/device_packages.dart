import 'device_status.dart';

/// Read-only applied package history from `POST /api/v1/device/packages/`.
class DevicePackages {
  const DevicePackages({
    required this.deviceExternalId,
    required this.iccid,
    required this.results,
    required this.checkedAt,
    this.activePackage,
  });

  /// Null on serial-auth success (server does not mint a binding).
  final String? deviceExternalId;
  final String iccid;
  final List<AppliedPackage> results;
  final AppliedPackage? activePackage;
  final DateTime? checkedAt;

  factory DevicePackages.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    final results = <AppliedPackage>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          results.add(AppliedPackage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final rawActive = json['active_package'];
    AppliedPackage? active;
    if (rawActive is Map) {
      active = AppliedPackage.fromJson(Map<String, dynamic>.from(rawActive));
    }
    return DevicePackages(
      deviceExternalId: _asNullableString(json['device_external_id']),
      iccid: json['iccid'] as String? ?? '',
      results: results,
      activePackage: active,
      checkedAt: parseApiDateTime(json['checked_at']),
    );
  }
}

/// One applied package instance (history, not the buy catalog).
class AppliedPackage {
  const AppliedPackage({
    required this.id,
    required this.kind,
    required this.status,
    required this.dataAllowance,
    required this.validityDays,
    required this.isUnlimited,
    required this.remainingMb,
    required this.createdAt,
    required this.activatedAt,
    required this.expiresAt,
    required this.paidUsd,
    required this.currency,
  });

  final String id;
  final String kind;
  final String status;
  final String dataAllowance;
  final int validityDays;
  final bool isUnlimited;
  final int? remainingMb;
  final DateTime? createdAt;
  final String? activatedAt;
  final String? expiresAt;
  final String? paidUsd;
  final String currency;

  factory AppliedPackage.fromJson(Map<String, dynamic> json) {
    return AppliedPackage(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? '',
      dataAllowance: json['data_allowance'] as String? ?? '',
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 0,
      isUnlimited: json['is_unlimited'] == true,
      remainingMb: (json['remaining_mb'] as num?)?.toInt(),
      createdAt: parseApiDateTime(json['created_at']),
      activatedAt: _asNullableString(json['activated_at']),
      expiresAt: _asNullableString(json['expires_at']),
      paidUsd: _asPaidUsd(json['paid_usd']),
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}

String? _asNullableString(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _asPaidUsd(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is num) {
    return raw.toString();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}
