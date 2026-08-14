import 'package:home_widget/home_widget.dart';

import 'widget_snapshot.dart';

/// Publishes atomic widget snapshots for native home-screen providers.
abstract class WidgetSnapshotStore {
  Future<void> publish(WidgetSnapshot snapshot);
  Future<WidgetSnapshot?> readLast();
}

/// Records publishes for tests (no platform channels).
class RecordingWidgetSnapshotStore implements WidgetSnapshotStore {
  final List<WidgetSnapshot> published = <WidgetSnapshot>[];
  WidgetSnapshot? seed;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    published.add(snapshot);
    seed = snapshot;
  }

  @override
  Future<WidgetSnapshot?> readLast() async => seed;
}

/// No-op store for widget tests that do not assert home-widget side effects.
class NoopWidgetSnapshotStore implements WidgetSnapshotStore {
  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}

  @override
  Future<WidgetSnapshot?> readLast() async => null;
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
    final previous = await readLast();
    if (previous != null && snapshotIsStaleWrite(previous, snapshot)) {
      return;
    }
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

  @override
  Future<WidgetSnapshot?> readLast() async {
    final raw = await HomeWidget.getWidgetData<String>(WidgetSnapshot.storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return WidgetSnapshot.fromJsonString(raw);
    } on FormatException {
      return null;
    }
  }
}
