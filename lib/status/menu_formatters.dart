import '../config/app_config.dart';
import '../managed_config/managed_config.dart';

/// Read-only support-menu labels. Never used by status color evaluation.
abstract final class MenuFormatters {
  static String binding(String? bindingStatus) {
    if (bindingStatus == null || bindingStatus.trim().isEmpty) {
      return '—';
    }
    final raw = bindingStatus.trim();
    if (raw.toLowerCase() == 'active') {
      return 'Active';
    }
    if (raw.isEmpty) {
      return '—';
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  static String credential(ManagedConfig? config) {
    if (config == null) {
      return 'Missing';
    }
    return config.hasDeviceCredential ? 'Present' : 'Missing';
  }

  static String autoTopup({bool? enabled}) {
    if (enabled == null) {
      return '—';
    }
    return enabled ? 'Enabled' : 'Disabled';
  }

  static String apiEnvironment({String? apiBaseUrl}) {
    final base = (apiBaseUrl ?? AppConfig.apiBaseUrl).toLowerCase();
    if (base.contains('staging')) {
      return 'Staging';
    }
    if (base.contains('api.roamkit.net') && !base.contains('staging')) {
      return 'Production';
    }
    return 'Custom';
  }

  static String externalId(ManagedConfig? config) {
    if (config == null || !config.hasDeviceExternalId) {
      return '—';
    }
    return config.deviceExternalId!;
  }

  static String deviceSerial(ManagedConfig? config) {
    if (config == null || !config.hasDeviceSerial) {
      return '—';
    }
    return config.deviceSerial!;
  }
}
