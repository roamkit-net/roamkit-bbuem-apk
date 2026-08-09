import 'dart:async';

import 'package:flutter/material.dart';

import '../api/device_status.dart';
import '../api/device_status_client.dart';
import '../api/device_status_errors.dart';
import '../config/app_config.dart';
import '../managed_config/managed_config.dart';
import '../managed_config/managed_config_reader.dart';
import '../status/menu_formatters.dart';
import '../status/operational_status_view.dart';
import '../status/plan_badge.dart';
import '../widget/widget_snapshot.dart';
import '../widget/widget_snapshot_store.dart';

/// Reads UEM managed config and shows operational eSIM status.
///
/// Credential is used only in-memory for the status POST and is never shown,
/// stored, or included in error text. ICCID is never shown on user surfaces.
class DeviceStatusPage extends StatefulWidget {
  const DeviceStatusPage({
    super.key,
    required this.reader,
    required this.statusClient,
    this.now,
    this.snapshotStore,
  });

  final ManagedConfigReader reader;
  final DeviceStatusClient statusClient;

  /// Clock injection for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// Home-widget publisher; defaults to [HomeWidgetSnapshotStore].
  final WidgetSnapshotStore? snapshotStore;

  @override
  State<DeviceStatusPage> createState() => _DeviceStatusPageState();
}

class _DeviceStatusPageState extends State<DeviceStatusPage> {
  ManagedConfig? _config;
  DeviceStatus? _status;
  OperationalStatusView _view = OperationalStatusView.loading();
  bool _loading = true;
  Future<void>? _inFlight;
  int _reloadGeneration = 0;
  int _widgetRevision = 0;
  StreamSubscription<ManagedConfig>? _subscription;
  late final WidgetSnapshotStore _snapshotStore =
      widget.snapshotStore ?? const HomeWidgetSnapshotStore();

  DateTime _now() => widget.now?.call() ?? DateTime.now();

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

  Future<void> _reload() {
    // Single-flight: concurrent callers await the same request; clear when done.
    return _inFlight ??= _reloadBody().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _reloadBody() async {
    final generation = ++_reloadGeneration;
    final hadSuccess = _view.isSuccessSnapshot;

    setState(() {
      _loading = true;
      if (!hadSuccess) {
        _view = OperationalStatusView.loading();
      }
    });

    String? credentialForRedaction;
    ManagedConfig? config;
    try {
      config = await widget.reader.read();
      credentialForRedaction = config.deviceCredential;

      if (!mounted || generation != _reloadGeneration) {
        return;
      }

      if (!config.isComplete) {
        setState(() {
          _config = config;
          _status = null;
          _view = OperationalStatusView.fromException(
            const MissingManagedConfigException(),
          );
          _loading = false;
        });
        unawaited(_publishWidgetSnapshot());
        return;
      }

      final status = await widget.statusClient.fetchStatus(
        deviceExternalId: config.deviceExternalId!,
        credential: config.deviceCredential!,
      );

      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _config = config;
        _status = status;
        _view = evaluateOperationalView(status, now: _now());
        _loading = false;
      });
      unawaited(_publishWidgetSnapshot());
    } on DeviceStatusException catch (error) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        if (config != null) {
          _config = config;
        }
        _status = null;
        _view = OperationalStatusView.fromException(error);
        _loading = false;
      });
      unawaited(_publishWidgetSnapshot());
    } catch (error) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        if (config != null) {
          _config = config;
        }
        _status = null;
        _view = OperationalStatusView.fromException(
          const DeviceStatusUnexpectedException(
            'Could not load status',
          ),
        );
        _loading = false;
      });
      unawaited(_publishWidgetSnapshot());
      assert(() {
        debugPrint(
          'device status unexpected error: '
          '${redactCredential('$error', credentialForRedaction)}',
        );
        return true;
      }());
    }
  }

  /// Publish final success/error only — never in-flight [StatusSurface.slateLoading].
  Future<void> _publishWidgetSnapshot() async {
    if (_view.surface == StatusSurface.slateLoading) {
      return;
    }
    final plan =
        _view.isSuccessSnapshot ? buildPlanBadgeView(_status?.plan) : null;
    final snapshot = WidgetSnapshot.fromViews(
      view: _view,
      plan: plan,
      revision: ++_widgetRevision,
      generatedAt: _now().toUtc(),
    );
    try {
      await _snapshotStore.publish(snapshot);
    } catch (error) {
      assert(() {
        debugPrint('widget snapshot publish failed: $error');
        return true;
      }());
    }
  }

  Color get _panelColor {
    return switch (_view.surface) {
      StatusSurface.green => const Color(OperationalStatusView.greenColorValue),
      StatusSurface.red => const Color(OperationalStatusView.redColorValue),
      StatusSurface.slateLoading ||
      StatusSurface.slateError =>
        const Color(OperationalStatusView.slateColorValue),
    };
  }

  void _openSupportMenu() {
    final config = _config;
    final status = _status;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Device binding'),
                subtitle: Text(MenuFormatters.binding(status?.bindingStatus)),
              ),
              ListTile(
                title: const Text('External ID'),
                subtitle: Text(MenuFormatters.externalId(config)),
              ),
              ListTile(
                title: const Text('Credential'),
                subtitle: Text(MenuFormatters.credential(config)),
              ),
              ListTile(
                title: const Text('Auto-topup'),
                subtitle: Text(
                  MenuFormatters.autoTopup(enabled: status?.autoTopup.enabled),
                ),
              ),
              ListTile(
                title: const Text('API'),
                subtitle: Text(MenuFormatters.apiEnvironment()),
              ),
              ListTile(
                title: const Text('About'),
                subtitle: Text('RoamKit Device · ${AppConfig.apiBaseUrl}'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final onPanel = Colors.white;

    return Scaffold(
      backgroundColor: _panelColor,
      appBar: AppBar(
        backgroundColor: _panelColor,
        foregroundColor: onPanel,
        elevation: 0,
        title: const Text('RoamKit'),
        actions: [
          IconButton(
            tooltip: 'Support menu',
            onPressed: _openSupportMenu,
            icon: const Icon(Icons.more_vert),
          ),
          IconButton(
            tooltip: 'Reload status',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: onPanel,
        backgroundColor: _panelColor,
        onRefresh: _reload,
        child: Stack(
          children: [
            Semantics(
              label: view.semanticsSummary ?? view.heroLabel,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                children: [
                  if (view.surface == StatusSurface.slateLoading) ...[
                    const SizedBox(height: 48),
                    Center(
                      child: Semantics(
                        label: 'Loading eSIM status',
                        child: CircularProgressIndicator(color: onPanel),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      view.heroLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: onPanel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Text(
                      view.heroLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: onPanel,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (view.errorDetail != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        view.errorDetail!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: onPanel.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    if (view.isSuccessSnapshot) ...[
                      Builder(
                        builder: (context) {
                          final badge = buildPlanBadgeView(_status?.plan);
                          if (badge == null) {
                            return const SizedBox(height: 48);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 28, bottom: 40),
                            child: _PlanBadge(badge: badge, color: onPanel),
                          );
                        },
                      ),
                    ] else
                      const SizedBox(height: 48),
                    _StatusMetric(
                      label: 'Data remaining',
                      value: view.dataRemainingDisplay ?? '—',
                      color: onPanel,
                    ),
                    const SizedBox(height: 28),
                    _StatusMetric(
                      label: 'Expires',
                      value: view.expiresDisplay,
                      color: onPanel,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      formatUpdatedCaption(view.checkedAt),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onPanel.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_loading && view.isSuccessSnapshot)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.badge, required this.color});

  final PlanBadgeView badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [
        badge.title,
        if (badge.subtitle != null) badge.subtitle!,
      ].join(', '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.topCenter,
              child: _PlanBadgeIcon(badge: badge, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (badge.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    badge.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadgeIcon extends StatelessWidget {
  const _PlanBadgeIcon({required this.badge, required this.color});

  final PlanBadgeView badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (badge.iconKind) {
      case PlanBadgeIconKind.flag:
        return Text(
          badge.flagEmoji ?? '🏳️',
          style: const TextStyle(fontSize: 28, height: 1.1),
        );
      case PlanBadgeIconKind.regional:
        return Icon(Icons.map_outlined, color: color, size: 28);
      case PlanBadgeIconKind.globe:
        return Icon(Icons.public, color: color, size: 28);
      case PlanBadgeIconKind.neutral:
        return Icon(Icons.sim_card_outlined, color: color, size: 28);
    }
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color.withValues(alpha: 0.8),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
