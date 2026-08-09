import 'dart:async';

import 'package:flutter/material.dart';

import '../iccid_spike/iccid_spike_reader.dart';
import '../iccid_spike/iccid_spike_snapshot.dart';

/// Debug-only ADR 021 proof: default data subscription → ICCID attempt.
///
/// No RoamKit API calls. Does not change the PR18 status contract.
class IccidSpikePage extends StatefulWidget {
  const IccidSpikePage({super.key, required this.reader});

  final IccidSpikeReader reader;

  @override
  State<IccidSpikePage> createState() => _IccidSpikePageState();
}

class _IccidSpikePageState extends State<IccidSpikePage> {
  IccidSpikeSnapshot? _snapshot;
  String? _errorMessage;
  bool _loading = true;

  static const expectedUemIccid = '8900424101001825931';

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await widget.reader.requestReadPhoneState();
      final snapshot = await widget.reader.read();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = null;
        _errorMessage = 'Unexpected error while reading ICCID spike snapshot.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICCID spike'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('ADR 021 proof', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Reads active/default data subscription ICCID only. '
            'No API calls. Pixel 6a DoD: ICCID == $expectedUemIccid',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) ...[
            const Text('Loading…'),
            const SizedBox(height: 12),
          ],
          if (_errorMessage != null) ...[
            _Banner(text: _errorMessage!, isError: true),
            const SizedBox(height: 20),
          ],
          if (snapshot != null) ...[
            if (snapshot.hasIccid)
              _Banner(
                text: snapshot.iccid == expectedUemIccid
                    ? 'DoD match: APK ICCID == UEM report ($expectedUemIccid)'
                    : 'ICCID readable but does not match expected UEM value '
                        '($expectedUemIccid)',
                isError: snapshot.iccid != expectedUemIccid,
              )
            else
              _Banner(
                text:
                    'ICCID not readable. Reason: ${snapshot.failureReason ?? 'unknown'}',
                isError: true,
              ),
            const SizedBox(height: 20),
            _InfoTile(label: 'Android version', value: snapshot.androidVersion),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Android SDK',
              value: '${snapshot.androidSdkInt}',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Default data subscriptionId',
              value: snapshot.defaultDataSubscriptionId?.toString() ?? 'none',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'READ_PHONE_STATE',
              value: snapshot.readPhoneStateGranted ? 'granted' : 'denied',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Managed profile',
              value: snapshot.isManagedProfile ? 'yes' : 'no',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Profile owner app',
              value: snapshot.isProfileOwnerApp ? 'yes' : 'no',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Device owner app',
              value: snapshot.isDeviceOwnerApp ? 'yes' : 'no',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'ICCID',
              value: snapshot.hasIccid ? snapshot.iccid! : 'unavailable',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Failure reason',
              value: snapshot.failureReason ?? 'none',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final fg = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
      ),
    );
  }
}
