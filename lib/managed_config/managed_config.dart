import 'managed_config_keys.dart';

/// Snapshot of UEM-delivered managed configuration.
///
/// Status auth preference (ADR 021 Option C″):
/// 1. [deviceSerial] when present → POST `{device_serial}`
/// 2. else PR18 [deviceExternalId] + [deviceCredential]
///
/// Do not persist [deviceCredential]; never log it.
class ManagedConfig {
  const ManagedConfig({
    this.deviceSerial,
    required this.deviceExternalId,
    required this.deviceCredential,
  });

  final String? deviceSerial;
  final String? deviceExternalId;
  final String? deviceCredential;

  bool get hasDeviceSerial =>
      deviceSerial != null && deviceSerial!.trim().isNotEmpty;

  bool get hasDeviceExternalId =>
      deviceExternalId != null && deviceExternalId!.trim().isNotEmpty;

  bool get hasDeviceCredential =>
      deviceCredential != null && deviceCredential!.trim().isNotEmpty;

  /// PR18 credential pair (coverage and status fallback).
  bool get hasPr18Auth => hasDeviceExternalId && hasDeviceCredential;

  /// Enough for status: serial preferred path, or PR18 fallback.
  bool get isComplete => hasDeviceSerial || hasPr18Auth;

  /// Prefer serial when present, even if PR18 keys are also set.
  bool get prefersSerialAuth => hasDeviceSerial;

  factory ManagedConfig.fromChannelMap(Map<Object?, Object?> map) {
    return ManagedConfig(
      deviceSerial: _asNullableString(map[ManagedConfigKeys.deviceSerial]),
      deviceExternalId: _asNullableString(map[ManagedConfigKeys.deviceExternalId]),
      deviceCredential: _asNullableString(map[ManagedConfigKeys.deviceCredential]),
    );
  }

  static String? _asNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
