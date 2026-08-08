import 'dart:async';

import 'package:flutter/material.dart';

import '../managed_config/managed_config.dart';
import '../managed_config/managed_config_keys.dart';
import '../managed_config/managed_config_reader.dart';

/// Temporary UEM validation screen.
///
/// Shows managed config values including plaintext credential for BlackBerry
/// delivery proof only. Remove credential display before wiring
/// `POST /api/v1/device/status/`.
class ManagedConfigDebugPage extends StatefulWidget {
  const ManagedConfigDebugPage({
    super.key,
    required this.reader,
  });

  final ManagedConfigReader reader;

  @override
  State<ManagedConfigDebugPage> createState() => _ManagedConfigDebugPageState();
}

class _ManagedConfigDebugPageState extends State<ManagedConfigDebugPage> {
  ManagedConfig? _config;
  Object? _error;
  bool _loading = true;
  StreamSubscription<ManagedConfig>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.reader.changes.listen((config) {
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _error = null;
        _loading = false;
      });
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
      _error = null;
    });
    try {
      final config = await widget.reader.read();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoamKit Device'),
        actions: [
          IconButton(
            tooltip: 'Reload managed config',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'UEM managed configuration',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Reads Android app restrictions only. No API calls. '
            'Credential is shown temporarily for UEM delivery validation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'DEBUG: plaintext credential display is temporary. '
                'Remove before connecting to /api/v1/device/status/.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              'Failed to read managed config',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText('$_error'),
          ],
          if (config != null) ...[
            _ValueTile(
              label: ManagedConfigKeys.deviceExternalId,
              value: config.deviceExternalId,
              present: config.hasDeviceExternalId,
            ),
            const SizedBox(height: 12),
            _ValueTile(
              label: ManagedConfigKeys.deviceCredential,
              value: config.deviceCredential,
              present: config.hasDeviceCredential,
              emphasizeSecret: true,
            ),
            const SizedBox(height: 20),
            Text(
              config.isComplete
                  ? 'Both values present — UEM → APK channel looks good.'
                  : 'Waiting for UEM to deliver both managed values.',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    required this.value,
    required this.present,
    this.emphasizeSecret = false,
  });

  final String label;
  final String? value;
  final bool present;
  final bool emphasizeSecret;

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
              present ? value! : '(missing)',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'monospace',
                color: present
                    ? (emphasizeSecret
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
