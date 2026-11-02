# AksharBuddy

Current version: **1.2.0 (3)**. Reading menus support English, Hindi and Marathi.

**No laptop backend is needed to use the Android app.** The laptop setup below is only for building from source. See the [user guide](docs/USER_GUIDE.md) for APK installation, voice setup and app usage.

## AksharBuddy APK Build — New Windows Laptop

### 1. Install required software

| Software       | Version           | Download                                                                              |
| -------------- | ----------------- | ------------------------------------------------------------------------------------- |
| Git            | Latest            | [Download](https://git-scm.com/install/windows?utm_source=chatgpt.com)                |
| Flutter SDK    | 3.41.0            | [Download](https://docs.flutter.dev/install/archive?utm_source=chatgpt.com)           |
| Android Studio | Latest compatible | [Download](https://developer.android.com/studio?utm_source=chatgpt.com)               |
| Java JDK       | 21                | [Download](https://adoptium.net/temurin/releases/?version=21\&utm_source=chatgpt.com) |
| VS Code        | Latest (optional) | [Download](https://code.visualstudio.com/?utm_source=chatgpt.com)                     |

Note: Dart comes with Flutter. No separate installation needed.

### 2. Configure everything

1. Extract Flutter to `C:\src\flutter`.
2. Add `C:\src\flutter\bin` to Windows Environment Variables → Path.
3. Open Android Studio → SDK Manager.
4. Install Android SDK Platform 36, Build-Tools, Platform-Tools and Command-line Tools.
5. Ensure JDK 21 is configured.

### 3. Verify installation

Open Command Prompt and run:

```
git --version
java -version
flutter --version
flutter doctor
flutter doctor --android-licenses
```

Accept Android licenses by entering `y`.

### 4. Download AksharBuddy source

1. Open the GitHub repository.
2. Click Code → Download ZIP.
3. Extract ZIP.
4. Open the extracted folder containing `pubspec.yaml`.
5. Type `cmd` in File Explorer's address bar and press Enter.

### 5. Build APK

Run these commands one by one:

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

### 6. Find the APK

The generated APK is located at:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Transfer it to your Android phone and install it.

## PDF page-reading update

- Previous/Next page controls with actual page numbers.
- Read aloud one page at a time, without automatic page advance.
- Saved position and original/edited text selection for each page.
- Visible warnings for failed or incompletely extracted pages.
- Saved-text fallback with a warning if page records are missing or damaged.

The original OCR and synchronized TTS engines are unchanged. Validation: **67 tests passed**, clean static analysis, and a verified debug APK build. Physical-phone testing is still needed.

See [PDF update details](docs/PDF_PAGE_UPGRADE.md), [validation evidence](docs/VALIDATION.md), and the [complete user/developer guide](docs/USER_GUIDE.md).
