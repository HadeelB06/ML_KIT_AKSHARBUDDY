import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

String extractDocxBytes(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw StateError('Choose a DOCX up to 10 MB.');
  }
  final zip = ZipDecoder().decodeBytes(bytes);
  final file = zip.findFile('word/document.xml');
  if (file == null) throw StateError('This is not a readable DOCX document.');
  if (file.size > 20 * 1024 * 1024) {
    throw StateError('The document text exceeds the supported memory limit.');
  }
  final doc = XmlDocument.parse(utf8.decode(file.content));
  final body = doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'body')
      .first;
  String inline(XmlNode node) {
    if (node is XmlElement) {
      switch (node.name.local) {
        case 't':
          return node.innerText;
        case 'tab':
          return '\t';
        case 'br':
        case 'cr':
          return '\n';
        case 'del':
          return ''; // Word's deleted revision is not displayed text.
      }
    }
    return node.children.whereType<XmlElement>().map(inline).join();
  }

  String block(XmlElement e) {
    if (e.name.local == 'p') return inline(e);
    if (e.name.local == 'tbl') {
      return e.childElements
          .where((r) => r.name.local == 'tr')
          .map(
            (r) => r.childElements
                .where((c) => c.name.local == 'tc')
                .map(
                  (c) => c.childElements
                      .where(
                        (x) =>
                            x.name.local == 'p' ||
                            x.name.local == 'tbl' ||
                            x.name.local == 'sdt' ||
                            x.name.local == 'sdtContent',
                      )
                      .map(block)
                      .join('\n'),
                )
                .join('\t'),
          )
          .join('\n');
    }
    return e.childElements
        .where(
          (x) =>
              x.name.local == 'p' ||
              x.name.local == 'tbl' ||
              x.name.local == 'sdt' ||
              x.name.local == 'sdtContent',
        )
        .map(block)
        .join('\n');
  }

  return body.childElements
      .where(
        (e) =>
            e.name.local == 'p' ||
            e.name.local == 'tbl' ||
            e.name.local == 'sdt',
      )
      .map(block)
      .join('\n');
}

String _readDocx(String path) => extractDocxBytes(File(path).readAsBytesSync());

class DocxInputService {
  static Future<String> read(String path) => compute(_readDocx, path);
}
