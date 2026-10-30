import 'package:flutter/material.dart';
import 'reading_screen.dart';
/// Legacy navigation entry reuses the single local-input flow.
class UploadFileScreen extends StatelessWidget {
  const UploadFileScreen({super.key});
  @override Widget build(BuildContext context) => const ReadingScreen(initialTab: ReadingTab.upload);
}
