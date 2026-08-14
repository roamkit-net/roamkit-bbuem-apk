import 'dart:async';

import 'package:flutter/material.dart';

import '../api/device_coverage_client.dart';
import '../api/device_status_errors.dart';
import '../status/coverage_countries.dart';
import '../status/plan_badge.dart';
import 'home_card.dart';
import 'home_error_banner.dart';
import 'home_refresh_icon.dart';
import 'home_skeleton.dart';
import 'home_tokens.dart';

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
  final _search = TextEditingController();
  bool _loading = true;
  bool _hasSnapshot = false;
  bool _refreshError = false;
  String? _firstError;
  List<GroupedCoverageCountry> _grouped = const [];
  int _generation = 0;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQueryChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _generation += 1;
    _search.removeListener(_onQueryChanged);
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearQuery() {
    _search.clear();
  }

  Future<void> _reload() {
    return _inFlight ??= _reloadBody().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _reloadBody() async {
    final generation = ++_generation;
    final hadSnapshot = _hasSnapshot;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      if (!hadSnapshot) {
        _firstError = null;
      }
    });

    try {
      final serial = widget.deviceSerial?.trim();
      final result = (serial != null && serial.isNotEmpty)
          ? await widget.coverageClient.fetchCoverage(deviceSerial: serial)
          : await widget.coverageClient.fetchCoverage(
              deviceExternalId: widget.deviceExternalId,
              credential: widget.credential,
            );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _grouped = groupCoverageCountries(result.coverage ?? const []);
        _hasSnapshot = true;
        _loading = false;
        _refreshError = false;
        _firstError = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      if (hadSnapshot) {
        setState(() {
          _loading = false;
          _refreshError = true;
        });
        return;
      }
      setState(() {
        _loading = false;
        _firstError = error is DeviceStatusException
            ? error.message
            : 'Could not load coverage.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text;
    final showSearch = _hasSnapshot && _grouped.length > 10;
    final filtered = filterCoverageCountries(_grouped, query);
    final suggestions = showSearch
        ? suggestCoverageCountries(_grouped, query)
        : const <String>[];
    final firstLoad = !_hasSnapshot && _loading;

    return Scaffold(
      backgroundColor: HomeTokens.background,
      appBar: AppBar(
        backgroundColor: HomeTokens.background,
        foregroundColor: HomeTokens.primaryText,
        elevation: 0,
        title: const Text('Coverage'),
        actions: [
          IconButton(
            tooltip: 'Reload coverage',
            onPressed: () => unawaited(_reload()),
            icon: HomeRefreshIcon(spinning: _loading),
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
            child: firstLoad
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(
                      HomeTokens.pageInset,
                      12,
                      HomeTokens.pageInset,
                      32,
                    ),
                    child: Column(
                      children: [
                        HomeSkeleton(showHero: false, showPackages: true),
                        SizedBox(height: HomeTokens.cardGap),
                        HomeSkeleton(showHero: false, showPackages: true),
                        SizedBox(height: HomeTokens.cardGap),
                        HomeSkeleton(showHero: false, showPackages: true),
                      ],
                    ),
                  )
                : !_hasSnapshot
                    ? Padding(
                        padding: const EdgeInsets.all(HomeTokens.pageInset),
                        child: HomeErrorBanner(
                          message: _firstError ?? 'Couldn’t load coverage',
                          onRetry: () => unawaited(_reload()),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          HomeTokens.pageInset,
                          12,
                          HomeTokens.pageInset,
                          32,
                        ),
                        children: [
                          if (_refreshError) ...[
                            HomeErrorBanner(
                              message: 'Couldn’t refresh coverage',
                              onRetry: () => unawaited(_reload()),
                            ),
                            const SizedBox(height: HomeTokens.cardGap),
                          ],
                          if (_grouped.isEmpty)
                            const _EmptyCopy(text: 'No coverage available')
                          else ...[
                            Text(
                              _grouped.length == 1
                                  ? '1 country'
                                  : '${_grouped.length} countries',
                              style: const TextStyle(
                                color: HomeTokens.secondaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (showSearch) ...[
                              const SizedBox(height: 12),
                              _SearchField(
                                controller: _search,
                                onClear: _clearQuery,
                              ),
                            ],
                            if (suggestions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final name in suggestions)
                                _SuggestionRow(
                                  name: name,
                                  onTap: () {
                                    _search.text = name;
                                    _search.selection =
                                        TextSelection.collapsed(
                                      offset: name.length,
                                    );
                                  },
                                ),
                            ],
                            const SizedBox(height: HomeTokens.cardGap),
                            if (filtered.isEmpty)
                              _NoSearchHits(onClear: _clearQuery)
                            else
                              for (final country in filtered) ...[
                                _CountryCard(country: country),
                                const SizedBox(height: HomeTokens.cardGap),
                              ],
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search country',
      textField: true,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: HomeTokens.primaryText),
        cursorColor: HomeTokens.primaryText,
        decoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: const TextStyle(color: HomeTokens.secondaryText),
          filled: true,
          fillColor: HomeTokens.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
            borderSide: const BorderSide(color: HomeTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
            borderSide: const BorderSide(color: HomeTokens.primaryText),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : SizedBox(
                  width: HomeTokens.minTap,
                  height: HomeTokens.minTap,
                  child: IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close,
                      color: HomeTokens.primaryText,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      onTap: onTap,
      semanticLabel: name,
      semanticButton: true,
      semanticHint: 'Use suggestion',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HomeTokens.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomeTokens.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({required this.country});

  final GroupedCoverageCountry country;

  @override
  Widget build(BuildContext context) {
    final flag = country.isUnknown
        ? null
        : countryFlagEmoji(country.countryCode);
    return HomeCard(
      semanticLabel: country.semanticsLabel,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HomeTokens.minTap),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: HomeTokens.iconCircle,
                  height: HomeTokens.iconCircle,
                  child: Center(
                    child: flag != null
                        ? Text(flag, style: const TextStyle(fontSize: 22))
                        : Icon(
                            Icons.public,
                            color: country.isUnknown
                                ? HomeTokens.secondaryText
                                : HomeTokens.iccid,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HomeTokens.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (country.operators.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          country.networksLine,
                          style: const TextStyle(
                            color: HomeTokens.secondaryText,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            color: HomeTokens.secondaryText,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _NoSearchHits extends StatelessWidget {
  const _NoSearchHits({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No countries found',
              style: TextStyle(
                color: HomeTokens.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: HomeTokens.minTap,
              child: TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: HomeTokens.primaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
