import 'package:flutter/material.dart';
import '../services/assistant_voice.dart';
import '../services/voice_command_handler.dart';
import '../theme/app_localizations.dart';
import 'voice_assistant_controls.dart';

class AssistantRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AssistantVoice.stop();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AssistantVoice.stop();
  }
}

class HelpSpeakerButton extends StatelessWidget {
  final String message;
  const HelpSpeakerButton({super.key, required this.message});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tr('Explain this screen'),
    icon: const Icon(Icons.volume_up_outlined),
    onPressed: () async {
      try {
        await AssistantVoice.speak(message);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'No installed voice for this language. Open Android voice settings.',
                ),
              ),
            ),
          );
        }
      }
    },
  );
}

Future<VoiceCommandIntent?> showReaderAssistant(BuildContext context) async {
  String? feedback;
  var language = AppLocalizations.language;
  final command = await showModalBottomSheet<VoiceCommandIntent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Voice assistant'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const HelpSpeakerButton(
                  message:
                      'Use the microphone for one command at a time. Reading pauses while the assistant listens.',
                ),
                IconButton(
                  tooltip: tr('Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const LText(
              'Use the microphone for one command at a time. Reading pauses while the assistant listens.',
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.choose(
                'Try: read this page • pause reading • resume reading • repeat sentence • read slower • make text bigger • change colors',
                'कहें: यह पेज पढ़ें • पढ़ना रोकें • पढ़ना जारी रखें • वाक्य दोहराएं • धीरे पढ़ें • अक्षर बड़े करें • रंग बदलें',
                'म्हणा: हे पान वाचा • वाचन थोडावेळ थांबवा • वाचन पुन्हा सुरू करा • वाक्य पुन्हा वाचा • हळू वाचा • मजकूर मोठा करा • रंग बदला',
              ),
            ),
            VoiceAssistantControls(
              initialLanguageCode: language,
              onBeforeListening: AssistantVoice.stop,
              onListeningCancelled: () async {},
              onLanguageChanged: (code, locale) async {
                language = code;
              },
              onRecognized: (transcript, code) async {
                final intent = VoiceCommandHandler.parse(
                  transcript,
                  languageCode: code,
                );
                if (intent == VoiceCommandIntent.unsupported) {
                  update(
                    () => feedback = VoiceCommandHandler.unsupportedFeedback(
                      code,
                    ),
                  );
                } else {
                  Navigator.pop(context, intent);
                }
              },
              feedback: feedback,
            ),
          ],
        ),
      ),
    ),
  );
  await AssistantVoice.stop();
  return command;
}
