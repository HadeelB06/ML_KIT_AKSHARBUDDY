# AksharBuddy

Current version: **1.3.0 (4)**. Reading menus support English, Hindi and Marathi.

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

## Confidence-guided OCR (1.3.0)

Everything runs on the phone. No internet and no large AI model are needed.

**What happens when a page is read**

1. **Better input.** A new **Scan a page** button opens Google's on-device document scanner. It finds the page edges, straightens tilted photos and removes shadows. It downloads once through Google Play services, then works offline. If it is missing, **Take a photo** still works. Big phone photos are scaled to about 16 MP instead of being rejected. A short tip appears under the preview if a photo looks blurry or dark.
2. **Two readers.** ML Kit's Devanagari and Latin models both read the page. The Devanagari model also reads English, so mixed Hindi/Marathi + English pages work. Each line is taken from the reader that is surer of it.
3. **Small print.** If the text is very small (screenshots, forwarded photos), the page is enlarged once and read again. The enlarged read is kept only if it is better.
4. **Spotting suspicious text.** Rules flag broken matras, Hindi and English letters mixed in one word, digit/letter mix-ups like `1O5`, impossible times like `10530 AM`, invalid dates, low confidence, and lines where the two readers disagree.
5. **Re-reading only the problem lines.** Each suspicious line is cropped, enlarged and cleaned two ways, then read again.
6. **Voting.** Agreement means the line is shown normally. If the re-reads agree on a different word, the line is corrected. **Numbers, dates and times are never changed automatically.** They stay highlighted with a "Does the original say this instead?" button, so the reader decides.
7. **Reading order.** Newspaper columns are read column by column, menus and receipts keep each item next to its price, and tilted or sideways photos keep the right order. A `|` that ML Kit gives for the Hindi full stop becomes `।`, so text-to-speech pauses correctly.
8. **Hindi PDFs in old fonts.** Some PDFs (Kruti Dev and similar) look fine on screen but extract as junk such as "Hkkjr ljdkj". These pages are detected and read from the rendered page instead.

**Settings you can tune** (`lib/services/mlkit_ocr_service.dart` and `lib/services/ocr/ocr_rules.dart`)

| Setting | Default | What it changes |
| --- | --- | --- |
| `maxRetryLines` | 16 | How many suspicious lines per page are re-read. Higher is more careful but slower. |
| `OcrRuleConfig.wordConfidence` / `lineConfidence` | 0.55 / 0.60 | Below these ML Kit confidences a word or line counts as suspicious. Raise them to check more, lower them to check less. |
| `smallTextHeight` | 20 px | Pages whose text lines are shorter than this are enlarged once. |
| `latinOnlyConfidence` | 0.75 | On Hindi/Marathi pages, an English-only line needs this confidence to be kept. This blocks junk from the English reader. |

To tune: save the app's text for each test image as `name.<variant>.txt` next to a hand-typed `name.txt`, run `dart run tool/ocr_eval.dart <folder>`, and keep a change only if CER/WER drops.

**Automatic checks.** Every push runs `.github/workflows/ci.yml` on GitHub: `flutter analyze` and `flutter test` on Windows (the golden screenshots were made on Windows), and a debug APK build on Linux. You can download the APK from the run's *Artifacts*.

## PDF page-reading update

- Previous/Next page controls with actual page numbers.
- Read aloud one page at a time, without automatic page advance.
- Saved position and original/edited text selection for each page.
- Visible warnings for failed or incompletely extracted pages.
- Saved-text fallback with a warning if page records are missing or damaged.

The original OCR and synchronized TTS engines are unchanged. Validation: **67 tests passed**, clean static analysis, and a verified debug APK build. Physical-phone testing is still needed.

See [PDF update details](docs/PDF_PAGE_UPGRADE.md), [validation evidence](docs/VALIDATION.md), and the [complete user/developer guide](docs/USER_GUIDE.md).
