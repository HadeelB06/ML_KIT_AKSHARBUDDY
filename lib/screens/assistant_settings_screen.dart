import 'package:flutter/material.dart';
import '../services/assistant_voice.dart';
import '../services/tts_service.dart';
import '../theme/app_localizations.dart';

class AssistantSettingsScreen extends StatefulWidget {
  const AssistantSettingsScreen({super.key});
  @override
  State<AssistantSettingsScreen> createState() => _AssistantSettingsScreenState();
}
class _AssistantSettingsScreenState extends State<AssistantSettingsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _voices = [];
  String? _selected;
  String? _error;
  bool _loading = true;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); AppLocalizations.notifier.addListener(_load); _load(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) { _load(); } else { AssistantVoice.stop(); } }
  Future<void> _load() async {
    final language = AppLocalizations.language;
    setState(() { _loading = true; _error = null; });
    try {
      final voices = await AssistantVoice.voices(language);
      final selected = await AssistantVoice.selected(language);
      if (mounted && language == AppLocalizations.language) setState(() { _voices = voices; _selected = selected; _loading = false; });
    } catch (_) { if (mounted) setState(() { _error = tr('No installed voice for this language. Open Android voice settings.'); _loading = false; }); }
  }
  Future<void> _sample() async {
    try { await AssistantVoice.speak('Hello. I am your reading assistant. Let us read together.'); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No installed voice for this language. Open Android voice settings.')))); }
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); AppLocalizations.notifier.removeListener(_load); AssistantVoice.stop(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Assistant voice')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const InterfaceLanguagePicker(), const SizedBox(height: 20),
      const LText('Female voice preference', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const LText('Choose and preview an installed voice. Voice gender depends on your Android speech engine.'),
      const SizedBox(height: 20),
      if (_loading) const Center(child: CircularProgressIndicator())
      else if (_error != null || _voices.isEmpty) LText(_error ?? 'No installed voice for this language. Open Android voice settings.')
      else ...[
        if (!_voices.any((v) => v['female'] == true)) const LText('No voice reports its gender. Preview the voices and select the female voice you prefer.'),
        DropdownButtonFormField<String>(
          initialValue: _voices.any((v) => v['name'] == _selected) ? _selected : '', isExpanded: true,
          items: [DropdownMenuItem(value: '', child: Text(tr('Prefer a female voice'))),
            ..._voices.map((v) => DropdownMenuItem(value: v['name'] as String, child: LText('${v['name']} (${v['locale']})', overflow: TextOverflow.ellipsis)))],
          onChanged: (value) async {
            try { await AssistantVoice.stop(); await AssistantVoice.select(AppLocalizations.language, value == '' ? null : value); if (mounted) setState(() => _selected = value); }
            catch (_) { if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Could not save your change. Please try again.')))); } }
          }),
        const SizedBox(height: 16), FilledButton.icon(onPressed: _sample, icon: const Icon(Icons.volume_up), label: const LText('Hear a sample')),
        TextButton(onPressed: AssistantVoice.stop, child: const LText('Stop')),
      ],
      const SizedBox(height: 20), OutlinedButton.icon(onPressed: () async {
        try { await TTSService.openVoiceSettings(); } catch (_) { if (mounted) setState(() => _error = tr('No installed voice for this language. Open Android voice settings.')); }
      }, icon: const Icon(Icons.settings_voice), label: const LText('Android voice settings')),
    ]));
}
