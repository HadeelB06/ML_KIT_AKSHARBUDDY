# AksharBuddy

Android reading assistant with on-device ML Kit OCR, synchronized read-aloud highlighting, saved words, font previews and voice commands.

**English · हिन्दी · मराठी**

**No laptop backend is needed to use the app.** New users can install the APK directly. A computer is needed only to edit or build the source.

## Install on your Android phone

### Requirements

- Android **7.0 or newer**.
- `VOICE_ASSISTANT.apk` from the maintainer or this repository’s Releases section, once published. The supplied APK is approximately 202 MB.
- An Android text-to-speech engine with voices for the languages you want to read.

### Installation steps

1. Download `VOICE_ASSISTANT.apk` on your phone, or copy it from your computer.
2. Open it using Downloads or your Files app.
3. If prompted, allow **Install unknown apps** for the browser/file manager opening this trusted APK.
4. Tap **Install**, then open **AksharBuddy**.
5. Choose **English**, **हिन्दी** or **मराठी** on the welcome screen.
6. Tap **Try without an account** to begin. Registration is optional.

This is a signed **debug APK for testing**, not a Play Store release. GitHub’s automatic “Source code” ZIP contains source files, not an installable application.

## First-time voice setup

1. Open **Settings → Android voice settings** in AksharBuddy.
2. In your phone’s text-to-speech settings, choose an engine and install English, Hindi and/or Marathi voice data. Menu names vary by phone.
3. Download the required voices while connected to the internet.
4. Return to AksharBuddy, select the language matching your reading, and try **Listen** on a short passage.

**Interface language** controls menus and buttons. **Reading language** controls how your text is processed and spoken. Selecting Marathi menus does not translate an English document into Marathi.

### Choose the assistant voice

Open **Settings → Assistant voice**, select a language and tap **Hear a sample**. Select and save your preferred voice.

The assistant prefers a female-labelled voice when available. Many Android engines do not report gender, so audition the installed voices and choose the female voice you prefer. A guaranteed female voice is not bundled inside the APK; availability depends on your phone’s speech engine.

## How to use the app

### Read a passage, photo or document

1. From Home, choose **Type or paste text**, **Take a photo**, **Choose an image**, or **Open a document**.
2. Select the language matching the text: English, Hindi or Marathi.
3. Check scanned text and correct OCR mistakes before reading.
4. Tap **Listen**. Use **Stop**, **Repeat sentence** and the speed control as needed.
5. Return to saved readings through **Library**.

Image OCR and PDF/DOCX extraction run on your phone. Check extracted text against the original, especially for blurry images, unusual layouts or mixed text.

### Save words and mark them known

Tap a word in a reading to open word help. Save it to **My Words**, adding a checked meaning or personal note when needed. Open the **Words** tab later to hear pronunciation and mark words **Known** or **Learning**. This is a vocabulary feature, not a homework-grading tool or online dictionary.

### Preview fonts and colours

Open **Settings → Style preview**, or use the preview icon in the reader. Choose **Reading style** or **App appearance**, then preview fonts, text size, spacing and colours. Tap **Apply this style** to save. Going back without applying keeps your saved style unchanged.

Bundled fonts: BuddySans, OpenDyslexic, Lexend, Atkinson Hyperlegible and Noto Sans Devanagari.

### Give voice commands

Open a reading, tap the microphone, grant microphone permission, choose a supported recognition language and tap **Listen** in the assistant panel.

| Language | Example |
| --- | --- |
| English | `read this page` or `pause reading` |
| Hindi | `धीरे पढ़ें` |
| Marathi | `हे पान वाचा` |

Recognition depends on the phone’s speech service and may need internet. The assistant uses a separate speech engine to preserve the original reader’s progress callbacks. Speaker buttons on the welcome and home screens provide spoken help.

## Does it need internet or a laptop?

| Feature | Requirement |
| --- | --- |
| Image OCR and PDF/DOCX extraction | Local processing; no laptop server |
| Reading aloud | Offline when the matching offline voice is installed |
| Saved words, library and appearance settings | Stored locally on the device |
| Downloading language voice data | Internet for the download |
| Voice-command recognition | Depends on the phone’s recognition service |
| Assistant speech | Depends on whether the chosen voice is offline or network-based |
| Optional registration/sign-in | Firebase and internet |

Signing in does not establish cloud backup of local words and readings. Clearing app data or uninstalling can remove saved work.

## Developer setup: build from source

### Verified toolchain

| Tool | Version used for the supplied APK |
| --- | --- |
| Flutter | 3.41.0 |
| Dart | 3.11.0, included with Flutter |
| Java JDK | 21 |
| Android compile/target SDK | 36 |
| Minimum Android version for supplied APK | API 24 / Android 7.0 |

Use this toolchain to reproduce the tested build before upgrading dependencies. Android is the supported target for the added native assistant functionality.

### 1. Prepare your computer

Install Git and the [Flutter SDK](https://docs.flutter.dev/install), and add Flutter’s `bin` directory to PATH. Install Android Studio and follow Flutter’s [Android setup guide](https://docs.flutter.dev/platform-integration/android/setup).

Through SDK Manager, install Android SDK Platform 36, Build-Tools, Platform-Tools and Command-line Tools. Allow Gradle to obtain any additional project-required SDK components. Configure a compatible JDK; this project was built with Java 21. Check the Java path printed by `flutter doctor -v`.

```sh
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

Read and accept the SDK licences when prompted. Resolve Android toolchain errors before building. The first dependency download and build require internet.

### 2. Get the source

Clone this repository, or download its source ZIP and extract it. Open a terminal **inside the folder containing `pubspec.yaml`**. Do not try to build directly inside a ZIP.

### 3. Install dependencies, check and build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The newly built APK is here:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Keep `packages/speech_to_text/`, `assets/fonts/`, `pubspec.lock` and the Android Gradle wrapper. They are required parts of the project. Machine-specific `android/local.properties` is excluded; Flutter generates/configures it for your computer. Start with Flutter commands from the project root rather than invoking Gradle directly.

### 4. Run on a connected phone

Enable Developer options and USB debugging, connect the phone by USB and approve its debugging prompt. On Windows, install the manufacturer’s USB driver if necessary.

```sh
flutter devices
flutter run
```

With multiple devices, use `flutter run -d DEVICE_ID`, replacing `DEVICE_ID` with the phone’s identifier.

### Optional: your own Firebase sign-in

Guest reading does not require a new Firebase project. The source retains the original client configuration in `lib/firebase_options.dart`; sign-in relies on that project’s availability and authentication settings.

For an independently maintained app, follow [Firebase’s Flutter setup guide](https://firebase.google.com/docs/flutter/setup). Install the Firebase CLI, sign in, install FlutterFire CLI and configure your own project from this folder:

```sh
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select Android and your Firebase project. Enable **Authentication → Sign-in method → Email/Password** in Firebase Console. Keep the Android application ID and Firebase app registration aligned. If you use `android/app/google-services.json`, it must match the same app/project. Do not commit service-account private keys.

The display name is **AksharBuddy**. The Dart package name remains `aksharally_ui`, and the Android application ID is `com.example.aksharally_ui`, retained for compatibility.

## Put this project on GitHub

For the maintainer:

1. Create a GitHub repository.
2. Upload/push the **contents** of this source folder so `README.md` and `pubspec.yaml` appear at the repository root. Keep the supplied `.gitignore`.
3. Include source, Android project, assets, the local speech package, tests, dependency files and documentation. Keep font and package licence files.
4. Exclude generated `build/` and `.dart_tool/` folders, local SDK paths and signing keys. The supplied `.gitignore` already excludes APKs.
5. Create a GitHub Release and attach **`VOICE_ASSISTANT.apk`** as a release asset instead of committing the large binary to Git history. See [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
6. Direct new users to **Releases → VOICE_ASSISTANT.apk**. You can then add your actual release link near the top of this README.

No repository or download URL is invented here; this delivery has not been published to GitHub.

For production distribution, configure a private release signing key using Flutter’s [Android release guide](https://docs.flutter.dev/deployment/android). The current Gradle release configuration also uses debug signing; running a release build alone does not configure production signing.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| APK does not install | Android 7.0+, complete download and permission to install from the file source. An existing app with the same package ID but a different signing certificate can conflict. Preserve saved work before uninstalling anything. |
| Reader is silent | Raise media volume, install the matching offline voice in Android settings and select the correct reading language. |
| Hindi/Marathi pronunciation is wrong | Check both the reading language and installed TTS voice. Menu language is a separate setting. |
| Assistant does not sound female | Preview available voices under Settings → Assistant voice and select your preference. Availability is engine-dependent. |
| Microphone fails | Grant microphone permission, check the speech-recognition service and language, and try with internet access. |
| Sign-in fails | Use “Try without an account” for reading. Developers should check Firebase configuration and Email/Password authentication. |
| `flutter` is not recognized | Add Flutter’s `bin` directory to PATH, reopen the terminal and run `flutter doctor -v`. |
| Android SDK/Java build error | Run `flutter doctor -v`; check SDK 36, the configured JDK and missing SDK components/licences. |
| Local speech package missing | Restore the complete `packages/speech_to_text/` folder and run `flutter pub get`. |

## Verification and scope

- Static analysis: **no issues found**.
- Automated tests: **57 passed**, covering original reading regressions and new interface/assistant behaviour.
- Debug APK: built, signature checked and bundled fonts verified.
- Thirteen core files match the original ML Kit project byte for byte; see [preservation evidence](docs/CORE_PRESERVATION.json).
- Marathi welcome and preview images were visually checked; see [validation notes](docs/VALIDATION.md).
- Physical-phone recognition, actual voice gender and camera OCR were not verified for this delivery. Check these on your device.

This version adds the assistant, language interface and appearance preview to the original ML Kit app. It does not include the separate Progress Handoff project’s page-by-page PDF reader, or claim improved OCR accuracy.
