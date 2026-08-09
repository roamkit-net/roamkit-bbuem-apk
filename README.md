# roamkit-device

Flutter/Android app for RoamKit managed devices (BlackBerry UEM / Android Enterprise).

## Flow

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
POST /api/v1/device/status/
  ↓
read-only eSIM / usage / expiry / auto-topup
```

## Scope (PR2)

- Read Android managed configuration (no credential storage)
- Show `Credential: present / missing` only (never plaintext)
- Call `POST /api/v1/device/status/` with the two managed values
- Show read-only status + loading / missing config / 404 / 429 / network errors
- Reload config + status on managed-config change events
- Never log or surface the credential in error messages

Out of scope:

- Org UI, billing mutations, binding management
- BlackBerry/UEM sync / provisioning automation
- Secure storage of credentials

## Managed configuration keys

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

Default API base: `https://api.staging.roamkit.net`

Override:

```bash
flutter run --dart-define=ROAMKIT_API_BASE_URL=https://api.staging.roamkit.net
flutter build apk --debug --dart-define=ROAMKIT_API_BASE_URL=https://api.staging.roamkit.net
```

Application id: `net.roamkit.device`

## UEM notes

1. Upload internal APK to BlackBerry UEM.
2. App configuration values must come from API binding create/rotate
   (not from the temporary channel-proof strings).
3. Assign app + configuration to the device.
4. Open the app — status loads when both managed values are present and valid.
