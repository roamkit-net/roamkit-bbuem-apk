/// UEM / Android Enterprise managed app configuration keys.
///
/// Must match BlackBerry UEM App Config keys and
/// `android/app/src/main/res/xml/app_restrictions.xml`.
abstract final class ManagedConfigKeys {
  /// Normative ADR 021 Option C″ identity from UEM `%SerialNumber%`.
  static const deviceSerial = 'roamkit.device_serial';

  /// PR18 fallback lookup id (not a secret).
  static const deviceExternalId = 'roamkit.device_external_id';

  /// PR18 fallback opaque device secret.
  static const deviceCredential = 'roamkit.device_credential';
}
