class FormatResult {
  final String processedText;
  final String profile;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double wordSpacing;
  final double paragraphSpacing;
  final String recommendedFont;
  final String sourceType;

  /// Raw extracted text before dyslexia formatting.
  /// Nullable: older backend responses or edge cases may not include it.
  /// Use [rawText] to access with a safe fallback.
  final String? originalText;

  /// Optional structure-aware OCR model for tables, menus, and columns.
  /// Kept nullable so older backend responses remain fully compatible.
  final Map<String, dynamic>? structuredContent;

  /// Returns the raw OCR/extracted text if available, otherwise falls back
  /// to [processedText].  Use this as the input to local model simplification
  /// so the pipeline is OCR → Simplify → Format rather than
  /// OCR → Format → Simplify.
  String get rawText => originalText ?? processedText;

  const FormatResult({
    required this.processedText,
    required this.profile,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.wordSpacing,
    required this.paragraphSpacing,
    required this.recommendedFont,
    this.sourceType = 'unknown',
    this.originalText,
    this.structuredContent,
  });

  factory FormatResult.fromJson(Map<String, dynamic> json) {
    return FormatResult(
      processedText: json['processedText'] as String,
      profile: json['profile'] as String,
      fontSize: (json['fontSize'] as num).toDouble(),
      lineHeight: (json['lineHeight'] as num).toDouble(),
      letterSpacing: (json['letterSpacing'] as num).toDouble(),
      wordSpacing: (json['wordSpacing'] as num).toDouble(),
      paragraphSpacing: (json['paragraphSpacing'] as num).toDouble(),
      recommendedFont: json['recommendedFont'] as String,
      sourceType: json['sourceType'] as String? ?? 'unknown',
      originalText: json['originalText'] as String?,
      structuredContent: json['structuredContent'] is Map
          ? Map<String, dynamic>.from(json['structuredContent'] as Map)
          : null,
    );
  }

  FormatResult copyWith({
    String? processedText,
    String? originalText,
    Map<String, dynamic>? structuredContent,
  }) {
    return FormatResult(
      processedText: processedText ?? this.processedText,
      profile: profile,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      paragraphSpacing: paragraphSpacing,
      recommendedFont: recommendedFont,
      sourceType: sourceType,
      originalText: originalText ?? this.originalText,
      structuredContent: structuredContent ?? this.structuredContent,
    );
  }
}
