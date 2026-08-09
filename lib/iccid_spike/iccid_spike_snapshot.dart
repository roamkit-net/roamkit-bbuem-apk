/// Result of the ADR 021 ICCID readability spike (debug only).
///
/// Does not call RoamKit API and does not change the PR18 status contract.
class IccidSpikeSnapshot {
  const IccidSpikeSnapshot({
    required this.androidVersion,
    required this.androidSdkInt,
    required this.defaultDataSubscriptionId,
    required this.readPhoneStateGranted,
    required this.isManagedProfile,
    required this.isProfileOwnerApp,
    required this.isDeviceOwnerApp,
    required this.iccid,
    required this.failureReason,
  });

  /// Known failure reasons for the spike UI (ADR 021 Accept gate).
  static const String permissionDenied = 'permission_denied';
  static const String noDefaultDataSubscription = 'no_default_data_subscription';
  static const String iccidUnavailable = 'iccid_unavailable';
  static const String ambiguousSubscription = 'ambiguous_subscription';

  static const Set<String> knownFailureReasons = {
    permissionDenied,
    noDefaultDataSubscription,
    iccidUnavailable,
    ambiguousSubscription,
  };

  final String androidVersion;
  final int androidSdkInt;
  final int? defaultDataSubscriptionId;
  final bool readPhoneStateGranted;
  final bool isManagedProfile;
  final bool isProfileOwnerApp;
  final bool isDeviceOwnerApp;
  final String? iccid;
  final String? failureReason;

  bool get hasIccid => iccid != null && iccid!.trim().isNotEmpty;

  factory IccidSpikeSnapshot.fromChannelMap(Map<Object?, Object?> raw) {
    final reasonRaw = raw['failureReason'] as String?;
    final reason = reasonRaw == null || reasonRaw.isEmpty
        ? null
        : (knownFailureReasons.contains(reasonRaw)
            ? reasonRaw
            : iccidUnavailable);

    final subId = raw['defaultDataSubscriptionId'];
    int? parsedSubId;
    if (subId is int) {
      parsedSubId = subId < 0 ? null : subId;
    }

    final iccidRaw = raw['iccid'] as String?;
    final iccid =
        iccidRaw == null || iccidRaw.trim().isEmpty ? null : iccidRaw.trim();

    return IccidSpikeSnapshot(
      androidVersion: (raw['androidVersion'] as String?) ?? 'unknown',
      androidSdkInt: (raw['androidSdkInt'] as int?) ?? 0,
      defaultDataSubscriptionId: parsedSubId,
      readPhoneStateGranted: raw['readPhoneStateGranted'] == true,
      isManagedProfile: raw['isManagedProfile'] == true,
      isProfileOwnerApp: raw['isProfileOwnerApp'] == true,
      isDeviceOwnerApp: raw['isDeviceOwnerApp'] == true,
      iccid: iccid,
      failureReason: reason,
    );
  }
}
