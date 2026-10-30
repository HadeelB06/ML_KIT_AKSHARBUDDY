import 'dart:convert';

/// Immutable engine result, including the exact string returned by ML Kit.
/// Metadata uses a serialized snapshot so callers cannot mutate nested raw data.
class OcrPage {
  final String rawOcrText;
  final String language;
  final String sourceType;
  final String? originalPath;
  final String? recognitionImagePath;
  final int pageNumber;
  final String status;
  final String? error;
  final String metadataJson;
  final String? userEditedText;
  const OcrPage({
    required this.rawOcrText,
    required this.language,
    required this.sourceType,
    this.originalPath,
    this.recognitionImagePath,
    this.pageNumber = 1,
    this.status = 'complete',
    this.error,
    this.metadataJson = '[]',
    this.userEditedText,
  });
  String get displayText => userEditedText ?? rawOcrText;
  List<dynamic> get blocks => jsonDecode(metadataJson) as List<dynamic>;
  OcrPage edited(String text) => OcrPage(
    rawOcrText: rawOcrText,
    language: language,
    sourceType: sourceType,
    originalPath: originalPath,
    recognitionImagePath: recognitionImagePath,
    pageNumber: pageNumber,
    status: status,
    error: error,
    metadataJson: metadataJson,
    userEditedText: text,
  );
  Map<String, dynamic> toJson() => {
    'rawOcrText': rawOcrText,
    'language': language,
    'sourceType': sourceType,
    'originalPath': originalPath,
    'recognitionImagePath': recognitionImagePath,
    'pageNumber': pageNumber,
    'status': status,
    'error': error,
    'blocks': blocks,
    'userEditedText': userEditedText,
  };
  factory OcrPage.fromJson(Map<String, dynamic> j) => OcrPage(
    rawOcrText: j['rawOcrText'] as String,
    language: j['language'] as String,
    sourceType: j['sourceType'] as String,
    originalPath: j['originalPath'] as String?,
    recognitionImagePath: j['recognitionImagePath'] as String?,
    pageNumber: j['pageNumber'] as int,
    status: j['status'] as String,
    error: j['error'] as String?,
    metadataJson: jsonEncode(j['blocks']),
    userEditedText: j['userEditedText'] as String?,
  );
}

class OcrDocument {
  final String id;
  final String language;
  final String sourceType;
  final String? originalPath;
  final int totalPages;
  final List<OcrPage> pages;
  final bool cancelled;
  final bool importantNumbers;
  OcrDocument({
    required this.id,
    required this.language,
    required this.sourceType,
    this.originalPath,
    this.totalPages = 1,
    required List<OcrPage> pages,
    this.cancelled = false,
    this.importantNumbers = false,
  }) : pages = List.unmodifiable(pages);
  String get displayText => sourceType == 'pdf'
      ? pages
            .map((p) => '—— Page ${p.pageNumber} ——\n${p.displayText}')
            .join('\n\n')
      : pages.map((p) => p.displayText).join('\n\n');
  String get rawText => sourceType == 'pdf'
      ? pages
            .map((p) => '—— Page ${p.pageNumber} ——\n${p.rawOcrText}')
            .join('\n\n')
      : pages.map((p) => p.rawOcrText).join('\n\n');
  bool get hasText => pages.any((p) => p.displayText.trim().isNotEmpty);
  OcrDocument withPages(List<OcrPage> value, {bool? cancelled}) => OcrDocument(
    id: id,
    language: language,
    sourceType: sourceType,
    originalPath: originalPath,
    totalPages: totalPages,
    pages: value,
    cancelled: cancelled ?? this.cancelled,
    importantNumbers: importantNumbers,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'language': language,
    'sourceType': sourceType,
    'originalPath': originalPath,
    'totalPages': totalPages,
    'cancelled': cancelled,
    'importantNumbers': importantNumbers,
    'pages': pages.map((p) => p.toJson()).toList(),
  };
  factory OcrDocument.fromJson(Map<String, dynamic> j) => OcrDocument(
    id: j['id'] as String,
    language: j['language'] as String,
    sourceType: j['sourceType'] as String,
    originalPath: j['originalPath'] as String?,
    totalPages: j['totalPages'] as int,
    cancelled: j['cancelled'] == true,
    importantNumbers: j['importantNumbers'] == true,
    pages: (j['pages'] as List)
        .map((p) => OcrPage.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}
