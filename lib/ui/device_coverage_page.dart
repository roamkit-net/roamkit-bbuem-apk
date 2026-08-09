import 'package:flutter/material.dart';

import '../api/device_coverage.dart';
import '../api/device_coverage_client.dart';
import '../api/device_status_errors.dart';
import '../status/operational_status_view.dart';
import '../status/plan_badge.dart';

/// Secondary screen: purchase-time country / operator coverage.
///
/// Auth: prefer [deviceSerial]; else PR18 [deviceExternalId] + [credential].
/// Secrets are held only for the in-flight fetch and never shown.
class DeviceCoveragePage extends StatefulWidget {
  const DeviceCoveragePage({
    super.key,
    this.deviceSerial,
    this.deviceExternalId,
    this.credential,
    required this.coverageClient,
  });

  final String? deviceSerial;
  final String? deviceExternalId;
  final String? credential;
  final DeviceCoverageClient coverageClient;

  @override
  State<DeviceCoveragePage> createState() => _DeviceCoveragePageState();
}

class _DeviceCoveragePageState extends State<DeviceCoveragePage> {
  bool _loading = true;
  DeviceCoverage? _coverage;
  String? _errorDetail;

  static const _slate = Color(OperationalStatusView.slateColorValue);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorDetail = null;
    });
    try {
      final serial = widget.deviceSerial?.trim();
      final result = (serial != null && serial.isNotEmpty)
          ? await widget.coverageClient.fetchCoverage(deviceSerial: serial)
          : await widget.coverageClient.fetchCoverage(
              deviceExternalId: widget.deviceExternalId,
              credential: widget.credential,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _coverage = result;
        _loading = false;
      });
    } on DeviceStatusException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorDetail = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorDetail = 'Could not load coverage.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final countries = _coverage?.coverage;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Coverage'),
        actions: [
          IconButton(
            tooltip: 'Reload coverage',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorDetail != null
          ? _MessagePane(
              color: _slate,
              hero: 'UNAVAILABLE',
              detail: _errorDetail!,
              onRetry: _load,
            )
          : countries == null
          ? _MessagePane(
              color: _slate,
              hero: 'UNAVAILABLE',
              detail: 'Coverage details are not available for this plan.',
              onRetry: _load,
            )
          : countries.isEmpty
          ? _MessagePane(
              color: _slate,
              hero: 'NO DATA',
              detail: 'No coverage countries in this plan snapshot.',
              onRetry: _load,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: countries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final n = countries.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Text(
                      n == 1 ? '1 country' : '$n countries',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  );
                }
                final country = countries[index - 1];
                return _CountryCoverageTile(country: country);
              },
            ),
    );
  }
}

class _CountryCoverageTile extends StatelessWidget {
  const _CountryCoverageTile({required this.country});

  final DeviceCoverageCountry country;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlagEmoji(country.countryCode);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: flag != null
                    ? Text(flag, style: const TextStyle(fontSize: 22))
                    : const Icon(Icons.public, size: 22, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  country.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (country.operators.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                country.operators.join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.color,
    required this.hero,
    required this.detail,
    required this.onRetry,
  });

  final Color color;
  final String hero;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hero,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
