# 생일알림 · saengil alrim

> A Flutter birthday alarm app that wakes your phone with full-screen UI and plays your chosen music — even when the app is completely closed.

---

## Table of Contents

1. [What This App Does](#1-what-this-app-does)
2. [Android Compatibility](#2-android-compatibility)
3. [How the App Works — Complete Flow](#3-how-the-app-works--complete-flow)
4. [Every Change Made and Why](#4-every-change-made-and-why)
5. [File-by-File Breakdown](#5-file-by-file-breakdown)
6. [Permissions Explained](#6-permissions-explained)
7. [Audio File Handling](#7-audio-file-handling)
8. [Alarm Screen UI](#8-alarm-screen-ui)
9. [Project Structure](#9-project-structure)
10. [Dependencies](#10-dependencies)
11. [Getting Started](#11-getting-started)

---

## 1. What This App Does

You add a friend's birthday once. The app remembers it forever and wakes your phone at the right time — even if the app is closed, the screen is off, or the phone was restarted.

**Two alarms per birthday:**

- **Birthday Alarm (D-Day)** — fires on the actual birthday at your chosen time
- **Advance Reminder** — fires N days before the birthday (you pick 0–14 days)

Each alarm has its own:
- Time of day
- Ringtone (any audio file from your device)
- On/Off toggle

When an alarm fires, a **full-screen alarm UI** appears over the lock screen showing the person's name, sticker, birthday message, and gift notes. Your chosen music plays and loops until you tap **Stop Alarm**.

---

## 2. Android Compatibility

| Android Version | API Level | Works? | Notes |
|---|---|---|---|
| Android 5.0 Lollipop | 21 | ✅ | Minimum supported version |
| Android 6.0 Marshmallow | 23 | ✅ | Battery optimization dialog available |
| Android 7 / 8 | 24–27 | ✅ | Full support |
| Android 9 Pie | 28 | ✅ | Foreground service permission required |
| Android 10 | 29 | ✅ | Full-screen intent available |
| Android 11 | 30 | ✅ | Full support |
| Android 12 / 12L | 31–32 | ✅ | Exact alarm granted by default at install |
| Android 13 | 33 | ✅ | `USE_EXACT_ALARM` auto-granted, `POST_NOTIFICATIONS` required |
| Android 14 | 34 | ✅ | `FOREGROUND_SERVICE_MEDIA_PLAYBACK` required |
| Android 15+ | 35+ | ✅ | Tested with Flutter 3.41 / targetSdk 35 |

**OEM devices (Samsung, Xiaomi, Huawei, OnePlus, Oppo, Vivo):**
These brands add their own battery killers on top of Android. The app asks for battery optimization exemption on first launch. Without it, the alarm service may be killed before it rings on these devices. Once granted, it works reliably.

**Stock Android (Google Pixel, Android One):**
Works without any extra steps.

---

## 3. How the App Works — Complete Flow

### 3.1 Adding a Birthday

```
User opens app → taps + button
        ↓
AddBirthdayScreen opens as a bottom sheet
        ↓
User fills in:
  • Name
  • Birthday date (month + day wheel picker)
  • Birth year (optional, for age calculation)
  • Sticker (28 built-in or pick from gallery)
  • Card colour (6 pastel options)
  • Birthday Alarm → toggle ON/OFF → pick time → pick ringtone
  • Advance Reminder → toggle ON/OFF → pick days before → pick time → pick ringtone
  • Gift ideas / notes
        ↓
User taps Save Birthday
        ↓
BirthdayProvider.addBirthday() is called
        ↓
Audio files are COPIED to internal storage
(so they're always readable even when app is closed)
        ↓
Birthday is saved to SharedPreferences as JSON
        ↓
NotificationService.scheduleBirthdayAlarms() is called
        ↓
Alarm.set() registers two exact alarms with Android's AlarmManager
        ↓
Done — alarms are now scheduled at the OS level
```

### 3.2 What Happens When the Alarm Fires (App Closed)

```
Phone reaches the scheduled date and time
        ↓
Android's AlarmManager fires — no app process needed
        ↓
AlarmReceiver (BroadcastReceiver) receives the broadcast
        ↓
AlarmReceiver starts AlarmService as a Foreground Service
        ↓
AlarmService:
  • Acquires a WAKE_LOCK (keeps CPU awake)
  • Requests audio focus
  • Plays the audio file from internal storage
  • Starts vibration
  • Shows a full-screen notification over the lock screen
  • Calls back into Flutter via platform channel
        ↓
Flutter's Alarm.ringing stream emits the alarm
        ↓
main.dart listener receives it
        ↓
Reads the birthday from SharedPreferences using the alarm payload (birthday ID)
        ↓
Pushes AlarmRingScreen via the global NavigatorKey
        ↓
Full-screen alarm UI appears with:
  • Live clock
  • Person's sticker (pulsing animation)
  • Expanding ring waves
  • Confetti particles
  • Name, birthday message, gift notes
  • Stop Alarm button
        ↓
User taps Stop Alarm
        ↓
Alarm.stop() is called → audio stops, vibration stops, screen returns to normal
```

### 3.3 After Device Reboot

```
Phone restarts
        ↓
Android sends BOOT_COMPLETED broadcast
        ↓
BootReceiver receives it
        ↓
Reads all saved alarms from AlarmStorage
        ↓
Re-registers each alarm with AlarmManager
        ↓
All alarms are restored — nothing is lost
```

### 3.4 App Launch — Reschedule on Every Open

```
App opens → main() runs
        ↓
NotificationService.init() → Alarm.init()
        ↓
Alarm.init() calls checkAlarm() internally
        ↓
BirthdayProvider loads all birthdays from SharedPreferences
        ↓
_rescheduleAllAlarms() loops through every birthday
        ↓
scheduleBirthdayAlarms() is called for each one
        ↓
Any alarm whose time has passed is automatically rolled to next year
```

---

## 4. Every Change Made and Why

### 4.1 The Original Problem

The original app had the `alarm` package installed but **never used it**. All scheduling went through `flutter_local_notifications.zonedSchedule()` which only shows a banner notification — it cannot wake the device, play a custom file, or show a full-screen UI. The user-picked ringtone path was saved but never passed to any audio API.

---

### 4.2 `AndroidManifest.xml` — Complete Rewrite

**Before:** Only had basic activity declaration. Wrong service class name (`dev.fluttercommunity.plus.androidalarm.AlarmService` — this class does not exist). Missing `AlarmReceiver`, `BootReceiver`, and most permissions.

**After — every addition explained:**

| Addition | Why |
|---|---|
| `RECEIVE_BOOT_COMPLETED` | Without this, all alarms are lost after reboot |
| `WAKE_LOCK` | Keeps CPU awake while alarm is ringing |
| `USE_FULL_SCREEN_INTENT` | Shows alarm UI over the lock screen |
| `FOREGROUND_SERVICE` | Required to run AlarmService in foreground (API 28+) |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Required for `foregroundServiceType="mediaPlayback"` (API 34+) |
| `ACCESS_NOTIFICATION_POLICY` | Allows alarm to ring even in Do-Not-Disturb mode |
| `POST_NOTIFICATIONS` | Required to show any notification on Android 13+ |
| `USE_EXACT_ALARM` | Auto-granted on API 33+, no user prompt needed |
| `SCHEDULE_EXACT_ALARM` | Covers API 21–32 for exact timing |
| `READ_EXTERNAL_STORAGE` (maxSdkVersion=32) | Read audio files on Android ≤ 12 |
| `READ_MEDIA_AUDIO` | Read audio files on Android 13+ |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ask user to whitelist app from battery killer |
| `AlarmService` with correct class name | The actual class is `com.gdelataillade.alarm.alarm.AlarmService` |
| `AlarmService` with `stopWithTask="false"` | Keeps service alive when app is swiped away |
| `AlarmReceiver` | BroadcastReceiver that fires when AlarmManager triggers |
| `BootReceiver` with `BOOT_COMPLETED` + `QUICKBOOT_POWERON` | Reschedules after reboot; `QUICKBOOT_POWERON` covers HTC/Huawei fast-boot |
| `showWhenLocked="true"` on Activity | Allows alarm screen to appear over lock screen |
| `turnScreenOn="true"` on Activity | Wakes the screen when alarm fires |

---

### 4.3 `MainActivity.kt` — Rewritten from Scratch

**Before:** Was just `class MainActivity : FlutterActivity()` — one line, nothing else.

**After:** Added a `MethodChannel` named `com.example.saengil_alrim/battery` that handles 4 calls from Flutter:

| Method | What it does |
|---|---|
| `isIgnoringBatteryOptimizations` | Checks if app is exempt from battery optimization using `PowerManager` |
| `requestIgnoreBatteryOptimizations` | Opens the system dialog asking user to exempt the app |
| `canScheduleExactAlarms` | Checks `AlarmManager.canScheduleExactAlarms()` (API 31+) |
| `openExactAlarmSettings` | Opens `Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM` |

Also added `onCreate` override that **automatically requests battery optimization exemption on first launch** — this is the most important step for OEM devices.

---

### 4.4 `notification_service.dart` — Complete Rewrite

**Before:** Used `flutter_local_notifications.zonedSchedule()`. The user's ringtone path was ignored. The `alarm` package was initialized but `Alarm.set()` was never called.

**After — key changes:**

- **Uses `Alarm.set()` with `AlarmSettings`** — this is what actually schedules a real alarm
- **`androidStopAlarmOnTermination: false`** — the single most critical setting. Without this, swiping the app away from recents stops the alarm. With it, the alarm keeps ringing.
- **`androidFullScreenIntent: true`** — wakes the screen and shows full-screen UI
- **`loopAudio: true`** — music loops until user stops it
- **`vibrate: true`** — vibrates alongside the audio
- **`VolumeSettings.fade(fadeDuration: 10s)`** — volume fades in over 10 seconds like a real alarm
- **`payload: birthday.id`** — stores the birthday ID so the ring screen knows whose birthday it is
- **Stable alarm IDs** — D-Day uses even numbers, advance uses odd numbers, both derived from the birthday ID hash
- **`_nextOccurrence()`** — correctly rolls to next year if the date has already passed; handles Feb 29 in non-leap years

---

### 4.5 `birthday_service.dart` — Audio Path Resolution Added

**Before:** `addBirthday()` and `updateBirthday()` saved the raw file path from `file_picker` (e.g. `/storage/emulated/0/Music/song.mp3`) and passed it directly to the alarm.

**Problem:** When the app is closed, Android's scoped storage may revoke access to external paths. The alarm service (a separate native process) cannot read `/storage/emulated/0/...` paths reliably.

**After:** Before saving, `_resolveRingtonePaths()` is called which:
1. Detects if the path is an external absolute path (starts with `/`)
2. Copies the file to `<app documents>/alarm_audio/dday_<id>.mp3`
3. Saves the **relative path** (`alarm_audio/dday_<id>.mp3`) instead
4. The alarm package resolves relative paths from the app's documents directory — always accessible

---

### 4.6 `main.dart` — Alarm Stream Wiring

**Before:** `MyApp` was a `StatelessWidget`. No alarm stream listener existed. Even if an alarm fired, nothing would navigate to a ring screen.

**After:**
- `MyApp` is now a `StatefulWidget`
- Listens to `Alarm.ringing` stream (the modern API from alarm 5.4.1)
- When an alarm fires, reads the birthday from SharedPreferences using `alarmSettings.payload` (the birthday ID)
- Pushes `AlarmRingScreen` via a global `NavigatorKey` — this works even when the app was launched by the alarm (not by the user)
- `StreamSubscription` is properly cancelled in `dispose()`

---

### 4.7 `alarm_ring_screen.dart` — Created from Scratch

**Before:** Did not exist.

**After:** A full-screen alarm UI with:
- Live clock updating every second
- Pulsing avatar circle with the person's sticker
- Two expanding ring-wave animations
- 60 confetti particles falling continuously
- Alarm type badge (Birthday Alarm vs Reminder)
- Person's name in handwriting font
- Contextual message ("It's X's birthday today!" or "X's birthday is in N days!")
- Gift notes preview (if any)
- **Stop Alarm** button — calls `Alarm.stop()` and pops the screen
- Forces portrait orientation while open
- Uses `SystemUiMode.immersiveSticky` (hides status/nav bars)
- Background: very light gradient tinted with the person's card colour

---

### 4.8 `permission_service.dart` — Created from Scratch

**Before:** Did not exist. No permission checking anywhere.

**After:** A singleton service that checks two things:
1. **Exact alarm permission** — calls `canScheduleExactAlarms` via MethodChannel
2. **Battery optimization exemption** — calls `isIgnoringBatteryOptimizations` via MethodChannel

Returns a list of `MissingPermission` enum values. Used by `HomeScreen` to show banners.

---

### 4.9 `home_screen.dart` — Permission Banners Added

**Before:** `StatelessWidget`, no permission awareness.

**After:**
- Converted to `StatefulWidget` with `WidgetsBindingObserver`
- Checks permissions after first frame renders
- Re-checks when user returns from Settings (via `didChangeAppLifecycleState`)
- Shows orange banner if battery optimization is not granted
- Shows red banner if exact alarm permission is missing
- Each banner is tappable — opens the relevant system settings page directly

---

### 4.10 Snooze Removed

The snooze button was removed from `AlarmRingScreen`. Only the **Stop Alarm** button remains. This was a deliberate design decision — birthday alarms should be acknowledged, not postponed.

---

## 5. File-by-File Breakdown

```
lib/
│
├── main.dart
│   • App entry point
│   • Calls NotificationService().init() → Alarm.init()
│   • MyApp is StatefulWidget — listens to Alarm.ringing stream
│   • When alarm fires: reads birthday from SharedPreferences,
│     pushes AlarmRingScreen via global NavigatorKey
│
├── screens/
│   │
│   ├── home_screen.dart
│   │   • Main screen with calendar and birthday lists
│   │   • Checks permissions on load and when returning from Settings
│   │   • Shows orange/red banners for missing permissions
│   │   • FAB opens AddBirthdayScreen as a bottom sheet
│   │
│   ├── add_birthday_screen.dart
│   │   • Full add/edit form for a birthday
│   │   • Month/day wheel picker, year field, sticker grid, colour picker
│   │   • Alarm section with animated tree-branch UI
│   │   • Ringtone picker using file_picker (audio files only)
│   │   • Requires ringtone to be selected before saving
│   │
│   ├── birthday_detail_screen.dart
│   │   • Friend profile sheet showing all birthday details
│   │   • Live countdown to next alarm
│   │   • Inline notes editing
│   │   • Edit and delete buttons
│   │
│   └── alarm_ring_screen.dart
│       • Full-screen alarm UI
│       • Pulsing avatar, ring waves, confetti, live clock
│       • Stop Alarm button → Alarm.stop() + Navigator.pop()
│       • Forces portrait, immersive mode
│       • Light gradient background tinted with person's card colour
│
├── services/
│   │
│   ├── birthday_service.dart
│   │   • FriendBirthday model (immutable, with copyWith)
│   │   • JSON serialization/deserialization
│   │   • BirthdayProvider (ChangeNotifier)
│   │   • Loads/saves to SharedPreferences
│   │   • _resolveRingtonePaths() — copies audio to internal storage
│   │   • _copyAudioToInternal() — copies file, returns relative path
│   │   • Calls NotificationService on add/update/delete
│   │
│   ├── notification_service.dart
│   │   • Singleton
│   │   • init() → Alarm.init()
│   │   • scheduleBirthdayAlarms() → Alarm.set() for D-Day and advance
│   │   • cancelBirthdayAlarms() → Alarm.stop() for both IDs
│   │   • _nextOccurrence() — rolls to next year if date passed
│   │   • _validatePath() — checks path is usable
│   │   • Stable ID generation from birthday ID hash
│   │
│   └── permission_service.dart
│       • Singleton
│       • hasExactAlarmPermission() via MethodChannel
│       • requestExactAlarmPermission() → opens Settings
│       • isIgnoringBatteryOptimizations() via MethodChannel
│       • requestIgnoreBatteryOptimizations() → opens system dialog
│       • checkAll() → returns List<MissingPermission>
│
└── widgets/
    ├── app_styles.dart      — Colors, TextStyles, BoxDecorations, font names
    ├── birthday_card.dart   — Card widget used in home screen lists
    ├── cute_sticker.dart    — Renders asset path or file path sticker image
    ├── funky_calendar.dart  — Monthly calendar with birthday dot indicators
    ├── confetti_particles.dart — Confetti overlay widget
    └── custom_button.dart   — Reusable styled button

android/app/src/main/
├── AndroidManifest.xml      — All permissions + service/receiver declarations
└── kotlin/.../MainActivity.kt — MethodChannel for battery + exact alarm
```

---

## 6. Permissions Explained

### Why two exact alarm permissions?

```
SCHEDULE_EXACT_ALARM  →  API 21 to 32  (Android 5 to 12)
                          Granted by default on install.
                          User can revoke in Settings.

USE_EXACT_ALARM       →  API 33+  (Android 13+)
                          Auto-granted at install, no user prompt.
                          Restricted to alarm/calendar apps on Play Store.

We declare BOTH so the alarm fires exactly on time on every Android version.
```

### Why battery optimization matters so much

Normal Android: when you swipe an app away, its background processes stop. That's fine for most apps.

For alarm apps: the `AlarmService` is a **Foreground Service** — it's supposed to keep running. But Samsung, Xiaomi, Huawei, and others have their own battery management layers that kill foreground services anyway.

The `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission lets us ask the user to whitelist the app. Once whitelisted, the OS treats it like a system app and won't kill it.

**The app asks for this automatically on first launch.** If the user denies it, a banner appears on the home screen with a direct link to fix it.

---

## 7. Audio File Handling

### The problem with external file paths

When you pick a song using `file_picker`, you get a path like:
```
/storage/emulated/0/Music/Happy Birthday.mp3
```

This works while the app is open. But when the app is closed:
- Android's scoped storage may revoke read access to external paths
- The `AlarmService` runs as a separate native process and cannot use Flutter's file access context
- The path may simply not be readable

### The solution — copy to internal storage

When you save a birthday, the app:

1. Detects the path starts with `/` (external absolute path)
2. Copies the file to:
   ```
   <app documents>/alarm_audio/dday_<birthdayId>.mp3
   ```
3. Saves the **relative path** `alarm_audio/dday_<birthdayId>.mp3` in the model
4. This relative path is what gets passed to `Alarm.set(assetAudioPath: ...)`

The alarm package's native `AudioService.kt` resolves relative paths from `context.filesDir.parent/app_flutter/` — this directory is always accessible to the app's own processes, even when the app is closed.

The copied file persists across app restarts, device reboots, and app updates.

---

## 8. Alarm Screen UI

### Background opacity

Controlled in `_buildBackground()` in `alarm_ring_screen.dart`:

```dart
colors: [
  themeColor.withValues(alpha: 0.40),   // top — person's card colour at 40%
  themeColor.withValues(alpha: 0.86),   // middle at 86%
  Colors.white.withValues(alpha: 0.60), // bottom — white wash at 60%
],
```

`alpha` goes from `0.0` (fully transparent) to `1.0` (fully opaque). The `themeColor` is the pastel card colour you chose for that person when adding their birthday.

### Animations

| Animation | What it does |
|---|---|
| Pulse | Avatar circle scales between 1.0× and 1.12× every 900ms |
| Ring waves | Two expanding circles fade out as they grow, offset by 0.5 phase |
| Fade-in | Whole screen fades in over 600ms when alarm opens |
| Confetti | 60 particles (circles and rectangles) fall continuously, respawn at top |
| Clock | Updates every second via `Timer.periodic` |

---

## 9. Project Structure

```
saengil_alrim/
├── lib/                          Flutter source code
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml   Permissions + components
│       └── kotlin/.../
│           └── MainActivity.kt   Native permission handling
├── assets/
│   ├── icon/                     App icon + add button icon
│   ├── sticker/                  28 PNG sticker images
│   └── fonts/                    Comfortaa, GloriaHallelujah, PlaywriteUSModern
├── pubspec.yaml                  Dependencies + asset declarations
└── README.md                     This file
```

---

## 10. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `alarm` | ^5.4.1 | Core alarm scheduling, foreground service, audio playback, full-screen intent |
| `provider` | ^6.1.2 | State management (`BirthdayProvider`) |
| `shared_preferences` | ^2.2.3 | Persist birthday data as JSON |
| `file_picker` | ^8.1.4 | Pick audio ringtone from device storage |
| `image_picker` | ^1.1.2 | Pick sticker photo from gallery |
| `path_provider` | ^2.1.5 | Get app documents directory for audio file copying |
| `flutter_local_notifications` | ^21.0.0 | Kept as dependency (used by alarm package internally) |
| `timezone` | ^0.11.0 | Timezone-aware date handling |
| `flutter_timezone` | ^5.1.0 | Get device's local timezone |
| `intl` | ^0.20.2 | Date formatting |
| `audioplayers` | ^6.1.0 | Declared but audio is handled natively by alarm package |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## 11. Getting Started

### Requirements

- Flutter 3.41+ / Dart 3.11+
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+, Android 5.0+)

### Run

```bash
git clone https://github.com/yourusername/saengil_alrim.git
cd saengil_alrim
flutter pub get
flutter run
```

### First launch checklist

1. App opens → system dialog appears asking to allow background activity → tap **Allow**
2. Add a birthday → pick a ringtone from your device
3. Set the alarm time to a few minutes from now for testing
4. Swipe the app away from recents
5. Lock your phone
6. Wait — the alarm screen should appear over the lock screen with your music playing

### Build release APK

```bash
flutter build apk --release
```

---

## Fonts

| Family | Weights | Used for |
|---|---|---|
| Comfortaa | 300, 400, 500, 600, 700 | All body text, labels, buttons |
| GloriaHallelujah | 400 | Accent text |
| Playwrite US Modern | 100, 200, 300, 400 | Titles, headings, alarm screen name |

---

## Stickers

28 PNG stickers in `assets/sticker/`:

**Cakes:** birthday-cake, birthday-cake_1, cake, cake_1, cake_2, cake_3, cupcake, pie

**Animals:** cat, chick, koala, penguin, monkey, mouse, elephant, giraffe, crocodile, dinosaur, dinosaur_1, stegosaurus, crow, jellyfish

**Nature & Objects:** flower, flower-pot, tulips, magic, drawing, glasses

You can also use any photo from your gallery as a sticker.

---

## License

MIT — see [LICENSE](LICENSE).

---

*Made with 💖 — never forget a birthday again.*
