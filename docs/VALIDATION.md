# Current validation — version 1.2.0 (3)

- Flutter analyzer: no issues.
- Complete regression suite: 67 tests passed.
- PDF-focused coverage: current-page-only speech, no automatic advance, original/edited selection, empty edited version recovery, missing/corrupt page-record fallback, navigation while speaking, independent page offsets, reopening at the saved page, Marathi controls on a narrow phone, failed extraction and cancelled extraction coverage.
- Android debug APK built successfully; version 1.2.0, build 3. Package metadata, v2 signature and bundled font assets verified.
- Marathi PDF-reader preview visually inspected; original/edited and speech-speed labels localized.
- All 13 original core OCR/TTS/storage files still match the ML Kit base byte for byte. See CORE_PRESERVATION.json.

Current evidence files start with `page-upgrade-`. Earlier logs without that prefix describe version 1.1.0 and its 57-test milestone.

Native PDF extraction and TTS are mocked in the automated tests. No connected physical phone was used to validate installation, microphone recognition, actual voice gender or OCR accuracy. The APK remains a test/debug build.

These checks were completed on the local build before publication. See PDF_PAGE_UPGRADE.md for the scope and README.md for setup.
