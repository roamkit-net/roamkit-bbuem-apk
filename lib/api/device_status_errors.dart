import 'dart:io';

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
  const DeviceStatusNetworkException([String detail = ''])
      : super(
          detail.isEmpty
              ? 'Network error while fetching device status.'
              : 'Network error while fetching device status ($detail).',
        );
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

/// Map low-level network failures to a short, credential-safe detail.
String networkFailureDetail(Object error, {String? apiHost}) {
  final hostHint = (apiHost == null || apiHost.isEmpty) ? '' : ' host=$apiHost';

  if (error is HandshakeException) {
    return 'TLS handshake failed — Work profile proxy/cert?$hostHint';
  }
  if (error is TlsException) {
    return 'TLS error — Work profile proxy/cert?$hostHint';
  }
  if (error is SocketException) {
    final message = error.message.toLowerCase();
    final os = error.osError?.message.toLowerCase() ?? '';
    if (message.contains('failed host lookup') ||
        os.contains('no address associated') ||
        os.contains('name or service not known')) {
      return 'DNS lookup failed$hostHint';
    }
    if (message.contains('connection refused') || os.contains('connection refused')) {
      return 'connection refused$hostHint';
    }
    if (message.contains('timed out') ||
        message.contains('timeout') ||
        os.contains('timed out')) {
      return 'connection timed out$hostHint';
    }
    if (message.contains('network is unreachable') ||
        os.contains('network is unreachable')) {
      return 'network unreachable from Work space$hostHint';
    }
    final short = (error.osError?.message ?? error.message).trim();
    if (short.isEmpty) {
      return 'socket error$hostHint';
    }
    final clipped = short.length > 80 ? '${short.substring(0, 80)}…' : short;
    return '$clipped$hostHint';
  }

  final raw = error.toString().trim();
  final cleaned = raw
      .replaceFirst(RegExp(r'^ClientException:\s*'), '')
      .replaceFirst(RegExp(r'^Bad file descriptor.*'), 'bad file descriptor');
  if (cleaned.isEmpty) {
    return '${error.runtimeType}$hostHint';
  }
  final clipped = cleaned.length > 80 ? '${cleaned.substring(0, 80)}…' : cleaned;
  return '$clipped$hostHint';
}
