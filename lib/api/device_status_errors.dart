/// Failures from the device status flow.
///
/// Messages must never include the device credential.
sealed class DeviceStatusException implements Exception {
  const DeviceStatusException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MissingManagedConfigException extends DeviceStatusException {
  const MissingManagedConfigException()
      : super(
          'Managed configuration incomplete. '
          'Waiting for roamkit.device_external_id and roamkit.device_credential.',
        );
}

class DeviceStatusNotFoundException extends DeviceStatusException {
  const DeviceStatusNotFoundException()
      : super('Device binding not found or credential invalid.');
}

class DeviceStatusRateLimitedException extends DeviceStatusException {
  const DeviceStatusRateLimitedException()
      : super('Too many status requests. Try again later.');
}

class DeviceStatusNetworkException extends DeviceStatusException {
  const DeviceStatusNetworkException()
      : super('Network error while fetching device status.');
}

class DeviceStatusUnexpectedException extends DeviceStatusException {
  const DeviceStatusUnexpectedException(super.message);
}

/// Strip a credential from any accidental error text before UI/logging.
String redactCredential(String text, String? credential) {
  if (credential == null || credential.isEmpty) {
    return text;
  }
  return text.replaceAll(credential, '[redacted]');
}
