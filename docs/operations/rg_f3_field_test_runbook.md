# AETRON — RG-F3 Real-Device Field Execution Runbook

**Document Version:** 1.0.0  
**Target:** Physical iPhone (Primary) & Physical Android Device  
**Commit Baseline:** `fa08471f723f1e44b0796a508f705e770265919b`  
**PR:** Stacked DRAFT PR #10 targeting `feat/rg-f2-native-boundary`  
**Governance:** RG-F1 and RG-F2 Code/Integration GO. Overall RG-F HOLD.

---

## 1. Safety & Credential Protection Rules

> [!CAUTION]
> **Strict Operational Security Policy:**
> 1. **Zero Personal Credentials:** Never commit personal user emails, Supabase service-role keys, or JWT bearer tokens into git, pull request descriptions, or public CI logs.
> 2. **Zero Personal Location Traces:** Do not commit raw GPS coordinates (latitude/longitude) of residences, private workplaces, or sensitive routes. The verification tool automatically validates canonical hash digests without exposing coordinate streams.
> 3. **Non-Production Supabase Environment:** All field tests must use designated test athlete accounts in the non-production Supabase instance (`<NON_PROD_SUPABASE_URL>`).
> 4. **No Fabricated Evidence:** Operational verification can ONLY be marked PASS when real hardware traces, extracted JSONL files, and authenticated cloud read-backs match with full canonical digest equality.

---

## 2. Equipment & Software Prerequisites

1. **Hardware:**
   - 1 physical iPhone (iOS 17+ or 18+, Lightning/USB-C cable connected to Mac workstation).
   - *Optional:* 1 physical Android phone (Android 10+, USB debugging enabled).
2. **Mac Workstation:**
   - macOS with Flutter 3.47.1 (`~/development/flutter/bin/flutter`).
   - Xcode 15+ / 16+ with command-line tools installed.
   - Apple Developer account profile configured in Xcode project (`DEVELOPMENT_TEAM = ZDR9AX4U8V`).
3. **Network:**
   - Cellular data connection active on test phone.
   - Ability to toggle Airplane mode on/off during tests.

---

## 3. Device Installation Procedures

### 3.1 Inspect Connected Devices
Connect the iPhone to the Mac via USB, unlock the phone, and tap *"Trust This Computer"*. Run:
```bash
flutter devices
```
Identify the connected iPhone Device ID (e.g., `00008101-001234567890001E`).

### 3.2 Run Debug / Profile on iPhone
Launch Aetron directly on the iPhone with all required `--dart-define` configurations:
```bash
./run.sh --profile -d <IPHONE_DEVICE_ID>
```
*Alternatively, for debug mode with hot reload:*
```bash
./run.sh -d <IPHONE_DEVICE_ID>
```

### 3.3 Verify Permissions on First Launch
1. Launch app on device.
2. Log in using a non-production test account (e.g. `test-athlete-01@aetron.local`).
3. When prompted, grant **Location: "Allow While Using App"**.
4. When prompted by iOS for background location, select **"Always Allow"** (or allow background updates).
5. Verify the blue status pill / location icon appears in the iOS status bar during active recording.

---

## 4. Field Test Scenarios & Step-by-Step Protocols

### Protocol RG-F3-01: Foreground Outdoor Workout Capture
1. **Action:** Walk outdoors in an area with clear open sky.
2. **Recording:** Open Aetron -> Record screen -> Select **Outdoor Running** or **Walking** -> Tap **Start**.
3. **Duration:** Record continuously for at least 3 minutes (minimum 180 GPS points at 1 Hz).
4. **Completion:** Tap **Pause** -> Tap **Finish** -> Confirm workout completion.
5. **Observation:** Ensure the workout summary screen displays and cloud upload sync indicator completes.

### Protocol RG-F3-02: Network Disconnect & Reconnect Recovery
1. **Action:** Start an outdoor workout session. Record normally for 60 seconds.
2. **Offline Simulation:** Enable **Airplane Mode** (disable Cellular and Wi-Fi) on the device.
3. **Continue Recording:** Continue walking for another 60 seconds with Airplane Mode active.
4. **Finish Offline:** Tap **Pause** -> Tap **Finish** while still offline.
5. **Verify Local State:** Confirm the session saves locally without crashing. Note that raw GPS points remain in the local write-ahead recovery journal.
6. **Reconnect:** Disable Airplane Mode (restore network connectivity). Open the app or return to Home screen.
7. **Verification:** Confirm the outbox service resumes, uploads pending points, and completes cloud verification.

### Protocol RG-F3-03: App Termination & Restart Recovery
1. **Action:** Start an outdoor workout session and record for 60 seconds.
2. **Finish Session:** Tap **Finish** to finalize the workout and write the journal manifest.
3. **Force-Quit:** Immediately swipe up from the bottom of the screen to enter iOS App Switcher, and swipe away Aetron to force-quit the process.
4. **Restart:** Re-launch Aetron from the iOS home screen.
5. **Verification:** The outbox worker enumerates pending sessions on startup (`resumePendingUploads`), discovers the unsynced raw GPS points, and reconciles them.

### Protocol RG-F3-04: Background Recording with Screen Locked
1. **Action:** Start an outdoor workout session in Aetron.
2. **Lock Screen:** Press the physical power/lock button on the iPhone to lock the screen.
3. **Walk:** Walk outdoors for 2–3 minutes with the phone in your pocket and screen locked.
4. **Unlock & Inspect:** Unlock phone. Confirm the blue location indicator remained active throughout.
5. **Finish:** Finish session and confirm continuous 1 Hz sample points without large unexpected gaps.

---

## 5. Evidence Extraction Procedure

### 5.1 Identify Session ID
In the app or via device logs, identify the active Session ID (`<SESSION_UUID>`).
During execution via USB, view live logs in terminal:
```bash
# On Mac with iPhone connected:
idevicesyslog | grep "\[RawGps"
# Or using log stream:
log stream --predicate 'process == "Aetron"' --level debug
```
Look for log line:
```
[RawGpsRecoveryJournal] Checkpoint finalized: <SESSION_UUID> (count: N)
```

### 5.2 Extract Local Journal & Manifest from iPhone
1. Open **Xcode** on Mac.
2. Go to menu: **Window > Devices and Simulators** (or press `Cmd+Shift+2`).
3. Select your connected iPhone from the left sidebar.
4. Under **Installed Apps**, select **Aetron**.
5. Click the **Gear icon (⚙)** at the bottom of the apps list and select **"Download Container..."**.
6. Save the container package as `Aetron_Container.xcappdata` to your Mac.
7. Right-click `Aetron_Container.xcappdata` in Finder and select **"Show Package Contents"**.
8. Navigate to:
   ```
   AppData/Documents/raw_gps_recovery/
   ```
9. Locate the two files for your session:
   - `<SESSION_UUID>.jsonl` (raw sensor points)
   - `<SESSION_UUID>.manifest.json` (cryptographic integrity manifest)
10. Copy these two files to a local working folder:
    ```bash
    mkdir -p field_evidence/<SESSION_UUID>
    cp path/to/<SESSION_UUID>.jsonl field_evidence/<SESSION_UUID>/
    cp path/to/<SESSION_UUID>.manifest.json field_evidence/<SESSION_UUID>/
    ```

### 5.3 Query Remote Supabase Data (Authenticated Read-back)
Obtain the JWT bearer token for your test user from the app session or Supabase test auth.
Fetch the exact persisted raw points using cURL:
```bash
SUPABASE_URL="<SUPABASE_URL_FROM_RUN_SH_OR_DASHBOARD>"
SUPABASE_ANON_KEY="<SUPABASE_ANON_KEY_FROM_RUN_SH_OR_DASHBOARD>"
USER_TOKEN="<YOUR_TEST_USER_BEARER_TOKEN>"
SESSION_UUID="<SESSION_UUID>"

curl -s -X GET "${SUPABASE_URL}/rest/v1/raw_gps_points?workout_id=eq.${SESSION_UUID}&select=*&order=timestamp.asc,latitude.asc,longitude.asc" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -H "Range-Unit: items" \
  -H "Range: 0-9999" > field_evidence/${SESSION_UUID}/supabase_${SESSION_UUID}.json
```

---

## 6. Automated Canonical Verification Tool

Aetron provides an automated CLI tool to verify physical evidence against cloud read-back without exposing coordinates:

```bash
dart run tooling/verify_field_evidence.dart \
  --journal field_evidence/<SESSION_UUID>/<SESSION_UUID>.jsonl \
  --manifest field_evidence/<SESSION_UUID>/<SESSION_UUID>.manifest.json \
  --supabase field_evidence/<SESSION_UUID>/supabase_<SESSION_UUID>.json \
  --device-model "iPhone 15 Pro" \
  --os-version "iOS 18.2" \
  --test-case "RG-F3-01" > field_evidence/<SESSION_UUID>/verification_report.json
```

### Verification Criteria
The tool strictly validates:
1. `raw_jsonl_file_sha256`: Computes raw byte SHA-256 of `.jsonl` and confirms match with `manifest.file_sha256`.
2. `canonical_capture_digest`: Parses local records into canonical lines (`v1|workout_id|timestamp|lat|lng|alt|speed|acc|head|src`) and confirms match with `manifest.canonical_capture_digest`.
3. `cloud_readback_digest`: Parses Supabase JSON rows into canonical lines and computes remote canonical digest.
4. **Digest Equality:** `canonical_capture_digest == cloud_readback_digest`.
5. **Count Equality:** `captured_sensor_points == cloud_rows_persisted`.
6. **Zero Missing / Duplicates:** `missing_cloud_points == 0` and `duplicate_cloud_points == 0`.

---

## 7. Submission Checklist for QA Review

When physical testing is complete, attach the sanitized verification report to the PR:
- [ ] Session ID (`<SESSION_UUID>`).
- [ ] Test Case ID (e.g. `RG-F3-01`).
- [ ] Device Model and OS Version.
- [ ] App Commit SHA.
- [ ] Sample Count equality verified.
- [ ] Raw JSONL SHA-256 verified against manifest.
- [ ] Local Canonical Digest matches Cloud Read-back Digest exactly.
- [ ] Output verification state is `CLOUD_VERIFIED`.
- [ ] No coordinates or secrets contained in submitted artifacts.
