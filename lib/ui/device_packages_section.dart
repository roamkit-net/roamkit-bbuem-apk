import 'package:flutter/material.dart';

import '../api/device_packages.dart';
import '../api/device_status.dart';
import '../status/applied_packages.dart';
import '../status/operational_status_view.dart';

/// Neutral Available / Previous / Unknown lists below the colored hero.
class DevicePackagesSection extends StatelessWidget {
  const DevicePackagesSection({
    super.key,
    required this.packages,
    required this.packagesError,
    required this.loading,
    required this.onRetry,
  });

  final List<AppliedPackage>? packages;
  final Object? packagesError;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = partitionAppliedPackages(packages ?? const []);
    final hasData = packages != null;
    final showRetry = packagesError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          availablePackagesCaption(groups.availableCount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        if (hasData && groups.availableCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _CountChip(
                icon: Icons.circle,
                iconSize: 10,
                label: '${groups.activeCount} Active',
              ),
              _CountChip(
                icon: Icons.schedule,
                label: '${groups.notActiveCount} Not active',
              ),
            ],
          ),
        ],
        if (groups.hasNotActive) ...[
          const SizedBox(height: 8),
          Text(
            'Next package starts on first use',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
        ],
        if (showRetry) ...[
          const SizedBox(height: 12),
          _PackagesErrorBanner(onRetry: onRetry),
        ],
        if (!hasData && loading) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (hasData) ...[
          const SizedBox(height: 20),
          _PackageGroup(
            title: 'Available',
            packages: groups.available,
          ),
          _PackageGroup(
            title: 'Previous',
            packages: groups.previous,
          ),
          _PackageGroup(
            title: 'Unknown',
            packages: groups.unknown,
          ),
        ],
      ],
    );
  }
}

class _PackagesErrorBanner extends StatelessWidget {
  const _PackagesErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load packages',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: const Color(0xFF334155)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _PackageGroup extends StatelessWidget {
  const _PackageGroup({
    required this.title,
    required this.packages,
  });

  final String title;
  final List<AppliedPackage> packages;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          for (final pkg in packages) _PackageTile(pkg: pkg),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.pkg});

  final AppliedPackage pkg;

  @override
  Widget build(BuildContext context) {
    final notActive = pkg.status == 'not_active';
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        title: Text(
          '${appliedPackageKindLabel(pkg.kind)} · ${packageSpecLabel(pkg)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          appliedPackageStatusLabel(pkg.status),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
        children: [
          if (pkg.createdAt != null)
            _DetailRow(label: 'Created', value: formatExpiresDisplay(pkg.createdAt)),
          if (notActive)
            const _DetailRow(
              label: 'Activated',
              value: 'Starts on first use',
            )
          else ...[
            _DetailRow(
              label: 'Activated',
              value: _formatMaybeDate(pkg.activatedAt),
            ),
            _DetailRow(
              label: 'Expires',
              value: _formatMaybeDate(pkg.expiresAt),
            ),
          ],
          _DetailRow(
            label: 'Amount',
            value: formatPaidAmount(pkg.paidUsd, pkg.currency),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMaybeDate(String? raw) {
  final parsed = parseApiDateTime(raw);
  if (parsed == null) {
    return '—';
  }
  return formatExpiresDisplay(parsed);
}
