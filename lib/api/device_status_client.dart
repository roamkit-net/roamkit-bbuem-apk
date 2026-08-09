import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'device_status.dart';
import 'device_status_errors.dart';

/// Fetches read-only status via opaque device credential.
///
/// Never persists the credential. Never logs request bodies or credentials.
abstract class DeviceStatusClient {
  Future<DeviceStatus> fetchStatus({
    required String deviceExternalId,
    required String credential,
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
    required String deviceExternalId,
    required String credential,
  }) async {
    late final http.Response response;
    try {
      response = await _http.post(
        _statusUri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'device_external_id': deviceExternalId,
          'credential': credential,
        }),
      );
    } on SocketException {
      throw const DeviceStatusNetworkException();
    } on http.ClientException {
      throw const DeviceStatusNetworkException();
    } on HandshakeException {
      throw const DeviceStatusNetworkException();
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
        throw const DeviceStatusNotFoundException();
      case 429:
        throw const DeviceStatusRateLimitedException();
      default:
        // Do not echo response body — it must never surface credentials.
        throw DeviceStatusUnexpectedException(
          'Status request failed (HTTP ${response.statusCode}).',
        );
    }
  }
}
