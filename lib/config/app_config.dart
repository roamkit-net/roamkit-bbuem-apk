/// Compile-time app configuration.
///
/// Override API base with:
/// `flutter run --dart-define=ROAMKIT_API_BASE_URL=https://api.staging.roamkit.net`
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'ROAMKIT_API_BASE_URL',
    defaultValue: 'https://api.staging.roamkit.net',
  );
}
