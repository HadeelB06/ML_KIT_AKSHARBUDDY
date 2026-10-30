import '../theme/app_localizations.dart';
import '../services/tts_service.dart';
import 'package:flutter/material.dart';
import '../services/buddy_store.dart';
import '../services/word_service.dart';

Future<void> showWordHelp(
  BuildContext context,
  String word,
  String language,
) async {
  final cleaned = WordService.clean(word);
  if (cleaned.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => WordHelpSheet(word: cleaned, language: language),
  );
}

class WordHelpSheet extends StatefulWidget {
  final String word, language;
  const WordHelpSheet({super.key, required this.word, required this.language});
  @override
  State<WordHelpSheet> createState() => _WordHelpSheetState();
}

class _WordHelpSheetState extends State<WordHelpSheet> {
  SavedWord? _entry;
  String? _error;
  bool _saving = false;
  final _meaning = TextEditingController();
  final _example = TextEditingController();
  final _voice = TTSService();
  @override
  void dispose() {
    _meaning.dispose();
    _example.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    for (final entry in BuddyStore.words) {
      if (entry.id == '${widget.language}:${widget.word.toLowerCase()}') {
        _entry = entry;
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await BuddyStore.saveWord(_entry!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: LText('Saved to My Words.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this word. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      20,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LText(
                'Word help',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: tr('Close word help'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(widget.word, style: Theme.of(context).textTheme.headlineMedium),
        TextButton.icon(
          onPressed: () => _voice.speak(widget.word, language: widget.language),
          icon: const Icon(Icons.volume_up_outlined),
          label: const LText('Hear this word'),
        ),
        const SizedBox(height: 16),
        if (_entry != null) ...[
          Text(_entry!.definition),
          const SizedBox(height: 16),
          LText('Example', style: Theme.of(context).textTheme.titleMedium),
          Text(_entry!.example),
          const SizedBox(height: 16),
          LText(
            '${_entry!.source}. Check the meaning if it seems unexpected.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(_saving ? 'Saving…' : 'Save to My Words'),
          ),
        ] else ...[
          const LText(
            'This simplification model is not a dictionary. Add a meaning you have checked; your note stays on this device.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _meaning,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: tr('Your meaning or note'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _example,
            decoration: InputDecoration(labelText: tr('Example (optional)')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () {
                    if (_meaning.text.trim().isEmpty) {
                      setState(() => _error = 'Add a meaning or note first.');
                      return;
                    }
                    _entry = SavedWord(
                      word: widget.word,
                      language: widget.language,
                      definition: _meaning.text.trim(),
                      example: _example.text.trim(),
                      source: 'Personal note',
                    );
                    _save();
                  },
            child: const LText('Save my note'),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Text(_error!)),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Back to reading'),
        ),
      ],
    ),
  );
}
