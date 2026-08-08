import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'managed_config.dart';

/// Reads Android managed configuration (app restrictions) into [ManagedConfig].
abstract class ManagedConfigReader {
  Future<ManagedConfig> read();

  /// Emits updated snapshots when the MDM pushes new restrictions.
  Stream<ManagedConfig> get changes;
}

class ChannelManagedConfigReader implements ManagedConfigReader {
  ChannelManagedConfigReader({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('net.roamkit.device/managed_config'),
        _eventChannel = eventChannel ??
            const EventChannel('net.roamkit.device/managed_config_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Future<ManagedConfig> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ManagedConfig(
        deviceExternalId: null,
        deviceCredential: null,
      );
    }
    final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getManagedConfig',
    );
    return ManagedConfig.fromChannelMap(raw ?? const {});
  }

  @override
  Stream<ManagedConfig> get changes {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<ManagedConfig>.empty();
    }
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      return ManagedConfig.fromChannelMap(map);
    });
  }
}
