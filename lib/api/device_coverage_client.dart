import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'device_coverage.dart';
import 'device_status_errors.dart';

/// Fetches purchase-time coverage via opaque device credential.
///
/// Same auth boundary as status. Never persists or logs the credential.
abstract class DeviceCoverageClient {
  Future<DeviceCoverage> fetchCoverage({
    required String deviceExternalId,
    required String credential,
  });
}

class HttpDeviceCoverageClient implements DeviceCoverageClient {
  HttpDeviceCoverageClient({
    http.Client? httpClient,
    String? apiBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _apiBaseUrl =
            (apiBaseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _http;
  final String _apiBaseUrl;

  Uri get _coverageUri => Uri.parse('$_apiBaseUrl/api/v1/device/coverage/');

  @override
  Future<DeviceCoverage> fetchCoverage({
    required String deviceExternalId,
    required String credential,
  }) async {
    late final http.Response response;
    try {
      response = await _http
          .post(
            _coverageUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'device_external_id': deviceExternalId,
              'credential': credential,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _coverageUri.host),
      );
    } on HandshakeException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _coverageUri.host),
      );
    } on TlsException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _coverageUri.host),
      );
    } on http.ClientException catch (error) {
      throw DeviceStatusNetworkException(
        networkFailureDetail(error, apiHost: _coverageUri.host),
      );
    } on TimeoutException {
      throw DeviceStatusNetworkException(
        networkFailureDetail(
          const SocketException('timed out'),
          apiHost: _coverageUri.host,
        ),
      );
    }

    switch (response.statusCode) {
      case 200:
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const DeviceStatusUnexpectedException(
            'Invalid coverage response from server.',
          );
        }
        return DeviceCoverage.fromJson(Map<String, dynamic>.from(decoded));
      case 404:
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
          'Coverage request failed (HTTP 503).',
        );
      case 429:
        throw const DeviceStatusRateLimitedException();
      default:
        throw DeviceStatusUnexpectedException(
          'Coverage request failed (HTTP ${response.statusCode}).',
        );
    }
  }
}
