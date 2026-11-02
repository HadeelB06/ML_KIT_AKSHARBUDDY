# PDF reader update — 31 October 2026

Version: 1.2.0 (Android build 3).

Merged from AksharBuddy_Progress_Handoff.zip into VOICE_ASSISTANT, preserving the assistant, appearance preview and English/Hindi/Marathi interface.

- Compact previous/next arrows and actual PDF page number.
- Speech is restricted to the selected page, with no automatic page advance.
- Independent position and original/edited selection per page; last page restored on reopening.
- Failed pages remain navigable and incomplete/cancelled extraction is explicitly shown.
- Missing/corrupt page records fall back to saved text with a visible warning.
- Original/edited selection remains available even if one version is empty.
- New page-reader controls and messages are localized in Hindi and Marathi.
- Navigation stops active speech and resets the reading highlight and scroll position.

Core OCR/TTS services and PDF extraction are unchanged. Non-PDF input keeps its existing full-text behaviour. No backend, new OCR model or confidence pipeline was added. A broader interface simplification remains the next design step.

The original source was preserved before integration. Local backup folders are not part of this repository.

Automated coverage includes current-page utterances, completion boundaries, navigation while speaking, per-page offsets, library-style reopening, original/edited selection, empty edited text, missing/corrupt records, narrow Marathi layout, failed-page extraction and cancelled extraction. Native PDF calls and speech are mocked in tests; physical-device verification is still needed.
