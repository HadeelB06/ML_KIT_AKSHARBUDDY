import 'dart:io';
import '../models/format_result.dart';
/// Dormant compatibility surface. No networking is allowed here.
class ApiService {
  static Future<FormatResult> processImage(File file,{String profile='moderate',
    void Function(String)? onProgress,String? language}) async =>
    throw UnsupportedError('Open New reading to use local ML Kit or document extraction.');
  static Future<void> checkConnection() async =>
    throw UnsupportedError('This build does not use a laptop connection.');
  static Future<String> simplifyText(String text,{String? language}) async =>
    throw UnsupportedError('Only Original text mode is available.');
  static Future<StructuredSimplifyResult> simplifyStructuredText(String text,
    Map<String,dynamic> structuredContent,{String? language}) async =>
    throw UnsupportedError('Only Original text mode is available.');
}
class StructuredSimplifyResult {
  final String formattedText;
  final Map<String,dynamic> structuredContent;
  const StructuredSimplifyResult({required this.formattedText,required this.structuredContent});
}
