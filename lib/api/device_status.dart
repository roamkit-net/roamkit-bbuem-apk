/// Read-only device status snapshot from `POST /api/v1/device/status/`.
class DeviceStatus {
  const DeviceStatus({
    required this.deviceExternalId,
    required this.bindingStatus,
    required this.esim,
    required this.usage,
    required this.autoTopup,
    required this.checkedAt,
    this.plan,
  });

  final String deviceExternalId;
  final String bindingStatus;
  final DeviceStatusEsim esim;
  final DeviceStatusUsage usage;
  final DeviceStatusAutoTopup autoTopup;
  final DeviceStatusPlan? plan;
  final DateTime? checkedAt;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'];
    return DeviceStatus(
      deviceExternalId: json['device_external_id'] as String? ?? '',
      bindingStatus: json['binding_status'] as String? ?? '',
      esim: DeviceStatusEsim.fromJson(
        Map<String, dynamic>.from(json['esim'] as Map? ?? const {}),
      ),
      usage: DeviceStatusUsage.fromJson(
        Map<String, dynamic>.from(json['usage'] as Map? ?? const {}),
      ),
      autoTopup: DeviceStatusAutoTopup.fromJson(
        Map<String, dynamic>.from(json['auto_topup'] as Map? ?? const {}),
      ),
      plan: planRaw is Map
          ? DeviceStatusPlan.fromJson(Map<String, dynamic>.from(planRaw))
          : null,
      checkedAt: parseApiDateTime(json['checked_at']),
    );
  }
}

class DeviceStatusEsim {
  const DeviceStatusEsim({
    required this.id,
    required this.iccid,
    required this.status,
  });

  final int id;
  final String iccid;
  final String status;

  factory DeviceStatusEsim.fromJson(Map<String, dynamic> json) {
    return DeviceStatusEsim(
      id: (json['id'] as num?)?.toInt() ?? 0,
      iccid: json['iccid'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class DeviceStatusUsage {
  const DeviceStatusUsage({
    required this.dataRemaining,
    required this.dataUsed,
    required this.expiresAt,
    this.expiryMalformed = false,
  });

  final String? dataRemaining;
  final String? dataUsed;
  final DateTime? expiresAt;

  /// True when API sent a non-null expires_at that could not be parsed.
  final bool expiryMalformed;

  factory DeviceStatusUsage.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'];
    if (expiresRaw == null) {
      return DeviceStatusUsage(
        dataRemaining: json['data_remaining'] as String?,
        dataUsed: json['data_used'] as String?,
        expiresAt: null,
      );
    }
    final parsed = parseApiDateTime(expiresRaw);
    if (parsed == null) {
      return DeviceStatusUsage(
        dataRemaining: json['data_remaining'] as String?,
        dataUsed: json['data_used'] as String?,
        expiresAt: null,
        expiryMalformed: true,
      );
    }
    return DeviceStatusUsage(
      dataRemaining: json['data_remaining'] as String?,
      dataUsed: json['data_used'] as String?,
      expiresAt: parsed,
    );
  }
}

class DeviceStatusAutoTopup {
  const DeviceStatusAutoTopup({required this.enabled});

  final bool enabled;

  factory DeviceStatusAutoTopup.fromJson(Map<String, dynamic> json) {
    return DeviceStatusAutoTopup(enabled: json['enabled'] == true);
  }
}

/// Purchase-time plan metadata from Order snapshot (nullable on parent).
class DeviceStatusPlan {
  const DeviceStatusPlan({
    this.title,
    this.dataAllowance,
    this.validityDays,
    this.countryCode,
    this.coverageType,
    this.locationTitle,
  });

  final String? title;
  final String? dataAllowance;
  final int? validityDays;
  final String? countryCode;
  final String? coverageType;
  final String? locationTitle;

  factory DeviceStatusPlan.fromJson(Map<String, dynamic> json) {
    return DeviceStatusPlan(
      title: _asNullableString(json['title']),
      dataAllowance: _asNullableString(json['data_allowance']),
      validityDays: (json['validity_days'] as num?)?.toInt(),
      countryCode: _asNullableString(json['country_code']),
      coverageType: _asNullableString(json['coverage_type']),
      locationTitle: _asNullableString(json['location_title']),
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

/// Parse API datetime; returns null for null/invalid input (never throws).
DateTime? parseApiDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}
