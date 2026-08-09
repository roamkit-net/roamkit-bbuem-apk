import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'device_status.dart';
import 'device_status_errors.dart';

/// Fetches read-only status (ADR 021 Option C″).
///
/// Prefer [deviceSerial] → `{device_serial}`. Otherwise PR18
/// [deviceExternalId] + [credential]. Never mix shapes. Never persist secrets.
abstract class DeviceStatusClient {
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  });
}

class HttpDeviceStatusClient implements DeviceStatusClient {
  HttpDeviceStatusClient({
    http.Client? httpClient,
    String? apiBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _apiBaseUrl = (apiBaseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _http;
  final String _apiBaseUrl;

  Uri get _statusUri => Uri.parse('$_apiBaseUrl/api/v1/device/status/');

  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    final body = _encodeBody(
      deviceSerial: deviceSerial,
      deviceExternalId: deviceExternalId,
      credential: credential,
    );

    late final http.Response response;
    try {
      response = await _http
          .post(
            _statusUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _statusUri.host),
      );
    } on HandshakeException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _statusUri.host),
      );
    } on TlsException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _statusUri.host),
      );
    } on http.ClientException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _statusUri.host),
      );
    } on TimeoutException {
      throw DeviceStatusNetworkException(
        networkFailureDetail(
          const SocketException('timed out'),
          apiHost: _statusUri.host,
        ),
      );
    }

    switch (response.statusCode) {
      case 200:
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const DeviceStatusUnexpectedException(
            'Invalid status response from server.',
          );
        }
        return DeviceStatus.fromJson(Map<String, dynamic>.from(decoded));
      case 404:
        // Distinguish ICCID miss from auth/binding 404 via API ``code`` only.
        // Never surface raw response detail (may be unsafe / noisy).
        if (statusErrorCodeFromBody(response.body) == 'iccid_not_found') {
          throw const DeviceStatusIccidNotFoundException();
        }
        throw const DeviceStatusNotFoundException();
      case 503:
        if (statusErrorCodeFromBody(response.body) ==
            'uem_inventory_unavailable') {
          throw const DeviceStatusUemInventoryUnavailableException();
        }
        throw const DeviceStatusUnexpectedException(
          'Status request failed (HTTP 503).',
        );
      case 429:
        throw const DeviceStatusRateLimitedException();
      default:
        // Do not echo response body — it must never surface credentials.
        throw DeviceStatusUnexpectedException(
          'Status request failed (HTTP ${response.statusCode}).',
        );
    }
  }

  static String _encodeBody({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) {
    final serial = deviceSerial?.trim();
    if (serial != null && serial.isNotEmpty) {
      return jsonEncode({'device_serial': serial});
    }
    final externalId = deviceExternalId?.trim() ?? '';
    final secret = credential ?? '';
    if (externalId.isEmpty || secret.isEmpty) {
      throw const DeviceStatusUnexpectedException(
        'Status request missing device_serial or PR18 credentials.',
      );
    }
    return jsonEncode({
      'device_external_id': externalId,
      'credential': secret,
    });
  }
}
