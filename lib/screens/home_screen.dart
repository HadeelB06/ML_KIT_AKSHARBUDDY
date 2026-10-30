import '../theme/app_localizations.dart';
import '../widgets/assistant_widgets.dart';
import 'package:flutter/material.dart';
import '../services/library_storage.dart';
import '../widgets/buddy_brand.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'reading_screen.dart';
import 'output_screen.dart';
import 'words_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with LanguageRebuild<HomeScreen> {
  int _tab = 0;
  Future<void> _open(ReadingTab tab, {String? input}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(initialTab: tab, initialInput: input),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const BuddyMark(size: 34),
          const SizedBox(width: 10),
          Flexible(
            child: LText(
              'AksharBuddy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      actions: [
        const HelpSpeakerButton(message: 'Choose Read for a new passage, Library for saved readings, or Words for your vocabulary.'),
        IconButton(
          tooltip: tr('Settings'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: SafeArea(child: SettingsScreen())),
            ),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            key: ValueKey(_tab),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: [
              _home(),
              const LibraryScreen(),
              const WordsScreen(),
              const SettingsScreen(),
            ][_tab],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories),
          label: tr('Read'),
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_open_outlined),
          label: tr('Library'),
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmarks_outlined),
          label: tr('Words'),
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: tr('Settings'),
        ),
      ],
    ),
  );
  Widget _home() {
    final recent = LibraryStorage.continueReading();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BuddyHeading(
          'Read at your pace',
          'Read text from a photo, document or message.',
        ),
        BuddyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LText(
                      'Start with your words',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const LText(
                'Paste a passage, a message, or something you want to understand.',
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _open(ReadingTab.type),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const LText('Type or paste text'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LText('Or bring a page', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _source(
          Icons.camera_alt_outlined,
          tr('Take a photo'),
          tr('Capture a printed page'),
          () => _open(ReadingTab.scan, input: 'camera'),
        ),
        _source(
          Icons.photo_library_outlined,
          tr('Choose an image'),
          tr('Open a picture from your phone'),
          () => _open(ReadingTab.scan, input: 'image'),
        ),
        _source(
          Icons.description_outlined,
          tr('Open a document'),
          tr('PDF or Word document'),
          () => _chooseDocument(),
        ),
        const SizedBox(height: 24),
        LText(
          'Continue reading',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          const BuddyCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark_border_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: LText(
                    'Your saved readings will appear here. Start with something you enjoy.',
                  ),
                ),
              ],
            ),
          ),
        for (final item in recent)
          _source(
            Icons.menu_book_outlined,
            item.title,
            'Continue reading',
            () async {
              await Navigator.push(
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
              );
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }

  Widget _source(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _chooseDocument() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText('Choose a document', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(c, 'pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const LText('Open PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(c, 'docx'),
              icon: const Icon(Icons.description_outlined),
              label: const LText('Open Word (.docx)'),
            ),
          ],
        ),
      ),
    );
    if (kind != null && mounted) await _open(ReadingTab.upload, input: kind);
  }
}
