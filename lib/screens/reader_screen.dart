import 'package:flutter/material.dart';
import '../models/format_result.dart';
import 'output_screen.dart';
import 'reading_screen.dart';
/// Compatibility entry point; no legacy OCR or simplification calls.
class ReaderScreen extends StatelessWidget {
  final String? initialText, displayText, language;
  final FormatResult? initialFormatResult;
  const ReaderScreen({super.key,this.initialText,this.displayText,this.language,this.initialFormatResult});
  @override Widget build(BuildContext context) {
    if(initialFormatResult!=null)return OutputScreen(initialFormatResult:initialFormatResult,language:language);
    final text=displayText??initialText;
    if(text!=null)return OutputScreen(displayText:text,originalText:text,language:language,saveOnLoad:initialText!=null);
    return const ReadingScreen();
  }
}
