# 생일알림 · saengil alrim

> A Flutter birthday alarm app — adds a friend's birthday once, rings with your chosen music when the day arrives, and waits politely until you unlock your phone before showing the alarm screen.

**Version:** 1.0.1+2 · **Platform:** Android 5.0+ (API 21+) · **Flutter:** 3.41+ / Dart 3.11+

---

## Table of Contents

1. [What This App Does](#1-what-this-app-does)
2. [Android Compatibility](#2-android-compatibility)
3. [Complete Flow](#3-complete-flow)
4. [Lock-Screen Behavior](#4-lock-screen-behavior)
5. [Cloud Sync](#5-cloud-sync)
6. [Permissions](#6-permissions)
7. [Audio File Handling](#7-audio-file-handling)
8. [Alarm Scheduling Logic](#8-alarm-scheduling-logic)
9. [File-by-File Breakdown](#9-file-by-file-breakdown)
10. [Dependencies](#10-dependencies)
11. [Getting Started](#11-getting-started)
12. [Fonts & Stickers](#12-fonts--stickers)

---

## 1. What This App Does

Add a friend's birthday once. The app remembers it and rings at the exact time you set — even if the app is closed, the screen is off, or the phone restarted.

**Two alarms per birthday:**

| Alarm | When it fires |
|---|---|
| **Birthday Alarm (D-Day)** | On the actual birthday at your chosen time |
| **Advance Reminder** | N days before the birthday (0–14 days, your choice) |

Each alarm has its own time, ringtone (any audio file from your device), and on/off toggle.

**When an alarm fires while you are using your phone**, a full-screen ring screen appears with the person's name, sticker, birthday message, and gift notes. Your music plays and loops until you tap **Stop Alarm**.

**When an alarm fires while your phone is locked**, the audio plays in the background. The ring screen appears the moment you unlock — nothing is missed and nothing interrupts your sleep.

---

## 2. Android Compatibility

| Android | API | Notes |
|---|---|---|
| 5.0 Lollipop | 21 | Minimum supported |
| 6.0 Marshmallow | 23 | Battery optimization dialog available |
| 7 / 8 | 24–27 | Full support |
| 9 Pie | 28 | Foreground service required |
| 10 | 29 | Full support |
| 11 / 12 / 12L | 30–32 | Exact alarm granted by default at install |
| 13 | 33 | `USE_EXACT_ALARM` auto-granted, `POST_NOTIFICATIONS` required at runtime |
| 14+ | 34+ | `FOREGROUND_SERVICE_MEDIA_PLAYBACK` required |

**OEM devices (Samsung, Xiaomi, Huawei, OnePlus, Oppo, Vivo, Realme):**
These manufacturers add proprietary battery managers that can kill background services even when battery optimization is disabled. On first launch the app requests standard battery optimization exemption. A persistent banner on the home screen also guides you to your device's specific autostart settings (MIUI Autostart, Samsung Battery, Huawei App Launch, etc.). Once you confirm that setting and dismiss the banner, it never shows again.

**Stock Android (Pixel, Android One):** Works without any extra steps.

---

## 3. Complete Flow

### 3.1 Adding a Birthday

```
Tap + → AddBirthdayScreen opens as a bottom sheet
         │
         ├─ Name (PlaywriteUSModern bold label)
         ├─ Birthday Date — month + day wheel picker
         ├─ Birth Year — optional, enables age display
         ├─ Card Colour — 6 pastel options
         ├─ Birthday Sticker — 28 built-in PNGs, or pick from gallery
         │                     Sticker is randomly assigned when importing
         │                     from cloud sync (no hardcoded 🎂 emoji)
         ├─ Birthday Alarm
         │   ├─ Toggle ON/OFF
         │   ├─ Pick alarm time
         │   └─ Pick ringtone (audio file from device)
         ├─ Advance Reminder
         │   ├─ Toggle ON/OFF
         │   ├─ Days before (1–14, slider)
         │   ├─ Pick reminder time
         │   └─ Pick ringtone
         └─ Gift Ideas & Notes (freeform text)
                  │
                  ▼
         BirthdayProvider.addBirthday()
                  │
         Audio files copied to internal storage
         (ensures they are always readable by the alarm service)
                  │
         Saved to SharedPreferences as JSON
                  │
         NotificationService.scheduleBirthdayAlarms()
         → Alarm.set() registers two exact alarms with Android AlarmManager
```

### 3.2 When an Alarm Fires (App Closed, Device Unlocked)

```
AlarmManager fires at scheduled time
        │
AlarmReceiver (BroadcastReceiver) starts AlarmService
        │
AlarmService (Foreground Service):
  · Acquires WAKE_LOCK
  · Plays audio from internal storage
  · Vibrates
  · Shows a notification
        │
Flutter's Alarm.ringing BehaviorSubject emits the alarm
        │
main.dart checks: is device locked?
        │
        NO → push AlarmRingScreen immediately
```

### 3.3 When an Alarm Fires While Device is Locked

```
AlarmManager fires
        │
AlarmService starts → audio plays in background (user hears it)
        │
main.dart checks: is device locked?
        │
        YES → alarm added to _pendingLockedAlarms queue
              (audio keeps playing, nothing shown on screen)
        │
User unlocks device → AppLifecycleState.resumed fires
        │
_onResumed() flushes the queue
        │
AlarmRingScreen pushed → user sees ring screen immediately after unlock
```

### 3.4 After Device Reboot

```
Phone restarts → BOOT_COMPLETED broadcast
        │
BootReceiver receives it
        │
All saved alarms re-registered with AlarmManager
        │
Nothing is lost
```

### 3.5 Stop Alarm

```
User taps Stop Alarm
        │
Alarm.stop(id) → audio stops, vibration stops
        │
NotificationService.scheduleBirthdayAlarmsAfter()
→ rolls that alarm to its next future occurrence
  (D-Day → next year; Advance → recalculated from next year's D-Day)
        │
Navigator.pop() → returns to normal app
```

---

## 4. Lock-Screen Behavior

This is the core design decision that separates this app from a typical alarm app.

**Why not show a full-screen UI over the lock screen?**

Most alarm apps use `FLAG_TURN_SCREEN_ON` + `FLAG_SHOW_WHEN_LOCKED` to forcibly wake and display over the keyguard. This is unreliable across the hundreds of Android OEM variants — PIN/pattern locks block interaction, Samsung One UI draws on top, and the behavior differs between API levels.

**What this app does instead:**

| Phase | What happens |
|---|---|
| Alarm fires, phone locked | Audio plays via foreground service. App detects locked state via `KeyguardManager.isKeyguardLocked`. Ring UI deferred. |
| User unlocks phone | `AppLifecycleState.resumed` fires. Deferred alarms flushed. Ring screen pushed. |
| Alarm fires, phone unlocked | Ring screen shown immediately as usual. |

The audio is the alert. The screen is the interaction. They are decoupled.

**Technical implementation:**

- `androidFullScreenIntent: false` in `AlarmSettings` — we do not ask the package to handle lock-screen presentation
- `showWhenLocked` / `turnScreenOn` attributes removed from `AndroidManifest.xml`
- `applyLockScreenFlags()` removed from `MainActivity.kt`
- New `isDeviceLocked` MethodChannel call in `MainActivity.kt` returns `KeyguardManager.isKeyguardLocked`
- `_pendingLockedAlarms` list in `main.dart` holds deferred alarms until resume

**Deduplication guard:**

Every alarm ID is added to `_handledAlarmIds` the moment it is first seen (before any `await`), preventing race conditions when the BehaviorSubject replays, the 1-second retry fires, or `_onResumed` flushes — all potentially running concurrently.

---

## 5. Cloud Sync

Birthdays can be backed up and shared between devices using Firebase Realtime Database.

### Data isolation

Every device gets a permanent random UUID generated once and stored in SharedPreferences as `cloud_user_id`. All cloud data lives at:

```
/birthdays/<userId>/
```

No two users ever share a node. Pushing from one device never affects another device's data.

### Push

Uploads the current device's birthdays to its own private cloud node. Replaces the node entirely with the current local state.

### Get (import from a friend)

1. Tap **Get** → enter a **Sync Code** (the other device's `cloud_user_id`)
2. The app fetches that user's node
3. Only entries not already on your device (by ID) are shown
4. You select which ones to import → they are added locally with randomly assigned stickers and colour index 0

### Your Sync Code

Shown on the Cloud Sync sheet. Tap **Copy** to share it with a friend. It is a UUID v4 string, e.g.:

```
3f4a12b8-9c2e-4d1f-a7b3-0e5f8d2c6a91
```

### What is synced

Only: `id`, `name`, `month`, `day`, `birthYear`, `notes`. Ringtone paths, sticker, colour, and alarm settings are device-local and are not uploaded.

---

## 6. Permissions

### Full list and why each is needed

| Permission | Why |
|---|---|
| `RECEIVE_BOOT_COMPLETED` | Re-register alarms after device restart |
| `VIBRATE` | Vibrate when alarm fires |
| `WAKE_LOCK` | Keep CPU awake while alarm service is running |
| `USE_FULL_SCREEN_INTENT` | Required to post the foreground notification (even though we don't show over lock screen) |
| `FOREGROUND_SERVICE` | Run AlarmService as a foreground service (API 28+) |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Required for `foregroundServiceType="mediaPlayback"` (API 34+) |
| `ACCESS_NOTIFICATION_POLICY` | Ring even in Do-Not-Disturb mode |
| `POST_NOTIFICATIONS` | Show any notification on Android 13+ |
| `USE_EXACT_ALARM` | Auto-granted on API 33+, exact timing |
| `SCHEDULE_EXACT_ALARM` | Exact timing on API 21–32 |
| `READ_EXTERNAL_STORAGE` (max API 32) | Read audio files on Android ≤ 12 |
| `READ_MEDIA_AUDIO` | Read audio files on Android 13+ |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ask user to whitelist app from battery killer |
| `INTERNET` | Cloud sync via Firebase REST API |
| `ACCESS_NETWORK_STATE` | Check connectivity before sync |

### Exact alarm — two permissions, one goal

```
SCHEDULE_EXACT_ALARM  →  API 21–32  granted by default, user can revoke
USE_EXACT_ALARM       →  API 33+    auto-granted at install
```

Both declared so the alarm fires exactly on time on every Android version.

### OEM battery management

Standard battery optimization exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) is not enough on Samsung, Xiaomi, Huawei, Oppo, Vivo, OnePlus, and Realme. These OEMs have additional proprietary managers.

The home screen shows a persistent yellow banner on these devices. Tapping it opens:

| OEM | Screen opened |
|---|---|
| Xiaomi / MIUI | AutoStart Management |
| Huawei / Honor | App Launch Manager |
| Samsung | Battery → Background usage limits |
| Oppo / Realme | Startup Manager |
| Vivo | Background App Refresh |
| OnePlus | Battery Optimization |
| Others | Standard battery optimization settings |

Once you complete the step, tap **×** on the banner. The dismissal is persisted in SharedPreferences (`oem_battery_banner_dismissed = true`) and the banner never shows again.

---

## 7. Audio File Handling

### The problem

`file_picker` returns absolute external paths like:
```
/storage/emulated/0/Music/Happy Birthday.mp3
```

These paths are readable while the app is open. When the app is closed, Android's scoped storage may revoke access. The `AlarmService` (a separate native process) cannot reliably read `/storage/emulated/0/...` paths.

### The solution — copy to internal storage

When a birthday is saved, `_resolveRingtonePaths()` runs:

1. Detects if path starts with `/` (external absolute path)
2. Copies the file to `<app documents>/alarm_audio/dday_<id>.mp3`
3. Stores the **relative path** `alarm_audio/dday_<id>.mp3` in the model

The alarm package's native audio code resolves relative paths from the app's internal documents directory — always accessible by the app's own processes regardless of lock state or scoped storage.

Copied files persist across restarts, reboots, and app updates.

---

## 8. Alarm Scheduling Logic

### ID generation

```dart
dDayId(friendId)   = (friendId.hashCode.abs() % 1_000_000) * 2 + 2  // even
advanceId(friendId) = (friendId.hashCode.abs() % 1_000_000) * 2 + 3  // odd
```

Even IDs = D-Day alarms. Odd IDs = advance reminders. IDs are stable — editing a birthday reschedules the same IDs.

### Next occurrence

`_nextOccurrence()` picks the next future date for a given month/day/time:

- If the date this year is still in the future → schedules this year
- If the date has already passed this year → schedules next year
- Handles February 29 in non-leap years by clamping to Feb 28

### Post-dismissal reschedule

When the user taps Stop Alarm:

- **D-Day alarm dismissed:** both alarms roll to next year's birthday
- **Advance alarm dismissed:** advance rolls to next year's birthday minus N days; D-Day stays this year if it hasn't fired yet
- **Both:** handled by `scheduleBirthdayAlarmsAfter(firedAlarmId:)` passing the dismissed alarm's ID to determine which path to take

---

## 9. File-by-File Breakdown

```
lib/
├── main.dart
│   • Calls NotificationService().init() → Alarm.init() before runApp
│   • MyApp is StatefulWidget + WidgetsBindingObserver
│   • Listens to Alarm.ringing BehaviorSubject
│   • _handleAlarm(): synchronously claims alarm ID, checks lock state
│   • _pendingLockedAlarms: queue for alarms deferred while locked
│   • _onResumed(): flushes queue, re-checks stream, handles tap payload
│   • _showAlarmScreen(): pushes AlarmRingScreen via global NavigatorKey
│   • _waitForNavigator(): polls up to 6 s for navigator on cold launch
│
├── screens/
│   ├── home_screen.dart
│   │   • Permission banners: notifications, battery, exact alarm, OEM
│   │   • OEM banner has separate tap (opens settings) and × (dismiss, persisted)
│   │   • Re-checks permissions on didChangeAppLifecycleState.resumed
│   │   • Calendar + birthday lists (today's date, this month + next month)
│   │
│   ├── add_birthday_screen.dart
│   │   • Section labels use PlaywriteUSModern 20px w800 (no icons)
│   │   • Month/day wheel picker, birth year field
│   │   • Sticker grid (28 built-in), gallery photo option
│   │   • Alarm section with animated tree-branch expand/collapse UI
│   │   • Last-used alarm settings pre-filled for new entries
│   │
│   ├── birthday_detail_screen.dart
│   │   • Full profile: sticker, name, countdown, notes, alarm summary
│   │   • Edit and delete actions
│   │
│   ├── alarm_ring_screen.dart
│   │   • Live clock (updates every second)
│   │   • Pulsing avatar + two expanding ring waves
│   │   • 60 confetti particles (continuous)
│   │   • Birthday vs reminder badge, name, message, notes
│   │   • Stop Alarm → Alarm.stop() + reschedule + pop
│   │   • SystemUiMode.edgeToEdge (not immersiveSticky, safer on OEM lock screens)
│   │
│   ├── saved_birthdays_screen.dart
│   │   • Scrollable list of all saved birthdays
│   │   • Tap → birthday_detail_screen
│   │
│   └── cloud_sync_sheet.dart
│       • Shows this device's sync code with one-tap copy
│       • Push: uploads to /birthdays/<userId>/
│       • Get: prompts for friend's sync code, fetches their node,
│              shows only entries not already on device
│       • Imported entries get a randomly assigned sticker
│
├── services/
│   ├── birthday_service.dart
│   │   • FriendBirthday model (immutable, copyWith, toJson, fromJson)
│   │   • kAllStickers: single source of truth for all sticker paths
│   │   • randomSticker(): used as fallback when importing from cloud
│   │   • BirthdayProvider (ChangeNotifier): load/save/add/update/delete
│   │   • _resolveRingtonePaths(): copies external audio to internal storage
│   │
│   ├── notification_service.dart
│   │   • scheduleBirthdayAlarms() / scheduleBirthdayAlarmsAfter()
│   │   • Alarm.set() with androidFullScreenIntent: false
│   │   • androidStopAlarmOnTermination: false (keeps ringing after app swipe)
│   │   • loopAudio: true, vibrate: true, VolumeSettings.fade(10s)
│   │   • cancelBirthdayAlarms(): Alarm.stop() for both IDs
│   │
│   ├── permission_service.dart
│   │   • hasNotificationPermission / requestNotificationPermission
│   │   • hasExactAlarmPermission / requestExactAlarmPermission
│   │   • isIgnoringBatteryOptimizations / requestIgnoreBatteryOptimizations
│   │   • needsOemBatterySettings(): true for known OEM brands
│   │   • oemBatterySettingsLabel(): device-specific label string
│   │   • openOemBatterySettings(): deep-links to OEM settings screen
│   │   • dismissOemBanner(): persists dismissal in SharedPreferences
│   │   • checkAll(): returns List<MissingPermission>
│   │
│   ├── cloud_service.dart
│   │   • getUserId(): persistent UUID from SharedPreferences
│   │   • pushToCloud(): PUT to /birthdays/<userId>/
│   │   • fetchFromUser(syncCode): GET from /birthdays/<syncCode>/
│   │   • Syncs only: id, name, month, day, birthYear, notes
│   │
│   └── update_service.dart
│       • Checks for APK updates via HTTP
│
└── widgets/
    ├── app_styles.dart       Colors, TextStyles, BoxDecorations, font names
    ├── birthday_card.dart    Card widget used in home screen lists
    ├── cute_sticker.dart     Renders asset or file path sticker image
    ├── funky_calendar.dart   Monthly calendar with birthday dot indicators
    └── ...

android/app/src/main/
├── AndroidManifest.xml       All permissions, service, receiver declarations
│                             No showWhenLocked / turnScreenOn on activity
└── kotlin/.../MainActivity.kt
    • MethodChannel: com.example.saengil_alrim/battery
    • isDeviceLocked → KeyguardManager.isKeyguardLocked
    • isIgnoringBatteryOptimizations, requestIgnoreBatteryOptimizations
    • canScheduleExactAlarms, openExactAlarmSettings
    • hasNotificationPermission, requestNotificationPermission
    • getManufacturer → Build.MANUFACTURER.lowercase()
    • openOemBatterySettings → per-OEM intent with fallback
    • getNotificationLaunchPayload → payload from notification tap intent
```

---

## 10. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `alarm` | ^5.4.1 | Core: exact alarm, foreground service, audio playback |
| `provider` | ^6.1.2 | State management (`BirthdayProvider`) |
| `shared_preferences` | ^2.2.3 | Persist birthday JSON + user settings |
| `file_picker` | ^8.1.4 | Pick audio ringtone from device |
| `image_picker` | ^1.1.2 | Pick sticker photo from gallery |
| `path_provider` | ^2.1.5 | App documents directory for audio copying |
| `http` | ^1.2.2 | Firebase REST API calls for cloud sync |
| `intl` | ^0.20.2 | Date formatting |
| `audioplayers` | ^6.1.0 | Audio preview in settings (alarm package handles actual alarm audio natively) |
| `package_info_plus` | ^8.3.0 | App version for update check |
| `url_launcher` | ^6.3.1 | Open browser for APK download |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## 11. Getting Started

### Requirements

- Flutter 3.41+ / Dart 3.11+
- Android device or emulator (API 21+)

### Run

```bash
flutter pub get
flutter run
```

### First-launch checklist

1. **Battery optimization** — system dialog appears on first open → tap **Allow**
2. **OEM autostart** — if a yellow banner appears, tap it → enable the setting → tap **×** to dismiss
3. **Add a birthday** → pick a ringtone → set alarm time a few minutes away for testing
4. Swipe the app away from recents
5. Wait — audio should play at the scheduled time. Unlock your phone → ring screen appears

### Build release APK

```bash
flutter build apk --release
```

---

## 12. Fonts & Stickers

### Fonts

| Family | Used for |
|---|---|
| **Comfortaa** | All body text, labels, buttons, captions |
| **PlaywriteUSModern** | Section headings in add/edit form, alarm screen name display |
| **GloriaHallelujah** | App title, date labels |

### Stickers

28 PNG stickers bundled in `assets/sticker/`. Defined in `kAllStickers` in `birthday_service.dart` — the single source of truth used by both the picker UI and the random-assignment fallback for cloud imports.

**Cakes:** birthday-cake, birthday-cake_1, cake, cake_1, cake_2, cake_3, cupcake, pie

**Animals:** cat, chick, koala, penguin, monkey, mouse, elephant, giraffe, crocodile, dinosaur, dinosaur_1, stegosaurus, crow, jellyfish

**Nature & Objects:** flower, flower-pot, tulips, magic, drawing, glasses

You can also use any photo from your gallery as a custom sticker.

---

*Made with 💖 — never forget a birthday again.*
