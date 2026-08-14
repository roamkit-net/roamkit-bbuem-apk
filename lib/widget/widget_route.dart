import 'package:flutter/services.dart';

/// Closed route enum carried in an explicit Activity extra.
/// Not a public custom-scheme intent filter.
enum WidgetRoute { home, packages, refresh, coverage }

class WidgetRouteBridge {
  static const channelName = 'net.roamkit.bbuem/widget_route';
  static const extraKey = 'roamkit_widget_route';

  static const MethodChannel _channel = MethodChannel(channelName);

  static WidgetRoute? parse(String? raw) {
    return switch (raw) {
      'home' => WidgetRoute.home,
      'packages' => WidgetRoute.packages,
      'refresh' => WidgetRoute.refresh,
      'coverage' => WidgetRoute.coverage,
      _ => raw == null || raw.isEmpty ? null : WidgetRoute.home,
    };
  }

  static Future<WidgetRoute?> takePending() async {
    try {
      final raw = await _channel.invokeMethod<String>('takePendingRoute');
      return parse(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
