import 'package:flutter/services.dart';

/// Asks native WorkManager to (re)schedule refresh and the 60-minute stale job.
class WidgetWorkBridge {
  static const channelName = 'net.roamkit.bbuem/widget_work';
  static const MethodChannel _channel = MethodChannel(channelName);

  static Future<void> onSnapshotSuccess({required String lastSuccessAt}) async {
    try {
      await _channel.invokeMethod<void>('onSnapshotSuccess', {
        'last_success_at': lastSuccessAt,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> ensureScheduled() async {
    try {
      await _channel.invokeMethod<void>('ensureScheduled');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
