import '../theme/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/library_storage.dart';
import '../widgets/buddy_brand.dart';
import 'output_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with LanguageRebuild<LibraryScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final all = LibraryStorage.getItems();
    final items = all
        .where(
          (i) => '${i.title} ${i.content}'.toLowerCase().contains(
            _query.trim().toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BuddyHeading(
          'Your library',
          'Good words are worth coming back to.',
        ),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            labelText: tr('Search readings'),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          BuddyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book_outlined, size: 36),
                const SizedBox(height: 16),
                Text(
                  all.isEmpty
                      ? 'No saved readings yet.'
                      : 'No matching readings.',
                ),
                const SizedBox(height: 8),
                const LText(
                  'Readings you open from a new source are saved here.',
                ),
              ],
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BuddyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OutputScreen(
                              displayText: item.content,
                              originalText: item.originalText,
                              readingId: item.date.toIso8601String(),
                              language: item.language,
                              extractionRecordPath: item.extractionRecordPath,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const LText('Read again'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const LText('Remove this reading?'),
                              content: Text(item.title),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const LText('Keep reading'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const LText('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && mounted) {
                            LibraryStorage.removeItem(
                              LibraryStorage.getItems().indexOf(item),
                            );
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const LText('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
