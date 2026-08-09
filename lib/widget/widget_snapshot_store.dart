import 'package:home_widget/home_widget.dart';

import 'widget_snapshot.dart';

/// Publishes atomic widget snapshots for native home-screen providers.
abstract class WidgetSnapshotStore {
  Future<void> publish(WidgetSnapshot snapshot);
}

/// Records publishes for tests (no platform channels).
class RecordingWidgetSnapshotStore implements WidgetSnapshotStore {
  final List<WidgetSnapshot> published = <WidgetSnapshot>[];

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    published.add(snapshot);
  }
}

/// No-op store for widget tests that do not assert home-widget side effects.
class NoopWidgetSnapshotStore implements WidgetSnapshotStore {
  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}
}

/// Persists JSON via home_widget and refreshes both Android providers.
class HomeWidgetSnapshotStore implements WidgetSnapshotStore {
  const HomeWidgetSnapshotStore();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    assert(
      !snapshot.containsForbiddenKeys,
      'Widget snapshot must not contain sensitive keys',
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetSnapshot.storageKey,
      snapshot.toJsonString(),
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: WidgetSnapshot.compactProvider,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: WidgetSnapshot.wideProvider,
    );
  }
}
