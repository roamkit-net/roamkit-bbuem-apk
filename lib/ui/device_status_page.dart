import 'dart:async';

import 'package:flutter/material.dart';

import '../api/device_status.dart';
import '../api/device_status_client.dart';
import '../api/device_status_errors.dart';
import '../iccid_spike/iccid_spike_reader.dart';
import '../managed_config/managed_config.dart';
import '../managed_config/managed_config_keys.dart';
import '../managed_config/managed_config_reader.dart';
import 'iccid_spike_page.dart';

/// Reads UEM managed config and shows read-only device status.
///
/// Credential is used only in-memory for the status POST and is never shown,
/// stored, or included in error text.
class DeviceStatusPage extends StatefulWidget {
  const DeviceStatusPage({
    super.key,
    required this.reader,
    required this.statusClient,
  });

  final ManagedConfigReader reader;
  final DeviceStatusClient statusClient;

  @override
  State<DeviceStatusPage> createState() => _DeviceStatusPageState();
}

class _DeviceStatusPageState extends State<DeviceStatusPage> {
  ManagedConfig? _config;
  DeviceStatus? _status;
  String? _errorMessage;
  bool _loading = true;
  StreamSubscription<ManagedConfig>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.reader.changes.listen((_) {
      unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    String? credentialForRedaction;
    ManagedConfig? config;
    try {
      config = await widget.reader.read();
      credentialForRedaction = config.deviceCredential;

      if (!mounted) {
        return;
      }

      if (!config.isComplete) {
        setState(() {
          _config = config;
          _status = null;
          _errorMessage = const MissingManagedConfigException().message;
          _loading = false;
        });
        return;
      }

      final status = await widget.statusClient.fetchStatus(
        deviceExternalId: config.deviceExternalId!,
        credential: config.deviceCredential!,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _status = status;
        _errorMessage = null;
        _loading = false;
      });
    } on DeviceStatusException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (config != null) {
          _config = config;
        }
        _status = null;
        _errorMessage = redactCredential(error.message, credentialForRedaction);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Never put exception details that might echo request data into the UI.
      setState(() {
        if (config != null) {
          _config = config;
        }
        _status = null;
        _errorMessage = 'Unexpected error while loading device status.';
        _loading = false;
      });
      assert(() {
        debugPrint(
          'device status unexpected error: '
          '${redactCredential('$error', credentialForRedaction)}',
        );
        return true;
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;
    final status = _status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoamKit Device'),
        actions: [
          IconButton(
            tooltip: 'ICCID spike (ADR 021)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IccidSpikePage(
                    reader: ChannelIccidSpikeReader(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.sim_card_outlined),
          ),
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
          Text('Device status', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Status from RoamKit API using UEM managed credentials. '
            'Credential is never stored or shown.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (config != null) ...[
            _InfoTile(
              label: ManagedConfigKeys.deviceExternalId,
              value: config.hasDeviceExternalId
                  ? config.deviceExternalId!
                  : 'missing',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Credential',
              value: config.hasDeviceCredential ? 'present' : 'missing',
            ),
            const SizedBox(height: 20),
          ],
          if (_errorMessage != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (status != null) ...[
            _InfoTile(label: 'eSIM status', value: status.esim.status),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Data remaining',
              value: status.usage.dataRemaining ?? '—',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Data used',
              value: status.usage.dataUsed ?? '—',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Expiry',
              value: status.usage.expiresAt?.toUtc().toIso8601String() ?? '—',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Auto-topup',
              value: status.autoTopup.enabled ? 'enabled' : 'disabled',
            ),
            const SizedBox(height: 12),
            _InfoTile(label: 'Binding', value: status.bindingStatus),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Checked at',
              value: status.checkedAt.toUtc().toIso8601String(),
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
            SelectableText(
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
