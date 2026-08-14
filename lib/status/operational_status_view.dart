import '../api/device_status.dart';
import '../api/device_status_errors.dart';
import 'remaining_parser.dart';

/// Visual surface for the in-app status panel.
///
/// Pure Dart view-model — no Flutter imports. Reusable by a future
/// Android home-screen widget without duplicating color rules.
enum StatusSurface { green, red, slateLoading, slateError }

/// Locked operational presentation derived from API status or errors.
class OperationalStatusView {
  const OperationalStatusView({
    required this.surface,
    required this.heroLabel,
    required this.isSuccessSnapshot,
    this.dataRemainingDisplay,
    this.expiresDisplay = '—',
    this.checkedAt,
    this.errorDetail,
    this.semanticsSummary,
  });

  final StatusSurface surface;
  final String heroLabel;
  final bool isSuccessSnapshot;
  final String? dataRemainingDisplay;
  final String expiresDisplay;
  final DateTime? checkedAt;
  final String? errorDetail;
  final String? semanticsSummary;

  static const greenColorValue = 0xFF15803D;
  static const redColorValue = 0xFFB91C1C;
  static const slateColorValue = 0xFF334155;

  static const aliveStatuses = {'activated', 'in_use'};

  /// First-load / in-flight without a prior success snapshot.
  factory OperationalStatusView.loading() {
    return const OperationalStatusView(
      surface: StatusSurface.slateLoading,
      heroLabel: 'Checking eSIM…',
      isSuccessSnapshot: false,
      semanticsSummary: 'Checking eSIM status',
    );
  }

  /// Map transport / config exceptions to slate error (never green/red).
  factory OperationalStatusView.fromException(DeviceStatusException error) {
    return switch (error) {
      MissingManagedConfigException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'UNAVAILABLE',
        isSuccessSnapshot: false,
        errorDetail: 'Waiting for managed configuration',
        semanticsSummary: 'Unavailable. Waiting for managed configuration',
      ),
      DeviceStatusIccidNotFoundException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'NO DATA',
        isSuccessSnapshot: false,
        errorDetail: 'No RoamKit data for this device',
        semanticsSummary: 'No data. No RoamKit data for this device',
      ),
      DeviceStatusNotFoundException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'UNAVAILABLE',
        isSuccessSnapshot: false,
        errorDetail: 'Device not found or credential invalid',
        semanticsSummary: 'Unavailable. Device not found or credential invalid',
      ),
      DeviceStatusUemInventoryUnavailableException() =>
        const OperationalStatusView(
          surface: StatusSurface.slateError,
          heroLabel: 'UNAVAILABLE',
          isSuccessSnapshot: false,
          errorDetail: 'UEM SIM inventory is temporarily unavailable',
          semanticsSummary: 'Unavailable. UEM inventory temporarily unavailable',
        ),
      DeviceStatusRateLimitedException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'TRY LATER',
        isSuccessSnapshot: false,
        errorDetail: 'Too many requests — try again later',
        semanticsSummary: 'Try later. Too many requests',
      ),
      DeviceStatusNetworkException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'OFFLINE',
        isSuccessSnapshot: false,
        errorDetail: 'Network error',
        semanticsSummary: 'Offline. Network error',
      ),
      DeviceStatusUnexpectedException() => const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'ERROR',
        isSuccessSnapshot: false,
        errorDetail: 'Could not load status',
        semanticsSummary: 'Error. Could not load status',
      ),
      DevicePackagesProviderUnavailableException() =>
        const OperationalStatusView(
          surface: StatusSurface.slateError,
          heroLabel: 'ERROR',
          isSuccessSnapshot: false,
          errorDetail: 'Package history is temporarily unavailable',
          semanticsSummary: 'Error. Package history temporarily unavailable',
        ),
    };
  }

  /// Malformed success payload that cannot be trusted for operational color.
  factory OperationalStatusView.malformedPayload() {
    return const OperationalStatusView(
      surface: StatusSurface.slateError,
      heroLabel: 'ERROR',
      isSuccessSnapshot: false,
      errorDetail: 'Could not load status',
      semanticsSummary: 'Error. Could not load status',
    );
  }
}

/// Evaluate a successful API snapshot into green/red operational UI.
///
/// [now] must be injected — never call [DateTime.now] inside this function.
OperationalStatusView evaluateOperationalView(
  DeviceStatus status, {
  required DateTime now,
}) {
  if (status.usage.expiryMalformed) {
    return OperationalStatusView.malformedPayload();
  }

  final remaining = parseDataRemaining(status.usage.dataRemaining);
  final expiresAt = status.usage.expiresAt;
  final expiresDisplay = formatExpiresDisplay(expiresAt);
  final statusKey = status.esim.status.trim().toLowerCase();

  final expired = expiresAt != null && !expiresAt.isAfter(now);
  String hero;
  StatusSurface surface;

  // Date-driven EXPIRED only. Domain `esim.status == expired` is terminal
  // (ADR 014) and can lag a fulfilled top-up whose usage cache already has
  // remaining data and a future expires_at.
  if (expired) {
    hero = 'EXPIRED';
    surface = StatusSurface.red;
  } else if (!remaining.isUsable) {
    hero = 'NO DATA';
    surface = StatusSurface.red;
  } else if (OperationalStatusView.aliveStatuses.contains(statusKey) ||
      statusKey == 'expired') {
    hero = 'ACTIVE';
    surface = StatusSurface.green;
  } else if (statusKey == 'exhausted') {
    hero = 'EXHAUSTED';
    surface = StatusSurface.red;
  } else {
    hero = 'INACTIVE';
    surface = StatusSurface.red;
  }

  final dataDisplay = remaining.display ?? '—';
  final semantics = _semanticsSummary(
    hero: hero,
    dataDisplay: dataDisplay,
    expiresDisplay: expiresDisplay,
  );

  return OperationalStatusView(
    surface: surface,
    heroLabel: hero,
    isSuccessSnapshot: true,
    dataRemainingDisplay: dataDisplay,
    expiresDisplay: expiresDisplay,
    checkedAt: status.checkedAt,
    semanticsSummary: semantics,
  );
}

String formatExpiresDisplay(DateTime? expiresAt) {
  if (expiresAt == null) {
    return '—';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = expiresAt.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Format `Updated HH:mm` in local time; null → `Updated —`.
String formatUpdatedCaption(DateTime? checkedAt) {
  if (checkedAt == null) {
    return 'Updated —';
  }
  final local = checkedAt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return 'Updated $hh:$mm';
}

String _semanticsSummary({
  required String hero,
  required String dataDisplay,
  required String expiresDisplay,
}) {
  final heroLower = hero.toLowerCase().replaceAll('_', ' ');
  return 'eSIM $heroLower, $dataDisplay remaining, expires $expiresDisplay';
}
