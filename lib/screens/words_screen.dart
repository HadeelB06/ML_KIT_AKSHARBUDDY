import '../theme/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/buddy_store.dart';
import '../theme/app_settings.dart';
import '../widgets/buddy_brand.dart';
import '../widgets/word_help_sheet.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});
  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> with LanguageRebuild<WordsScreen> {
  String _filter = 'All', _query = '';
  final _lookup = TextEditingController();
  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Could not save your change. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: BuddyStore.notifier,
    builder: (context, _, _) {
      final entries = BuddyStore.words
          .where(
            (w) =>
                (_filter == 'All' || (_filter == 'Known') == w.known) &&
                w.word.toLowerCase().contains(_query.toLowerCase()),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BuddyHeading(
            'My Words',
            'A small collection. A little more confidence.',
          ),
          BuddyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LText(
                  'Find a word',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lookup,
                  decoration: InputDecoration(
                    labelText: tr('Word to explain'),
                    hintText: tr('One word at a time'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      showWordHelp(context, _lookup.text, AppSettings.language),
                  icon: const Icon(Icons.search),
                  label: const LText('Open word help'),
                ),
                const SizedBox(height: 8),
                const LText(
                  'You can also tap a word in your reading. Saved meanings stay available offline.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              labelText: tr('Search saved words'),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Learning', 'Known']
                .map(
                  (f) => ChoiceChip(
                    label: LText(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const BuddyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bookmarks_outlined, size: 32),
                  SizedBox(height: 12),
                  LText('Your words will grow here.'),
                  SizedBox(height: 8),
                  LText(
                    'Save a useful meaning, then mark it Known when you feel ready.',
                  ),
                ],
              ),
            ),
          for (final w in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BuddyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      w.word,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      {
                            'en': 'English',
                            'hi': 'Hindi',
                            'mr': 'Marathi',
                          }[w.language] ??
                          w.language,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showWordHelp(context, w.word, w.language),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const LText('Open meaning and pronunciation'),
                    ),
                    Text(w.definition),
                    const SizedBox(height: 8),
                    Text(w.example),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _change(
                            () => BuddyStore.saveWord(w.withKnown(!w.known)),
                          ),
                          icon: Icon(
                            w.known
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                          label: LText(
                            w.known ? 'Known · mark Learning' : 'Mark Known',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: LText('Remove ${w.word}?'),
                                content: const LText(
                                  'This removes the saved meaning from this device.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const LText('Keep word'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const LText('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) {
                              await _change(() => BuddyStore.removeWord(w.id));
                            }
                          },
                          child: const LText('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
