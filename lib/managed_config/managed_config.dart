import 'managed_config_keys.dart';

/// Snapshot of UEM-delivered managed configuration.
///
/// PR1 scope: read-only display for channel validation. Do not persist
/// [deviceCredential]; do not call RoamKit APIs yet.
class ManagedConfig {
  const ManagedConfig({
    required this.deviceExternalId,
    required this.deviceCredential,
  });

  final String? deviceExternalId;
  final String? deviceCredential;

  bool get hasDeviceExternalId =>
      deviceExternalId != null && deviceExternalId!.trim().isNotEmpty;

  bool get hasDeviceCredential =>
      deviceCredential != null && deviceCredential!.trim().isNotEmpty;

  bool get isComplete => hasDeviceExternalId && hasDeviceCredential;

  factory ManagedConfig.fromChannelMap(Map<Object?, Object?> map) {
    return ManagedConfig(
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
