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
import '../status/applied_packages.dart';
import '../status/home_status_chrome.dart';
import '../status/menu_formatters.dart';
import '../status/operational_status_view.dart';
import '../status/usage_bar_view.dart';
import '../widget/widget_route.dart';
import '../widget/widget_snapshot.dart';
import '../widget/widget_snapshot_store.dart';
import '../widget/widget_work.dart';
import 'device_coverage_page.dart';
import 'home_error_banner.dart';
import 'home_expiry_card.dart';
import 'home_iccid_card.dart';
import 'home_packages_cards.dart';
import 'home_refresh_icon.dart';
import 'home_skeleton.dart';
import 'home_tokens.dart';
import 'home_usage_ring.dart';

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
  StreamSubscription<ManagedConfig>? _subscription;
  Timer? _foregroundTimer;
  DateTime? _lastReloadCompletedAt;
  late final WidgetSnapshotStore _snapshotStore =
      widget.snapshotStore ?? const HomeWidgetSnapshotStore();
  late final DeviceCoverageClient _coverageClient =
      widget.coverageClient ?? HttpDeviceCoverageClient();
  late final DevicePackagesClient _packagesClient =
      widget.packagesClient ?? HttpDevicePackagesClient();
  DevicePackages? _packagesSnapshot;
  Object? _packagesError;
  bool _packagesLoading = false;
  bool _pendingPackages = false;
  bool _statusRefreshError = false;
  bool _iccidCopied = false;
  Timer? _copiedTimer;
  WidgetSnapshot? _lastWidgetSnapshot;
  final GlobalKey _packagesKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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
    unawaited(_consumeWidgetRoute());
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _scrollController.dispose();
    _cancelForegroundTimer();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_consumeWidgetRoute());
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
          _packagesSnapshot = null;
          _packagesError = null;
          _statusRefreshError = false;
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
          _statusRefreshError = false;
        });
        await packagesFuture;
        unawaited(_publishWidgetSnapshot());
        return;
      }

      if (hadSuccess && _status != null) {
        setState(() {
          _config = config;
          _loading = false;
          _statusRefreshError = true;
        });
        await packagesFuture;
        unawaited(_publishWidgetSnapshot(statusFailed: true));
        return;
      }

      final mapped = _mapStatusError(statusError);
      setState(() {
        _config = config;
        _status = null;
        _view = OperationalStatusView.fromException(mapped);
        _loading = false;
        _statusRefreshError = false;
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
          _statusRefreshError = true;
        });
        unawaited(_publishWidgetSnapshot(statusFailed: true));
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
        _packagesSnapshot = snapshot;
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
    unawaited(_publishWidgetSnapshot());
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
  Future<void> _publishWidgetSnapshot({bool statusFailed = false}) async {
    if (_view.surface == StatusSurface.slateLoading) {
      return;
    }
    final view = statusFailed
        ? OperationalStatusView.fromException(
            const DeviceStatusUnexpectedException('Could not load status'),
          )
        : _view;
    final bar = buildUsageBarView(
      dataRemaining: _status?.usage.dataRemaining,
      dataUsed: _status?.usage.dataUsed,
    );
    final snapshot = WidgetSnapshot.fromState(
      view: view,
      activePackage: _packagesSnapshot?.activePackage,
      bar: bar,
      coverageAvailable: _coverageAvailable,
      packagesFailed: _packagesError != null,
      lastGood: _lastWidgetSnapshot,
      now: _now(),
    );
    try {
      await _snapshotStore.publish(snapshot);
      _lastWidgetSnapshot = snapshot;
      if (snapshot.lastSuccessAt != null && !snapshot.updateUnavailable) {
        await WidgetWorkBridge.onSnapshotSuccess(
          lastSuccessAt: snapshot.lastSuccessAt!,
        );
      }
    } catch (error) {
      assert(() {
        debugPrint('widget snapshot publish failed: $error');
        return true;
      }());
    }
  }

  Future<void> _consumeWidgetRoute() async {
    final route = await WidgetRouteBridge.takePending();
    if (!mounted || route == null || route == WidgetRoute.home) {
      return;
    }
    switch (route) {
      case WidgetRoute.coverage:
        _openCoverage();
      case WidgetRoute.packages:
        unawaited(_reload(includePackages: true));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusPackages();
        });
      case WidgetRoute.refresh:
        unawaited(_reload(includePackages: true));
      case WidgetRoute.home:
        break;
    }
  }

  void _focusPackages() {
    final ctx = _packagesKey.currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      alignment: 0.1,
    );
  }

  List<Widget> _heroWarningBanners() {
    final bar = buildUsageBarView(
      dataRemaining: _status?.usage.dataRemaining,
      dataUsed: _status?.usage.dataUsed,
    );
    final expiresAt = _status?.usage.expiresAt;
    final messages = <String>[];
    if (bar.isLowRemaining) {
      messages.add('Low data remaining');
    }
    if (expiresAt != null) {
      final remaining = expiresAt.difference(_now());
      if (!remaining.isNegative && remaining <= const Duration(hours: 24)) {
        messages.add('Expires today');
      }
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
            color: HomeTokens.expiry.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTokens.expiry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
    ];
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
    final chrome = homeStatusChrome(view);
    final refreshing = _loading || _packagesLoading;
    final showHeroSkeleton =
        !view.isSuccessSnapshot && _status == null && _loading;
    final showPackagesSkeleton =
        _packagesSnapshot == null && _packagesLoading && _packagesError == null;
    final groups = _packagesSnapshot == null
        ? null
        : partitionAppliedPackages(
            _packagesSnapshot!.results,
            activePackage: _packagesSnapshot!.activePackage,
          );
    final titlePackage = showHeroPackageTitle(
      view,
      _packagesSnapshot?.activePackage,
    )
        ? _packagesSnapshot!.activePackage
        : null;
    final bar = buildUsageBarView(
      dataRemaining: _status?.usage.dataRemaining,
      dataUsed: _status?.usage.dataUsed,
    );
    final showRing = view.isSuccessSnapshot &&
        (chrome.kind == HomeStatusKind.active ||
            (chrome.kind == HomeStatusKind.inactive &&
                bar.kind != UsageBarKind.unavailable));
    final updated = view.isSuccessSnapshot && view.checkedAt != null
        ? formatUpdatedCaption(view.checkedAt)
        : null;

    return Scaffold(
      backgroundColor: HomeTokens.background,
      appBar: AppBar(
        backgroundColor: HomeTokens.background,
        foregroundColor: HomeTokens.primaryText,
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
            onPressed: () => _reload(includePackages: true),
            icon: HomeRefreshIcon(spinning: refreshing),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: HomeTokens.maxContentWidth,
            ),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                HomeTokens.pageInset,
                12,
                HomeTokens.pageInset,
                32,
              ),
              children: [
                if (showHeroSkeleton)
                  HomeSkeleton(
                    showHero: true,
                    showPackages: showPackagesSkeleton,
                  )
                else ...[
                  _HeroCard(
                    chrome: chrome,
                    title: titlePackage == null
                        ? null
                        : appliedPackageTitle(titlePackage),
                    showCoverage: _coverageAvailable,
                    onViewCoverage: _openCoverage,
                    showRing: showRing,
                    bar: bar,
                    showRetry: !view.isSuccessSnapshot,
                    onRetry: () => _reload(includePackages: true),
                  ),
                  if (_statusRefreshError) ...[
                    const SizedBox(height: HomeTokens.cardGap),
                    HomeErrorBanner(
                      message: 'Couldn’t refresh status',
                      onRetry: () => _reload(includePackages: true),
                    ),
                  ],
                  ..._heroWarningBanners(),
                  if (view.isSuccessSnapshot) ...[
                    const SizedBox(height: HomeTokens.cardGap),
                    HomeIccidCard(
                      iccid: _status?.esim.iccid ?? '',
                      copied: _iccidCopied,
                      onCopied: _onIccidCopied,
                    ),
                    const SizedBox(height: HomeTokens.cardGap),
                    HomeExpiryCard(
                      expiresAt: _status?.usage.expiresAt,
                      now: _now(),
                    ),
                  ],
                  const SizedBox(height: HomeTokens.cardGap),
                  if (showPackagesSkeleton)
                    const HomeSkeleton(showHero: false, showPackages: true)
                  else
                    HomePackagesCards(
                      key: _packagesKey,
                      groups: groups,
                      packagesError: _packagesError,
                      onRetry: _retryPackages,
                      firstLoadError: _packagesSnapshot == null &&
                          _packagesError != null,
                    ),
                ],
                if (updated != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    updated,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: HomeTokens.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.chrome,
    required this.title,
    required this.showCoverage,
    required this.onViewCoverage,
    required this.showRing,
    required this.bar,
    required this.showRetry,
    required this.onRetry,
  });

  final HomeStatusChrome chrome;
  final String? title;
  final bool showCoverage;
  final VoidCallback onViewCoverage;
  final bool showRing;
  final UsageBarView bar;
  final bool showRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
        side: const BorderSide(color: HomeTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            Semantics(
              label: chrome.semantics,
              child: Text(
                chrome.badge,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTokens.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 10),
              Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTokens.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (chrome.secondary != null) ...[
              const SizedBox(height: 8),
              Text(
                chrome.secondary!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTokens.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
            if (showCoverage) ...[
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'View coverage',
                child: InkWell(
                  onTap: onViewCoverage,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View coverage',
                          style: TextStyle(
                            color: HomeTokens.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: HomeTokens.primaryText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (showRing) ...[
              const SizedBox(height: 16),
              HomeUsageRing(bar: bar),
            ],
            if (showRetry) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: HomeTokens.minTap,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: HomeTokens.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
