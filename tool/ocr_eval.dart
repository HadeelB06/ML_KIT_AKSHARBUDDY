// Usage: dart run tool/ocr_eval.dart <folder>
// Folder holds ground truth  name.txt  and OCR outputs  name.<variant>.txt
// (e.g. sample1.txt, sample1.plain.txt, sample1.enhanced.txt, sample1.arranged.txt).
// Export OCR text from the app (Copy text / raw text) and type ground truth by hand.
import 'dart:io';
import 'package:aksharally_ui/services/ocr_metrics.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Pass the folder with ground-truth and OCR .txt files.');
    exit(64);
  }
  final files = Directory(
    args.first,
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList();
  final names = {for (final f in files) f.uri.pathSegments.last};
  stdout.writeln('file,variant,CER,WER');
  for (final n in names.where((n) => n.split('.').length == 2)) {
    final base = n.split('.').first;
    final truth = File('${args.first}/$n').readAsStringSync();
    for (final v in names.where((v) => v.startsWith('$base.') && v != n)) {
      final hyp = File('${args.first}/$v').readAsStringSync();
      stdout.writeln(
        '$base,${v.split('.')[1]},${cer(truth, hyp).toStringAsFixed(4)},${wer(truth, hyp).toStringAsFixed(4)}',
      );
    }
  }
}
