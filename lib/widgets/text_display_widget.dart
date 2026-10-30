import 'package:flutter/material.dart';

class TextDisplayWidget extends StatelessWidget {
  final String text;
  final double fontSize;
  final double lineSpacing;
  final Color textColor;

  const TextDisplayWidget({
    super.key,
    required this.text,
    required this.fontSize,
    required this.lineSpacing,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        height: lineSpacing,
        color: textColor,
      ),
    );
  }
}
