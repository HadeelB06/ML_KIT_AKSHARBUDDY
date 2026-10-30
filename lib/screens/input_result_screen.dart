import '../theme/app_localizations.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/ocr_document.dart';
import '../services/mlkit_ocr_service.dart';
import '../services/ocr_layout.dart';
import '../services/ocr_store.dart';
import '../services/tts_service.dart';
import 'ocr_review_screen.dart';
import 'output_screen.dart';

class InputResultScreen extends StatefulWidget {
  final OcrDocument document;
  const InputResultScreen({super.key, required this.document});
  @override
  State<InputResultScreen> createState() => _InputResultScreenState();
}

class _InputResultScreenState extends State<InputResultScreen> with LanguageRebuild<InputResultScreen> {
  late OcrDocument document = widget.document;
  final TTSService voice = TTSService();
  final Set<String> accepted = {};
  String? saveError;
  @override
  void initState() {
    super.initState();
    voice.onError = (m) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    };
  }

  @override
  void dispose() {
    voice.dispose();
    super.dispose();
  }

  Future<void> edit(int index) async {
    final page = document.pages[index];
    final edited = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewScreen(
          text: page.displayText,
          source: File(page.recognitionImagePath ?? page.originalPath ?? ''),
        ),
      ),
    );
    if (edited == null || !mounted) return;
    final pages = document.pages.toList();
    pages[index] = page.edited(edited);
    final updated = document.withPages(pages);
    try {
      await OcrStore.save(updated);
      if (mounted) setState(() => document = updated);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => saveError =
            'Could not save your edit. Your raw result is preserved.',
      );
    }
  }

  Future<void> arrangeRows(int index) async {
    final page = document.pages[index];
    final pages = document.pages.toList();
    pages[index] = page.edited(OcrLayout.rows(page));
    final updated = document.withPages(pages);
    try {
      await OcrStore.save(updated);
      if (mounted) setState(() => document = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => saveError = 'Could not save the arranged rows.');
    }
  }

  Future<void> startReading() async {
    try {
      final path = await OcrStore.save(document);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OutputScreen(
            language: document.language,
            displayText: document.displayText,
            originalText: document.rawText,
            extractionRecordPath: path,
            saveOnLoad: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => saveError = 'Could not save this reading. Please try again.',
      );
    }
  }

  Future<void> word(int index, Map<String, dynamic> element) async {
    final page = document.pages[index];
    final key = '$index:${element['box']}:${element['text']}';
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                element['text'] as String,
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              if (page.recognitionImagePath != null)
                SizedBox(
                  height: 100,
                  child: _WordImage(
                    path: page.recognitionImagePath!,
                    box: Map<String, dynamic>.from(element['box']),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => voice.speak(
                      element['text'] as String,
                      language: page.language,
                    ),
                    child: const LText('Hear it'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, 'accept'),
                    child: const LText('Looks right'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, 'edit'),
                    child: const LText('Edit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, 'retake'),
                    child: const LText('Return to crop / retake'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await voice.stop();
    if (!mounted) return;
    if (action == 'accept') setState(() => accepted.add(key));
    if (action == 'edit') await edit(index);
    if (action == 'retake' && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Your extracted text')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: document.hasText ? startReading : null,
          icon: const Icon(Icons.menu_book),
          label: const LText('Start Reading'),
        ),
        if (document.cancelled)
          const LText('Stopped. Completed pages are kept.'),
        if (document.sourceType == 'pdf')
          LText(
            'Document: ${document.totalPages} pages. Results below: ${document.pages.length} pages. Unselected or unprocessed pages are not included.',
          ),
        if (document.importantNumbers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LText('Check important numbers and doses.'),
          ),
        if (saveError != null) Text(saveError!),
        for (var i = 0; i < document.pages.length; i++) _page(i),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Return to crop / retake'),
        ),
      ],
    ),
  );
  Widget _page(int i) {
    final p = document.pages[i];
    final doubtful = OcrReviewPolicy.doubtfulWords(p);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText('Page ${p.pageNumber} · ${p.status} · ${p.sourceType}'),
            if (p.status == 'failed')
              const LText(
                'This page could not be read. Other results are kept.',
              ),
            if (p.rawOcrText.isEmpty && p.status != 'failed')
              const LText('No text was found. Try a clearer photo.'),
            if (OcrReviewPolicy.difficult(p))
              const LText(
                'This image may be difficult to read. You can crop or retake it.',
              ),
            const SizedBox(height: 12),
            SelectableText(p.displayText),
            if (p.displayText.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: p.displayText));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: LText('Text copied')));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const LText('Copy text'),
              ),
            TextButton(
              onPressed: () => edit(i),
              child: const LText('Review doubtful text (optional)'),
            ),
            if (p.recognitionImagePath != null &&
                p.blocks.isNotEmpty &&
                p.userEditedText == null)
              TextButton(
                onPressed: () => arrangeRows(i),
                child: const LText('Arrange rows (receipts / tables)'),
              ),
            if (doubtful.isNotEmpty)
              ExpansionTile(
                title: const LText('Words you may want to check'),
                children: [
                  Wrap(
                    spacing: 6,
                    children: doubtful.map((e) {
                      final checked = accepted.contains(
                        '$i:${e['box']}:${e['text']}',
                      );
                      return ActionChip(
                        avatar: checked
                            ? const Icon(Icons.check, size: 16)
                            : null,
                        label: Text(e['text'] as String),
                        onPressed: () => word(i, e),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ExpansionTile(
              title: const LText('Raw text and details'),
              children: [
                SelectableText(p.rawOcrText),
                if (p.error != null) SelectableText(p.error!),
                if (p.userEditedText != null)
                  const LText(
                    'Your edits are stored separately. Raw text is unchanged.',
                  ),
                if (p.recognitionImagePath != null)
                  SizedBox(
                    height: 220,
                    child: InteractiveViewer(
                      maxScale: 8,
                      child: Image.file(
                        File(p.recognitionImagePath!),
                        errorBuilder: (_, e, s) =>
                            const LText('Image unavailable.'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordImage extends StatefulWidget {
  final String path;
  final Map<String, dynamic> box;
  const _WordImage({required this.path, required this.box});
  @override
  State<_WordImage> createState() => _WordImageState();
}

class _WordImageState extends State<_WordImage> with LanguageRebuild<_WordImage> {
  ui.Image? image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(widget.path).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() => image = frame.image);
      } else {
        frame.image.dispose();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => image == null
      ? const LText('Loading source…')
      : CustomPaint(
          size: const Size(300, 100),
          painter: _WordPainter(image!, widget.box),
        );
}

class _WordPainter extends CustomPainter {
  final ui.Image image;
  final Map<String, dynamic> box;
  _WordPainter(this.image, this.box);
  @override
  void paint(Canvas canvas, Size size) {
    final source =
        Rect.fromLTRB(
          (box['left'] as num).toDouble(),
          (box['top'] as num).toDouble(),
          (box['right'] as num).toDouble(),
          (box['bottom'] as num).toDouble(),
        ).intersect(
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        );
    if (source.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    canvas.drawImageRect(
      image,
      source,
      Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _WordPainter old) =>
      old.image != image || old.box != box;
}
