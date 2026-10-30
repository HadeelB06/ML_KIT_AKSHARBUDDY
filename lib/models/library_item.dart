class LibraryItem {
  final String? language;
  final String? extractionRecordPath;
  final String? originalText;
  final String title;
  final String content;
  final DateTime date;
  final String sourceType; // 'image' | 'pdf' | 'docx' | 'text' | 'simplified'

  LibraryItem({
    required this.title,
    this.language,
    this.extractionRecordPath,
    this.originalText,
    required this.content,
    required this.date,
    this.sourceType = 'unknown',
  });

  // ── JSON serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'language': language,
    'extractionRecordPath': extractionRecordPath,
    'originalText': originalText,
    'title': title,
    'content': content,
    'date': date.toIso8601String(),
    'sourceType': sourceType,
  };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    language: json['language'] as String?,
    extractionRecordPath: json['extractionRecordPath'] as String?,
    originalText: json['originalText'] as String?,
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    sourceType: json['sourceType'] as String? ?? 'unknown',
  );
}
