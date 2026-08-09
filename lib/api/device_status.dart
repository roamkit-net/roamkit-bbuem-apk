/// Read-only device status snapshot from `POST /api/v1/device/status/`.
class DeviceStatus {
  const DeviceStatus({
    required this.deviceExternalId,
    required this.bindingStatus,
    required this.esim,
    required this.usage,
    required this.autoTopup,
    required this.checkedAt,
  });

  final String deviceExternalId;
  final String bindingStatus;
  final DeviceStatusEsim esim;
  final DeviceStatusUsage usage;
  final DeviceStatusAutoTopup autoTopup;
  final DateTime checkedAt;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceExternalId: json['device_external_id'] as String,
      bindingStatus: json['binding_status'] as String,
      esim: DeviceStatusEsim.fromJson(
        Map<String, dynamic>.from(json['esim'] as Map),
      ),
      usage: DeviceStatusUsage.fromJson(
        Map<String, dynamic>.from(json['usage'] as Map),
      ),
      autoTopup: DeviceStatusAutoTopup.fromJson(
        Map<String, dynamic>.from(json['auto_topup'] as Map),
      ),
      checkedAt: DateTime.parse(json['checked_at'] as String),
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
      id: json['id'] as int,
      iccid: json['iccid'] as String,
      status: json['status'] as String,
    );
  }
}

class DeviceStatusUsage {
  const DeviceStatusUsage({
    required this.dataRemaining,
    required this.dataUsed,
    required this.expiresAt,
  });

  final String? dataRemaining;
  final String? dataUsed;
  final DateTime? expiresAt;

  factory DeviceStatusUsage.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'];
    return DeviceStatusUsage(
      dataRemaining: json['data_remaining'] as String?,
      dataUsed: json['data_used'] as String?,
      expiresAt: expiresRaw == null ? null : DateTime.parse(expiresRaw as String),
    );
  }
}

class DeviceStatusAutoTopup {
  const DeviceStatusAutoTopup({required this.enabled});

  final bool enabled;

  factory DeviceStatusAutoTopup.fromJson(Map<String, dynamic> json) {
    return DeviceStatusAutoTopup(enabled: json['enabled'] as bool);
  }
}
