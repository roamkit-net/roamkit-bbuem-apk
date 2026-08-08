/// Managed app configuration keys consumed from Android RestrictionsManager.
///
/// These must match `android/app/src/main/res/xml/app_restrictions.xml` and
/// the keys configured in BlackBerry UEM (or other MDM) app configuration.
abstract final class ManagedConfigKeys {
  static const deviceExternalId = 'roamkit.device_external_id';
  static const deviceCredential = 'roamkit.device_credential';
}
