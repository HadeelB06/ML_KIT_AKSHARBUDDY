import '../theme/app_localizations.dart';
import 'dart:io';
import 'package:flutter/material.dart';

/// Optional user editing; caller retains immutable raw recognition.
class OcrReviewScreen extends StatefulWidget {
  final String text;
  final File source;
  const OcrReviewScreen({super.key, required this.text, required this.source});
  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> with LanguageRebuild<OcrReviewScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  );
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = RegExp(
      r'\.(png|jpe?g|webp)$',
      caseSensitive: false,
    ).hasMatch(widget.source.path);
    return Scaffold(
      appBar: AppBar(title: const LText('Check your text')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const LText(
              'Optional: edit any text you want to correct. You can listen without reviewing.',
            ),
            const SizedBox(height: 16),
            if (image)
              ExpansionTile(
                title: const LText('View source image'),
                children: [
                  SizedBox(
                    height: 260,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.file(
                        widget.source,
                        errorBuilder: (_, e, stack) =>
                            const LText('Image preview is unavailable.'),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 24,
              decoration: InputDecoration(
                labelText: tr('Extracted text'),
                alignLabelWithHint: true,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_text.text.trim().isEmpty) {
                  setState(() => _error = 'Enter some text to continue.');
                  return;
                }
                Navigator.pop(context, _text.text);
              },
              child: const LText('Save my edits'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LText('Choose another image or document'),
            ),
          ],
        ),
      ),
    );
  }
}
