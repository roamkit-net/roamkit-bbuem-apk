import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'device_packages.dart';
import 'device_status_errors.dart';

/// Fetches applied package history (ADR 021).
///
/// Prefer [deviceSerial] → `{device_serial}`. Otherwise PR18
/// [deviceExternalId] + [credential]. Never send `iccid` or `esim_id`.
abstract class DevicePackagesClient {
  Future<DevicePackages> fetchPackages({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  });
}

class HttpDevicePackagesClient implements DevicePackagesClient {
  HttpDevicePackagesClient({
    http.Client? httpClient,
    String? apiBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _apiBaseUrl =
            (apiBaseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _http;
  final String _apiBaseUrl;

  Uri get _packagesUri => Uri.parse('$_apiBaseUrl/api/v1/device/packages/');

  @override
  Future<DevicePackages> fetchPackages({
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
            _packagesUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _packagesUri.host),
      );
    } on HandshakeException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _packagesUri.host),
      );
    } on TlsException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _packagesUri.host),
      );
    } on http.ClientException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _packagesUri.host),
      );
    } on TimeoutException {
      throw DeviceStatusNetworkException(
        networkFailureDetail(
          const SocketException('timed out'),
          apiHost: _packagesUri.host,
        ),
      );
    }

    switch (response.statusCode) {
      case 200:
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const DeviceStatusUnexpectedException(
            'Invalid packages response from server.',
          );
        }
        return DevicePackages.fromJson(Map<String, dynamic>.from(decoded));
      case 404:
        if (statusErrorCodeFromBody(response.body) == 'iccid_not_found') {
          throw const DeviceStatusIccidNotFoundException();
        }
        throw const DeviceStatusNotFoundException();
      case 503:
        final code = statusErrorCodeFromBody(response.body);
        if (code == 'provider_unavailable') {
          throw const DevicePackagesProviderUnavailableException();
        }
        if (code == 'uem_inventory_unavailable') {
          throw const DeviceStatusUemInventoryUnavailableException();
        }
        throw const DeviceStatusUnexpectedException(
          'Packages request failed (HTTP 503).',
        );
      case 429:
        throw const DeviceStatusRateLimitedException();
      default:
        throw DeviceStatusUnexpectedException(
          'Packages request failed (HTTP ${response.statusCode}).',
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
        'Packages request missing device_serial or PR18 credentials.',
      );
    }
    return jsonEncode({
      'device_external_id': externalId,
      'credential': secret,
    });
  }
}
