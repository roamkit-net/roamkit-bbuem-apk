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
operational eSIM status (green / red / slate)
```

## Scope

- Read Android managed configuration (no credential storage)
- Show operational status panel: hero + plan badge + data remaining + expiry + updated time
- Plan badge from API `plan` snapshot (flag / region / globe); hidden when `plan` is null
- Support menu (read-only): binding, external id, credential present/missing, auto-topup, API env
- Reload on managed-config change; single-flight refresh; failed refresh → slate error
- Foreground auto-refresh: one-shot 10 min timer after each completed load while
  resumed; resume reloads if ≥60s since last complete (no WorkManager)
- Never log or surface the credential; never show ICCID on user surfaces
- Plan badge is informational only — does not drive GREEN/RED
- Android home-screen widgets (2×2 + 4×2) paint from the same Dart snapshot
- Coverage screen (regional/global): countries + operators from
  `POST /api/v1/device/coverage/` (not on the home-screen widget)

Out of scope:

- Org UI, billing mutations, binding management
- BlackBerry/UEM sync / provisioning automation
- Secure storage of credentials
- Headless / WorkManager widget refresh while the app is dead
- Amber / low-data warning state

## Status colors (locked)

| Surface | Color | When |
|---------|-------|------|
| GREEN | `#15803d` | `esim.status ∈ {activated, in_use}` + usable remaining + not expired |
| RED | `#b91c1c` | Expired, no usable data, or inactive domain status |
| SLATE | `#334155` | Loading, transport/config errors (never green/red) |

GREEN statuses only: `activated`, `in_use`.

Expiry: `expiresAt == null` is not expired (display `—`). `expiresAt <= now` → `EXPIRED`.

Hero labels (success): `ACTIVE` / `EXPIRED` / `NO DATA` / `EXHAUSTED` / `INACTIVE`.  
Hero labels (error): `UNAVAILABLE` / `NO DATA` (ICCID miss) / `TRY LATER` / `OFFLINE` / `ERROR`.

Success RED `NO DATA` (unusable remaining) is distinct from slate error `NO DATA` (ICCID miss).

Color logic lives in pure Dart [`lib/status/operational_status_view.dart`](lib/status/operational_status_view.dart) (no Flutter imports). The home-screen widget reuses those view-models via an atomic JSON snapshot — Kotlin only paints.

## Home-screen widgets

Two separate picker entries (no 4×4):

| Entry | Size | Shows |
|-------|------|--------|
| RoamKit Status | 2×2 | Hero + remaining |
| RoamKit Status Wide | 4×2 | Hero + plan (if present) + remaining + expiry |

Architecture:

1. After each completed status load (success or error), Flutter builds a `WidgetSnapshot` from `OperationalStatusView` + optional `PlanBadgeView`.
2. One JSON string is written under `widget_snapshot_v1`, then both providers are refreshed.
3. Native `RoamKitCompactWidgetProvider` / `RoamKitWideWidgetProvider` share `RoamKitWidgetBinder` — deserialize and paint only.

Rules:

- Open the app at least once after install / UEM config so a snapshot exists.
- In-flight reload does **not** overwrite the last good widget with a loading slate (same SWR idea as in-app).
- Failed refresh publishes slate error (never leaves a false green).
- Missing / corrupt / unknown schema → slate `UNAVAILABLE` / “Open RoamKit”.
- Tap opens `MainActivity` with no credential, ICCID, or external-id extras.
- No background fetch while the app is dead (last persisted snapshot survives reboot).

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

Launcher source art: `assets/branding/ic_launcher_source.png` (exported PNG; PSD is not in the repo).

## UEM notes

1. Upload internal APK to BlackBerry UEM.
2. App configuration values must come from API binding create/rotate.
3. Assign app + configuration to the device.
4. Open the app — status loads when both managed values are present and valid.
