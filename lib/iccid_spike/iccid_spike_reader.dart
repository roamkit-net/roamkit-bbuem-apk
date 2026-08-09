import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'iccid_spike_snapshot.dart';

/// Reads default-data subscription ICCID via Android MethodChannel (spike).
abstract class IccidSpikeReader {
  Future<bool> requestReadPhoneState();

  Future<IccidSpikeSnapshot> read();
}

class ChannelIccidSpikeReader implements IccidSpikeReader {
  ChannelIccidSpikeReader({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('net.roamkit.device/iccid_spike');

  final MethodChannel _methodChannel;

  @override
  Future<bool> requestReadPhoneState() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final granted =
        await _methodChannel.invokeMethod<bool>('requestReadPhoneState');
    return granted == true;
  }

  @override
  Future<IccidSpikeSnapshot> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const IccidSpikeSnapshot(
        androidVersion: 'non-android',
        androidSdkInt: 0,
        defaultDataSubscriptionId: null,
        readPhoneStateGranted: false,
        isManagedProfile: false,
        isProfileOwnerApp: false,
        isDeviceOwnerApp: false,
        iccid: null,
        failureReason: IccidSpikeSnapshot.iccidUnavailable,
      );
    }
    final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getIccidSpikeSnapshot',
    );
    return IccidSpikeSnapshot.fromChannelMap(raw ?? const {});
  }
}
