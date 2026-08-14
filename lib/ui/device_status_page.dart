import 'dart:async';

import 'package:flutter/material.dart';

import '../api/device_coverage_client.dart';
import '../api/device_packages.dart';
import '../api/device_packages_client.dart';
import '../api/device_status.dart';
import '../api/device_status_client.dart';
import '../api/device_status_errors.dart';
import '../config/app_config.dart';
import '../managed_config/managed_config.dart';
import '../managed_config/managed_config_reader.dart';
import '../status/expiry_countdown.dart';
import '../status/menu_formatters.dart';
import '../status/operational_status_view.dart';
import '../status/plan_badge.dart';
import '../status/usage_bar_view.dart';
import '../widget/widget_snapshot.dart';
import '../widget/widget_snapshot_store.dart';
import 'device_coverage_page.dart';
import 'device_packages_section.dart';
import 'iccid_copy_row.dart';
import 'usage_bar_widget.dart';

/// Reads UEM managed config and shows operational eSIM status.
///
/// Credential is used only in-memory for POSTs and is never shown, stored,
/// or included in error text. ICCID is shown on the home hero (copy allowed)
/// and is never sent in a request body, logged, or published to widgets.
class DeviceStatusPage extends StatefulWidget {
  const DeviceStatusPage({
    super.key,
    required this.reader,
    required this.statusClient,
    this.coverageClient,
    this.packagesClient,
    this.now,
    this.snapshotStore,
    this.foregroundRefreshInterval = const Duration(minutes: 10),
    this.resumeDebounce = const Duration(seconds: 60),
  });

  final ManagedConfigReader reader;
  final DeviceStatusClient statusClient;
  final DeviceCoverageClient? coverageClient;
  final DevicePackagesClient? packagesClient;

  /// Clock injection for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// Home-widget publisher; defaults to [HomeWidgetSnapshotStore].
  final WidgetSnapshotStore? snapshotStore;

  /// One-shot delay after each completed reload while foreground.
  final Duration foregroundRefreshInterval;

  /// Skip resume auto-reload if last completed reload was more recent.
  final Duration resumeDebounce;

  @override
  State<DeviceStatusPage> createState() => _DeviceStatusPageState();
}

class _DeviceStatusPageState extends State<DeviceStatusPage>
    with WidgetsBindingObserver {
  ManagedConfig? _config;
  DeviceStatus? _status;
  OperationalStatusView _view = OperationalStatusView.loading();
  bool _loading = true;
  Future<void>? _inFlight;
  int _reloadGeneration = 0;
  int _widgetRevision = 0;
  StreamSubscription<ManagedConfig>? _subscription;
  Timer? _foregroundTimer;
  DateTime? _lastReloadCompletedAt;
  late final WidgetSnapshotStore _snapshotStore =
      widget.snapshotStore ?? const HomeWidgetSnapshotStore();
  late final DeviceCoverageClient _coverageClient =
      widget.coverageClient ?? HttpDeviceCoverageClient();
  late final DevicePackagesClient _packagesClient =
      widget.packagesClient ?? HttpDevicePackagesClient();
  List<AppliedPackage>? _packages;
  Object? _packagesError;
  bool _packagesLoading = false;
  bool _pendingPackages = false;
  bool _iccidCopied = false;
  Timer? _copiedTimer;

  /// Coverage uses the same auth completeness as status (serial or PR18).
  bool get _coverageAvailable =>
      (_config?.isComplete ?? false) &&
      _status?.plan?.coverageSummary?.available == true;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  /// Null lifecycle (common before first callback / in tests) counts as resumed.
  bool get _isResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Test/debug: at most one one-shot timer may exist.
  @visibleForTesting
  bool get debugHasForegroundTimer => _foregroundTimer != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.reader.changes.listen((_) {
      unawaited(_reload(includePackages: true));
    });
    // Do not arm timer here — only after a completed reload while resumed.
    unawaited(_reload(includePackages: true));
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _cancelForegroundTimer();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _maybeReloadOnResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _cancelForegroundTimer();
    }
  }

  void _cancelForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  /// Arm a single one-shot timer. Cancels any previous timer first.
  void _armForegroundTimer({Duration? delay}) {
    _cancelForegroundTimer();
    if (!mounted || !_isResumed) {
      return;
    }
    final wait = delay ?? widget.foregroundRefreshInterval;
    if (wait <= Duration.zero) {
      unawaited(_reload(includePackages: false));
      return;
    }
    _foregroundTimer = Timer(wait, () {
      _foregroundTimer = null;
      if (!mounted || !_isResumed) {
        return;
      }
      unawaited(_reload(includePackages: false));
    });
  }

  Duration _delayUntilNextForegroundRefresh() {
    final last = _lastReloadCompletedAt;
    if (last == null) {
      return widget.foregroundRefreshInterval;
    }
    final now = _now();
    if (now.isBefore(last)) {
      // Clock rollback: treat cadence as expired.
      return Duration.zero;
    }
    final remaining = widget.foregroundRefreshInterval - now.difference(last);
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    return remaining;
  }

  void _maybeReloadOnResume() {
    final last = _lastReloadCompletedAt;
    if (last == null) {
      unawaited(_reload(includePackages: false));
      return;
    }
    final now = _now();
    if (now.isBefore(last) ||
        now.difference(last) >= widget.resumeDebounce) {
      unawaited(_reload(includePackages: false));
      return;
    }
    // Debounced: re-arm remaining time until next foreground refresh.
    _armForegroundTimer(delay: _delayUntilNextForegroundRefresh());
  }

  void _onReloadCompleted() {
    _lastReloadCompletedAt = _now();
    if (!mounted || !_isResumed) {
      return;
    }
    _armForegroundTimer();
  }

  Future<void> _reload({bool includePackages = false}) {
    if (includePackages) {
      _pendingPackages = true;
    }
    // Single-flight: concurrent callers await the same request; clear when done.
    return _inFlight ??= _reloadBody().whenComplete(() {
      _inFlight = null;
      _onReloadCompleted();
    });
  }

  Future<void> _reloadBody() async {
    final generation = ++_reloadGeneration;
    final hadSuccess = _view.isSuccessSnapshot;

    if (!mounted) {
      return;
    }
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
          _packages = null;
          _packagesError = null;
          _view = OperationalStatusView.fromException(
            const MissingManagedConfigException(),
          );
          _loading = false;
        });
        unawaited(_publishWidgetSnapshot());
        return;
      }

      DeviceStatus? status;
      Object? statusError;
      final fetchPackages = _pendingPackages;
      _pendingPackages = false;
      final packagesFuture = fetchPackages
          ? _loadPackages(config, generation)
          : Future<void>.value();

      try {
        // Serial wins when present (even if PR18 keys are also set). Never mix.
        status = config.prefersSerialAuth
            ? await widget.statusClient.fetchStatus(
                deviceSerial: config.deviceSerial!,
              )
            : await widget.statusClient.fetchStatus(
                deviceExternalId: config.deviceExternalId!,
                credential: config.deviceCredential!,
              );
      } catch (error) {
        statusError = error;
      }

      if (!mounted || generation != _reloadGeneration) {
        return;
      }

      final loaded = status;
      if (loaded != null) {
        setState(() {
          _config = config;
          _status = loaded;
          _view = evaluateOperationalView(loaded, now: _now());
          _loading = false;
        });
        unawaited(_publishWidgetSnapshot());
        await packagesFuture;
        return;
      }

      if (hadSuccess && _status != null) {
        setState(() {
          _config = config;
          _loading = false;
        });
        await packagesFuture;
        return;
      }

      final mapped = _mapStatusError(statusError);
      setState(() {
        _config = config;
        _status = null;
        _view = OperationalStatusView.fromException(mapped);
        _loading = false;
      });
      unawaited(_publishWidgetSnapshot());
      if (statusError != null && statusError is! DeviceStatusException) {
        assert(() {
          debugPrint(
            'device status unexpected error: '
            '${redactCredential('$statusError', credentialForRedaction)}',
          );
          return true;
        }());
      }
      await packagesFuture;
    } catch (error) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      if (hadSuccess && _status != null) {
        setState(() {
          if (config != null) {
            _config = config;
          }
          _loading = false;
        });
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

  DeviceStatusException _mapStatusError(Object? error) {
    if (error is DeviceStatusException) {
      return error;
    }
    return const DeviceStatusUnexpectedException('Could not load status');
  }

  Future<void> _loadPackages(ManagedConfig config, int generation) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _packagesLoading = true;
    });
    try {
      final snapshot = config.prefersSerialAuth
          ? await _packagesClient.fetchPackages(
              deviceSerial: config.deviceSerial!,
            )
          : await _packagesClient.fetchPackages(
              deviceExternalId: config.deviceExternalId!,
              credential: config.deviceCredential!,
            );
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _packages = snapshot.results;
        _packagesError = null;
        _packagesLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _packagesError = error;
        _packagesLoading = false;
      });
    }
  }

  Future<void> _retryPackages() async {
    final config = _config;
    if (config == null || !config.isComplete) {
      return;
    }
    await _loadPackages(config, _reloadGeneration);
  }

  void _onIccidCopied() {
    _copiedTimer?.cancel();
    setState(() {
      _iccidCopied = true;
    });
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _iccidCopied = false;
      });
    });
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

  List<Widget> _heroWarningBanners(Color onPanel) {
    final bar = buildUsageBarView(
      dataRemaining: _status?.usage.dataRemaining,
      dataUsed: _status?.usage.dataUsed,
    );
    final expiry = buildExpiryCountdown(
      expiresAt: _status?.usage.expiresAt,
      now: _now(),
      notYetInUse: esimNotYetInUse(_status?.esim.status),
    );
    final messages = <String>[];
    if (bar.isLowRemaining) {
      messages.add('Low data remaining');
    }
    if (expiry.isExpired) {
      messages.add('This plan has expired');
    } else if (expiry.isToday) {
      messages.add('Expires today');
    }
    if (messages.isEmpty) {
      return const [];
    }
    return [
      const SizedBox(height: 16),
      for (final message in messages)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: onPanel.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onPanel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
    ];
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

  void _openCoverage() {
    final config = _config;
    if (config == null || !config.isComplete) {
      return;
    }
    // Prefer root navigator so a closing modal sheet cannot swallow the push.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceCoveragePage(
          deviceSerial:
              config.prefersSerialAuth ? config.deviceSerial : null,
          deviceExternalId:
              config.prefersSerialAuth ? null : config.deviceExternalId,
          credential:
              config.prefersSerialAuth ? null : config.deviceCredential,
          coverageClient: _coverageClient,
        ),
      ),
    );
  }

  Future<void> _openSupportMenu() async {
    final config = _config;
    final status = _status;
    final showCoverage = _coverageAvailable;
    // Pop sheet with a result, then navigate after it fully closes.
    // Immediate push after pop() is dropped by the navigator while the
    // modal route is still disposing (tap appears to do nothing).
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (showCoverage)
                ListTile(
                  title: const Text('Coverage'),
                  subtitle: Text(
                    '${status?.plan?.coverageSummary?.countryCount ?? 0} '
                    'countries',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop('coverage');
                  },
                ),
              ListTile(
                title: const Text('Device binding'),
                subtitle: Text(MenuFormatters.binding(status?.bindingStatus)),
              ),
              ListTile(
                title: const Text('Device serial'),
                subtitle: Text(MenuFormatters.deviceSerial(config)),
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
                subtitle: Text('RoamKit · ${AppConfig.apiBaseUrl}'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action != 'coverage') {
      return;
    }
    _openCoverage();
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
            onPressed: _loading ? null : () => _reload(includePackages: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: onPanel,
        backgroundColor: _panelColor,
        onRefresh: () => _reload(includePackages: true),
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
                            return const SizedBox(height: 20);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 8),
                            child: _PlanBadge(
                              badge: badge,
                              color: onPanel,
                              onViewCoverage:
                                  _coverageAvailable ? _openCoverage : null,
                            ),
                          );
                        },
                      ),
                      IccidCopyRow(
                        iccid: _status?.esim.iccid ?? '',
                        color: onPanel,
                        copied: _iccidCopied,
                        onCopied: _onIccidCopied,
                      ),
                      const SizedBox(height: 20),
                      UsageBarWidget(
                        bar: buildUsageBarView(
                          dataRemaining: _status?.usage.dataRemaining,
                          dataUsed: _status?.usage.dataUsed,
                        ),
                        color: onPanel,
                      ),
                      ..._heroWarningBanners(onPanel),
                      const SizedBox(height: 24),
                      _ExpiryBlock(
                        countdown: buildExpiryCountdown(
                          expiresAt: _status?.usage.expiresAt,
                          now: _now(),
                          notYetInUse: esimNotYetInUse(_status?.esim.status),
                        ),
                        color: onPanel,
                      ),
                      const SizedBox(height: 28),
                      _UpdatedRow(
                        caption: formatUpdatedCaption(view.checkedAt),
                        color: onPanel,
                        loading: _loading,
                        onRefresh: () => _reload(includePackages: true),
                      ),
                      const SizedBox(height: 28),
                      Material(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                          child: DevicePackagesSection(
                            packages: _packages,
                            packagesError: _packagesError,
                            loading: _packagesLoading,
                            onRetry: _retryPackages,
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 48),
                    if (!view.isSuccessSnapshot &&
                        view.surface != StatusSurface.slateLoading) ...[
                      Text(
                        formatUpdatedCaption(view.checkedAt),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onPanel.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
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
  const _PlanBadge({
    required this.badge,
    required this.color,
    this.onViewCoverage,
  });

  final PlanBadgeView badge;
  final Color color;
  final VoidCallback? onViewCoverage;

  @override
  Widget build(BuildContext context) {
    final tappable = onViewCoverage != null;
    final content = Row(
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
              if (tappable) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'View coverage',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: color, size: 20),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Semantics(
      button: tappable,
      label: [
        badge.title,
        if (badge.subtitle != null) badge.subtitle!,
        if (tappable) 'View coverage',
      ].join(', '),
      child: tappable
          ? InkWell(
              onTap: onViewCoverage,
              borderRadius: BorderRadius.circular(8),
              child: content,
            )
          : content,
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

class _ExpiryBlock extends StatelessWidget {
  const _ExpiryBlock({
    required this.countdown,
    required this.color,
  });

  final ExpiryCountdown countdown;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                countdown.combinedLine,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (!countdown.startsOnFirstUse &&
            countdown.remainingLine != '—' &&
            !countdown.combinedLine.contains(countdown.remainingLine)) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: color.withValues(alpha: 0.85), size: 16),
              const SizedBox(width: 6),
              Text(
                countdown.remainingLine,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UpdatedRow extends StatelessWidget {
  const _UpdatedRow({
    required this.caption,
    required this.color,
    required this.loading,
    required this.onRefresh,
  });

  final String caption;
  final Color color;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          caption,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color.withValues(alpha: 0.75),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          visualDensity: VisualDensity.compact,
          onPressed: loading ? null : onRefresh,
          icon: Icon(Icons.refresh, color: color, size: 20),
        ),
      ],
    );
  }
}
