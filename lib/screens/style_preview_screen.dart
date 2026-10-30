import 'package:flutter/material.dart';
import '../theme/app_localizations.dart';
import '../theme/style_draft.dart';
import '../theme/accessibility_settings.dart';
import '../services/assistant_voice.dart';

/// Additive DIYA-style preview. No reading text or playback state is changed.
class StylePreviewScreen extends StatefulWidget {
  final String sample;
  const StylePreviewScreen({super.key, this.sample = ''});
  @override
  State<StylePreviewScreen> createState() => _StylePreviewScreenState();
}

class _StylePreviewScreenState extends State<StylePreviewScreen> {
  bool _reader = true, _saving = false;
  late StyleDraft _draft = StyleDraft(reader: true);
  String get _sample => widget.sample.trim().isNotEmpty
      ? widget.sample
      : AppLocalizations.choose(
          'A little reading, at your pace. Every word is a new beginning.',
          'अपनी गति से पढ़ें। हर शब्द एक नई शुरुआत है।',
          'तुमच्या गतीने वाचा. प्रत्येक शब्द ही नवी सुरुवात आहे.',
        );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LText('${tr(label)} · ${value.toStringAsFixed(1)}'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: _saving ? null : (v) => setState(() => change(v)),
      ),
    ],
  );
  @override
  void dispose() {
    AssistantVoice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Style preview')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    await _draft.apply();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Changes saved'))),
                      );
                      Navigator.pop(context, true);
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr('Could not save your change. Please try again.'),
                          ),
                        ),
                      );
                    }
                  }
                },
          icon: const Icon(Icons.check),
          label: const LText('Apply this style'),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('Preview before applying'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const LText(
          'Preview only. Your current style stays unchanged until you apply.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const LText('Reading style'),
              selected: _reader,
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                      _reader = true;
                      _draft = StyleDraft(reader: true);
                    }),
            ),
            ChoiceChip(
              label: const LText('App appearance'),
              selected: !_reader,
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                      _reader = false;
                      _draft = StyleDraft(reader: false);
                    }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const LText(
          'Live preview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('style-preview'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _draft.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _draft.foreground.withValues(alpha: .2)),
          ),
          child: Text(_sample, style: _draft.textStyle),
        ),
        const SizedBox(height: 24),
        const LText(
          'Font gallery',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final font in StyleDraft.fonts)
          Card(
            child: ListTile(
              selected: _draft.font == font,
              leading: Icon(
                _draft.font == font
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(
                font == 'System Default' ? tr('Clear sans serif') : font,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  AppLocalizations.choose(
                    'Read with confidence.',
                    'आत्मविश्वास से पढ़ें।',
                    'आत्मविश्वासाने वाचा.',
                  ),
                  style: TextStyle(
                    fontFamily: StyleDraft.family(font),
                    fontFamilyFallback: const ['NotoSansDevanagari'],
                    fontSize: 19,
                  ),
                ),
              ),
              onTap: _saving ? null : () => setState(() => _draft.font = font),
            ),
          ),
        const SizedBox(height: 20),
        _slider(
          'Font size',
          _draft.size,
          _reader ? 16 : 14,
          _reader ? 36 : 24,
          (v) => _draft.size = v,
        ),
        _slider(
          'Letter spacing',
          _draft.letters,
          0,
          3,
          (v) => _draft.letters = v,
        ),
        _slider('Word spacing', _draft.words, 0, 12, (v) => _draft.words = v),
        _slider(
          'Line spacing',
          _draft.lines,
          1.2,
          2.5,
          (v) => _draft.lines = v,
        ),
        const SizedBox(height: 12),
        const LText(
          'Page colour',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              [
                    'cream_black',
                    'soft_yellow_black',
                    'pale_blue_navy',
                    'pale_green_gray',
                    'white_black',
                    'cream_navy',
                  ]
                  .map(
                    (key) => Semantics(
                      label: tr(AccessibilitySettings.themeLabels[key] ?? key),
                      selected: _draft.palette == key,
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _draft.palette = key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 145,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AccessibilitySettings.previewBg(key),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: _draft.palette == key ? 3 : 1,
                              color: _draft.palette == key
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          child: Text(
                            tr(AccessibilitySettings.themeLabels[key] ?? key),
                            style: TextStyle(
                              color: AccessibilitySettings.previewText(key),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() => _draft = StyleDraft(reader: _reader)),
          child: const LText('Reset'),
        ),
      ],
    ),
  );
}
