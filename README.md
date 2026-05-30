# saengil_alrim

A delightful Flutter birthday reminder app with task management, cute stickers, and notifications.

## Features

- 🎂 **Birthday Management**: Add, edit, delete friends' birthdays with details like name, birth year, notes, and sticker.
- ✅ **Task Lists**: For each birthday, create a checklist of tasks (e.g., order cake, buy gifts) and mark them as completed.
- 📅 **Calendar View**: Select a date to see birthdays falling on that day.
- ⏰ **Notifications**: Schedule local notifications for upcoming birthdays (configurable advance alerts).
- 🎨 **Cute & Customizable UI**: Uses bubbly fonts (Comfortaa, GloriaHallelujah, PlaywriteUSModern) and pastel color scheme.
- 🖼️ **Sticker Support**: Attach fun sticker images (cakes, animals, objects) to birthdays for visual flair.
- 💾 **Data Persistence**: Birthdays and tasks are saved locally via SharedPreferences.
- 🔄 **Mock Data**: On first launch, the app loads adorable Korean-style sample birthdays to demo the UI.

## Assets

The app includes the following assets defined in `pubspec.yaml`:

### Fonts
- **Comfortaa** (Regular, Light, Medium, SemiBold, Bold)
- **GloriaHallelujah** (Regular)
- **Playwrite US Modern** (ExtraLight, Light, Regular, Thin)

### Images
- **App Icon**: `assets/icon/saengil_alrim_logo.png`
- **Stickers**: A collection of PNG images in `assets/sticker/` including:
  - Birthday cakes (`birthday-cake.png`, `cake.png`, `cupcake.png`, etc.)
  - Animals (`cat.png`, `chick.png`, `crocodile.png`, `koala.png`, `monkey.png`, `penguin.png`, `tulips.png`, etc.)
  - Objects (`glasses.png`, `flower.png`, `flower-pot.png`, `magic.png`, `pie.png`, etc.)
  - Characters (`dinosaur.png`, `elephant.png`, `giraffe.png`, `jellyfish.png`, `stegosaurus.png`, etc.)

These assets are used throughout the UI for avatars, decorations, and visual appeal.

## Getting Started

This project is a Flutter application.

### Prerequisites
- Flutter SDK (>=3.11.5)
- Dart SDK
- Android Studio / Xcode / VS Code with Flutter extensions
- A physical device or emulator/simulator

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/saengil_alrim.git
   ```
2. Navigate to the project directory:
   ```bash
   cd saengil_alrim
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Platform Support
- Android (minSdk 21)
- iOS (not configured in this template)
- Web, Windows, macOS, Linux (not tested)

## Project Structure

```
lib/
├── main.dart              # App entry point
├── providers/
│   └── birthday_provider.dart   # State management with Provider
├── models/
│   ├── birthday_task.dart       # Task model
│   └── friend_birthday.dart     # Birthday model
├── services/
│   └── notification_service.dart # Local notification handling
├── views/
│   └── home_view.dart         # Main UI (calendar, list, etc.)
├── utils/
│   ├── styles.dart            # Theme colors and typography
│   └── ...                    # Other utility files
```

## How It Works

1. **State Management**: Uses `Provider` with `ChangeNotifier` (`BirthdayProvider`) to manage the list of birthdays and tasks.
2. **Data Persistence**: Birthdays are serialized to JSON and stored in `SharedPreferences`.
3. **Notifications**: Utilizes `flutter_local_notifications` and `timezone` packages to schedule alerts for birthdays.
4. **UI**: Built with Material 3, featuring a custom theme with pastel colors and rounded shapes. The home view includes a date picker, birthday list, and task checkboxes.
5. **Mock Data**: On first run, `_getMockBirthdays()` generates three sample friends with Korean-inspired names, stickers, and predefined tasks.

## Customization

- **Change Theme**: Modify `utils/styles.dart` and `utils/colors.dart` (if exists) to adjust colors and fonts.
- **Add Stickers**: Place new PNG images in `assets/sticker/` and reference them in the birthday model (currently uses emoji strings; you can extend to use asset paths).
- **Adjust Notification Logic**: Edit `services/notification_service.dart` to change alert timing or appearance.

## Acknowledgments

- Flutter team for the wonderful framework.
- Providers of the used packages: `provider`, `shared_preferences`, `flutter_local_notifications`, `timezone`, `image_picker`, `file_picker`, `audioplayers`, `flutter_launcher_icons`.
- The cute sticker images are sourced from open/free collections (ensure you have rights for any additional assets you add).

## License

This project is open source and available under the [MIT License](LICENSE).

---

*Made with 💖 for remembering birthdays in style.*