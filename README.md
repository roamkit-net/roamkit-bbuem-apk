# roamkit-device

Flutter/Android app for RoamKit managed devices (BlackBerry UEM / Android Enterprise).

## PR1 scope

Prove the **UEM → APK managed configuration channel**:

```text
BlackBerry UEM
  ↓
managed app configuration
  ↓
RoamKit APK (net.roamkit.device)
  ↓
reads:
  roamkit.device_external_id
  roamkit.device_credential
  ↓
debug screen shows values
```

Out of scope for PR1:

- API calls (`POST /api/v1/device/status/`)
- credential persistence / secure storage
- org, billing, or eSIM UI
- BlackBerry backend sync

`device_credential` is shown in plaintext **only** for UEM delivery validation.
Remove that debug display before wiring the status API.

## Managed configuration keys

Declared in `android/app/src/main/res/xml/app_restrictions.xml` and linked from the
manifest via `android.content.APP_RESTRICTIONS`:

| Key | Purpose |
|-----|---------|
| `roamkit.device_external_id` | Active `DeviceBinding` lookup id (not a secret) |
| `roamkit.device_credential` | Opaque device secret for device status auth |

Do **not** put `organization_id`, `account_id`, ICCID, or user JWTs in managed config.

## Local development

```bash
flutter pub get
flutter analyze
flutter test
```

Build a debug APK for UEM upload (requires Android SDK):

```bash
flutter build apk --debug
```

Application id: `net.roamkit.device`

## UEM validation checklist

1. Upload internal APK to BlackBerry UEM.
2. Configure app configuration with the two keys above (values from API binding create/rotate).
3. Assign app + config to a Work space / Android Enterprise device.
4. Open the app and confirm both values appear.
5. Only then proceed to status API integration (next PR).
