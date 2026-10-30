import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ocr_document.dart';

class OcrStore {
  static Future<Directory> directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/ocr_records').create(recursive: true);
  }

  static Future<String> save(OcrDocument doc) async {
    final dir = await directory();
    final target = '${dir.path}/${doc.id}.json';
    final temp = File('$target.tmp');
    await temp.writeAsString(jsonEncode(doc.toJson()), flush: true);
    await temp.rename(target);
    return target;
  }

  static Future<OcrDocument> load(String path) async => OcrDocument.fromJson(
    jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
  );
  static Future<File> keepOriginal(File file) async {
    final dir = await directory();
    final ext = file.path.split('.').last.toLowerCase();
    return file.copy(
      '${dir.path}/source_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
  }

  static Future<List<File>> records() async {
    final dir = await directory();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }
}
