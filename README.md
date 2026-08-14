# roamkit-bbuem-apk

Flutter/Android app for RoamKit managed devices (BlackBerry UEM / Android Enterprise).

## Flow

```text
BlackBerry UEM App Config
  roamkit.device_serial = %SerialNumber%
  (optional PR18 fallback:
   roamkit.device_external_id + roamkit.device_credential)
  ↓
RoamKit APK (net.roamkit.bbuem)
  RestrictionsManager
  ↓
POST /api/v1/device/status/
  { "device_serial" }          ← preferred when serial present
  or PR18 device_external_id + credential
  ↓
operational eSIM status (green / red / slate)
  +
POST /api/v1/device/packages/  ← on open + manual Refresh only
  same body (never client ICCID)
  ↓
Available / Previous / Unknown package lists
```

## Scope

- Read Android managed configuration (no credential storage)
- Home hero: operational color + plan title + full ICCID (copy) + usage bar
  (remaining + used from status) + expiry countdown + updated time
- Package lists below the hero from `POST /api/v1/device/packages/`
- Plan badge from API `plan` title + coverage icon; no stale allowance/validity subtitle
- Support menu (read-only): binding, external id, credential present/missing, auto-topup, API env
- Reload on managed-config change; single-flight refresh
- Partial failure keeps last-good data (packages Retry does not wipe the hero)
- Foreground auto-refresh: one-shot 10 min timer after each completed load while
  resumed (status only — does not poll package history); resume reloads status
  if ≥60s since last complete
- Never log or surface the credential; ICCID is on the home hero only
- Plan badge is informational only — does not drive GREEN/RED
- Android home-screen widgets paint snapshot v2 (dark 4×3); both existing
  receivers stay so upgrades do not drop instances
- Coverage screen (regional/global): countries + operators from
  `POST /api/v1/device/coverage/`

Out of scope:

- Org UI, billing mutations, binding management
- BlackBerry/UEM sync / provisioning automation
- Secure storage of credentials
- Package lists / ICCID on home-screen widgets

## Status colors (locked)

| Surface | Color | When |
|---------|-------|------|
| GREEN | `#15803d` | usable remaining + not date-expired + `esim.status ∈ {activated, in_use, expired}` |
| RED | `#b91c1c` | Date-expired, no usable data, exhausted, or inactive domain status |
| SLATE | `#334155` | Loading, transport/config errors (never green/red) |

GREEN statuses: `activated`, `in_use`. Domain `expired` is also GREEN when remaining is usable and `expiresAt` is null or in the future (top-up after ADR 014 terminal lifecycle).

Expiry: `expiresAt == null` is not expired (display `—`). `expiresAt <= now` → `EXPIRED`. Domain `esim.status == expired` alone is not EXPIRED.

Hero labels (success): `ACTIVE` / `EXPIRED` / `NO DATA` / `EXHAUSTED` / `INACTIVE`.  
Hero labels (error): `UNAVAILABLE` / `NO DATA` (ICCID miss) / `TRY LATER` / `OFFLINE` / `ERROR`.

Success RED `NO DATA` (unusable remaining) is distinct from slate error `NO DATA` (ICCID miss).

Color logic lives in pure Dart [`lib/status/operational_status_view.dart`](lib/status/operational_status_view.dart) (no Flutter imports). The home-screen widget reuses those view-models via an atomic JSON snapshot — Kotlin only paints.

## Home-screen widgets

Both existing receivers (`RoamKitCompactWidgetProvider`,
`RoamKitWideWidgetProvider`) stay registered and paint the same dark 4×3
layout from snapshot v2 (`widget_snapshot`). Flutter decides meaning; native
only paints. WorkManager runs a best-effort 15-minute refresh when connected
and a no-network stale flip at `last_success_at + 60 min`.

Rules:

- In-flight reload does **not** publish a loading snapshot.
- Status error keeps last-good usage and paints `↻ UNAVAILABLE`.
- Packages error hides the package title and does not turn ACTIVE into UNAVAILABLE.
- Missing / corrupt / unknown schema → empty `UNAVAILABLE`.
- Taps use an explicit Activity extra (`home` / `packages` / `refresh` /
  `coverage`). No public `roamkit://` intent filter, ICCID, or credential extras.

## Managed configuration keys

| Key | Purpose |
|-----|---------|
| `roamkit.device_serial` | Normative v1 status identity (UEM `%SerialNumber%`; not a secret) |
| `roamkit.device_external_id` | PR18 fallback `DeviceBinding` lookup id (not a secret) |
| `roamkit.device_credential` | PR18 fallback opaque secret for status/coverage |

When `roamkit.device_serial` is present, status, coverage, and packages use
the serial path even if PR18 keys are also set.

Do **not** put `organization_id`, `account_id`, ICCID, `fleet_*`, or user JWTs in managed config.

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

### Signed release APK

Release builds on `main` are signed with the qubitmdm `qubit-signer` keystore via GitHub Actions (`Release APK` workflow). Secrets (not in git):

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEYSTORE_ALIAS` (`qubit-signer`)

Local signed release (Windows): copy `android/key.properties.example` → `android/key.properties` and fill from `C:\Users\avrca\Documents\Projects\keys\qubitmdm\qubit-signer.secrets`, then:

```bash
flutter build apk --release --dart-define=ROAMKIT_API_BASE_URL=https://api.roamkit.net
```

Application id: `net.roamkit.bbuem`

Launcher source art: `assets/branding/ic_launcher_source.png` (exported PNG; PSD is not in the repo).

## UEM notes

1. Upload internal APK to BlackBerry UEM.
2. App configuration values must come from API binding create/rotate.
3. Assign app + configuration to the device.
4. Open the app — status loads when both managed values are present and valid.
