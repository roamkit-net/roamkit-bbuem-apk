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

## Scope

- Read Android managed configuration (no credential storage)
- Show `Credential: present / missing` only (never plaintext)
- Call `POST /api/v1/device/status/` with the two managed values
- Show read-only status + loading / missing config / 404 / 429 / network errors
- Reload config + status on managed-config change events
- Never log or surface the credential in error messages
- **ADR 021 spike (debug):** App bar → ICCID spike — read active/default data
  subscription ICCID only (no API / no fleet credential / no PR18 contract change)

Out of scope:

- Org UI, billing mutations, binding management
- BlackBerry/UEM sync / provisioning automation
- Secure storage of credentials
- ICCID-based status API (blocked until ADR 021 Accept)

## ICCID spike (ADR 021)

On a BlackBerry-managed device, open **ICCID spike** from the status app bar.

| Field | Purpose |
|-------|---------|
| Android version / SDK | Device context |
| Default data `subscriptionId` | Lookup target |
| `READ_PHONE_STATE` | Permission gate |
| Managed profile / owner flags | Work-profile / DPC context |
| ICCID or failure reason | Proof result |

Failure reasons: `permission_denied`, `no_default_data_subscription`,
`iccid_unavailable`, `ambiguous_subscription`.

First proof device (Pixel 6a / `staging@roamkit.net`): APK ICCID should match
UEM report `8900424101001825931`, or the screen must show why it cannot.

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
