import 'dart:convert';
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
          'Waiting for roamkit.device_serial, or PR18 '
          'roamkit.device_external_id + roamkit.device_credential.',
        );
}

class DeviceStatusNotFoundException extends DeviceStatusException {
  const DeviceStatusNotFoundException()
      : super('Device binding not found or credential invalid.');
}

/// API returned 404 with ``code=iccid_not_found`` (UEM ICCID miss).
class DeviceStatusIccidNotFoundException extends DeviceStatusException {
  const DeviceStatusIccidNotFoundException()
      : super('No RoamKit.net data for this ICCID');
}

/// API returned 503 with ``code=uem_inventory_unavailable``.
class DeviceStatusUemInventoryUnavailableException extends DeviceStatusException {
  const DeviceStatusUemInventoryUnavailableException()
      : super('UEM SIM inventory is temporarily unavailable.');
}

class DeviceStatusRateLimitedException extends DeviceStatusException {
  const DeviceStatusRateLimitedException()
      : super('Too many status requests. Try again later.');
}

/// API returned 503 with ``code=provider_unavailable`` (package history).
class DevicePackagesProviderUnavailableException extends DeviceStatusException {
  const DevicePackagesProviderUnavailableException()
      : super('Package history is temporarily unavailable.');
}

/// Read a machine ``code`` from a JSON error body without surfacing detail text.
///
/// Returns null when the body is missing, invalid, or has no string ``code``.
String? statusErrorCodeFromBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return null;
    }
    final code = decoded['code'];
    if (code is String && code.isNotEmpty) {
      return code;
    }
    return null;
  } on FormatException {
    return null;
  } on Object {
    return null;
  }
}

class DeviceStatusNetworkException extends DeviceStatusException {
  DeviceStatusNetworkException([String detail = ''])
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
