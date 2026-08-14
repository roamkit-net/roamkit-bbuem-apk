import 'package:flutter/material.dart';

import '../api/device_packages.dart';
import '../api/device_status.dart';
import '../status/applied_packages.dart';
import '../status/home_status_chrome.dart';
import '../status/operational_status_view.dart';
import 'home_card.dart';
import 'home_error_banner.dart';
import 'home_tokens.dart';

class HomePackagesCards extends StatefulWidget {
  const HomePackagesCards({
    super.key,
    required this.groups,
    required this.packagesError,
    required this.onRetry,
    this.firstLoadError = false,
  });

  final AppliedPackageGroup? groups;
  final Object? packagesError;
  final VoidCallback onRetry;
  final bool firstLoadError;

  @override
  State<HomePackagesCards> createState() => _HomePackagesCardsState();
}

class _HomePackagesCardsState extends State<HomePackagesCards> {
  bool _packagesOpen = true;
  bool _previousOpen = false;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _logUnknown();
  }

  @override
  void didUpdateWidget(covariant HomePackagesCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.groups, widget.groups)) {
      _logUnknown();
    }
  }

  void _logUnknown() {
    final unknown = widget.groups?.omittedUnknown ?? const [];
    for (final pkg in unknown) {
      debugPrint(
        'omitting unknown package status=${pkg.status} id=${pkg.id}',
      );
    }
  }

  void _toggleRow(String id) {
    setState(() {
      _expandedId = _expandedId == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firstLoadError) {
      return HomeCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HomeErrorBanner(
            message: 'Couldn’t refresh packages',
            onRetry: widget.onRetry,
          ),
        ),
      );
    }

    final groups = widget.groups;
    if (groups == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (groups.hasCurrent) ...[
          _CollapsibleCard(
            icon: Icons.inventory_2,
            iconColor: HomeTokens.used,
            title: 'Packages',
            subtitle: groups.headerSummary,
            open: _packagesOpen,
            expandLabel: _packagesOpen ? 'Collapse' : 'Expand',
            semantics:
                'Packages, ${_packagesOpen ? 'expanded' : 'collapsed'}'
                '${groups.headerSummary == null ? '' : ', ${groups.headerSummary}'}',
            onToggle: () => setState(() => _packagesOpen = !_packagesOpen),
            child: Column(
              children: [
                if (widget.packagesError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HomeErrorBanner(
                      message: 'Couldn’t refresh packages',
                      onRetry: widget.onRetry,
                    ),
                  ),
                for (final pkg in groups.active)
                  _PackageRow(
                    pkg: pkg,
                    expanded: _expandedId == pkg.id,
                    onToggle: () => _toggleRow(pkg.id),
                  ),
                for (final pkg in groups.notActive)
                  _PackageRow(
                    pkg: pkg,
                    expanded: _expandedId == pkg.id,
                    onToggle: () => _toggleRow(pkg.id),
                  ),
                for (final pkg in groups.queued)
                  _PackageRow(
                    pkg: pkg,
                    expanded: _expandedId == pkg.id,
                    onToggle: () => _toggleRow(pkg.id),
                  ),
              ],
            ),
          ),
          if (groups.previous.isNotEmpty)
            const SizedBox(height: HomeTokens.cardGap),
        ],
        if (groups.previous.isNotEmpty)
          _CollapsibleCard(
            icon: Icons.history,
            iconColor: HomeTokens.previous,
            title: previousCardTitle(groups.previous),
            open: _previousOpen,
            expandLabel: _previousOpen ? 'Collapse' : 'Expand',
            semantics:
                'Previous, ${_previousOpen ? 'expanded' : 'collapsed'}',
            onToggle: () => setState(() => _previousOpen = !_previousOpen),
            child: Column(
              children: [
                for (final pkg in groups.previous)
                  _PackageRow(
                    pkg: pkg,
                    expanded: _expandedId == pkg.id,
                    onToggle: () => _toggleRow(pkg.id),
                    previous: true,
                  ),
              ],
            ),
          ),
        if (!groups.hasCurrent &&
            groups.previous.isEmpty &&
            widget.packagesError != null)
          HomeCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeErrorBanner(
                message: 'Couldn’t refresh packages',
                onRetry: widget.onRetry,
              ),
            ),
          ),
      ],
    );
  }
}

class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.open,
    required this.expandLabel,
    required this.semantics,
    required this.onToggle,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool open;
  final String expandLabel;
  final String semantics;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Column(
        children: [
          Semantics(
            button: true,
            label: semantics,
            hint: expandLabel,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: HomeTokens.minTap),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      HomeCircleIcon(icon: icon, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomeTokens.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: HomeTokens.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: HomeTokens.minTap,
                        height: HomeTokens.minTap,
                        child: Icon(
                          open
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: HomeTokens.primaryText,
                          semanticLabel: expandLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.pkg,
    required this.expanded,
    required this.onToggle,
    this.previous = false,
  });

  final AppliedPackage pkg;
  final bool expanded;
  final VoidCallback onToggle;
  final bool previous;

  @override
  Widget build(BuildContext context) {
    final title = appliedPackageTitle(pkg);
    final status = appliedPackageStatusLabel(pkg.status);
    final statusColor = previous || pkg.status == 'expired'
        ? HomeTokens.previous
        : pkg.status == 'queued'
            ? HomeTokens.used
            : HomeTokens.primaryText;
    final symbol = switch (pkg.status) {
      'active' => '✓ ',
      'queued' => '',
      'expired' || 'finished' => '',
      _ => '',
    };

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: HomeTokens.packageRowMin,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomeTokens.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$symbol$status',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: HomeTokens.minTap,
                    height: HomeTokens.minTap,
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: HomeTokens.secondaryText,
                      semanticLabel: expanded ? 'Collapse' : 'Expand',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) _PackageDetails(pkg: pkg, previous: previous),
      ],
    );
  }
}

class _PackageDetails extends StatelessWidget {
  const _PackageDetails({required this.pkg, required this.previous});

  final AppliedPackage pkg;
  final bool previous;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    final allowance = pkg.dataAllowance.trim();
    if (allowance.isNotEmpty) {
      rows.add(('Data', allowance));
    }
    if (pkg.validityDays > 0) {
      rows.add((
        'Duration',
        pkg.validityDays == 1 ? '1 day' : '${pkg.validityDays} days',
      ));
    }
    if (previous && pkg.createdAt != null) {
      rows.add(('Purchased', formatExpiresDisplay(pkg.createdAt)));
    }
    if (pkg.status != 'not_active') {
      final activated = _formatMaybeDate(pkg.activatedAt);
      if (activated != null) {
        rows.add(('Activated', activated));
      }
      final expires = _formatMaybeDate(pkg.expiresAt);
      if (expires != null) {
        rows.add(('Expires', expires));
      }
    }
    final paid = formatPaidAmountOrNull(pkg.paidUsd, pkg.currency);
    if (paid != null) {
      rows.add(('Paid', paid));
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: HomeTokens.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        color: HomeTokens.primaryText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String? _formatMaybeDate(String? raw) {
  final parsed = parseApiDateTime(raw);
  if (parsed == null) {
    return null;
  }
  return formatExpiresDisplay(parsed);
}
