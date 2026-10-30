import 'package:flutter/material.dart';

import '../theme/accessibility_settings.dart';
import '../theme/app_theme.dart';

/// Renders the optional OCR layout model without flattening it into prose.
/// This widget is intentionally tolerant of missing fields so older or
/// partially-recognised documents can still be displayed safely.
class StructuredContentView extends StatelessWidget {
  final Map<String, dynamic> content;
  final ValueChanged<String>? onWordTap;

  const StructuredContentView({
    super.key,
    required this.content,
    this.onWordTap,
  });

  Widget _text(String value, {TextStyle? style}) {
    if (onWordTap == null) return Text(value, style: style);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: value
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map(
            (word) => Semantics(
              button: true,
              label: 'Explain $word',
              child: InkWell(
                onTap: () => onWordTap!(word),
                child: Text(word, style: style),
              ),
            ),
          )
          .toList(),
    );
  }

  TextStyle get _bodyStyle => TextStyle(
    color: AccessibilitySettings.textColor(),
    fontSize: 18,
    height: 1.55,
  );

  @override
  Widget build(BuildContext context) {
    final blocks =
        (content['blocks'] as List?)
            ?.whereType<Map>()
            .map((block) => Map<String, dynamic>.from(block))
            .toList() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: AppTheme.spaceMD),
          _buildBlock(blocks[index]),
        ],
      ],
    );
  }

  Widget _buildBlock(Map<String, dynamic> block) {
    switch (block['type']) {
      case 'table':
        return _buildTable(block);
      case 'menu_section':
        return _buildMenuSection(block);
      case 'columns':
        return _buildColumns(block);
      case 'section':
        return _buildSection(block);
      default:
        return _text(block['text'] as String? ?? '', style: _bodyStyle);
    }
  }

  Widget _buildTable(Map<String, dynamic> block) {
    final headers =
        (block['headers'] as List?)
            ?.map((value) => value?.toString() ?? '')
            .toList() ??
        const <String>[];
    final rows =
        (block['rows'] as List?)
            ?.whereType<List>()
            .map((row) => row.map((value) => value?.toString() ?? '').toList())
            .toList() ??
        const <List<String>>[];
    final columnCount = headers.length;
    if (columnCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnValues = List.generate(
          columnCount,
          (column) => [
            headers[column],
            for (final row in rows) column < row.length ? row[column] : '',
          ],
        );
        // Estimate the width of the longest unbreakable word, not the full
        // sentence. Long descriptions can wrap inside a cell and should not
        // force an otherwise readable 2–3 column table to scroll.
        final preferredWidths = columnValues.map<double>((values) {
          final longestWord = values.fold<int>(0, (longest, value) {
            final wordLength = value
                .split(RegExp(r'\s+'))
                .fold<int>(
                  0,
                  (current, word) =>
                      word.length > current ? word.length : current,
                );
            return wordLength > longest ? wordLength : longest;
          });
          return (longestWord * 8.0 + 28.0).clamp(72.0, 220.0).toDouble();
        }).toList();
        final preferredTotal = preferredWidths.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final availableWidth = constraints.maxWidth;
        final needsHorizontalScroll =
            !availableWidth.isFinite || preferredTotal > availableWidth;

        final fittingColumnWidths = <int, TableColumnWidth>{};
        if (!needsHorizontalScroll && preferredTotal > 0) {
          final extraWidth = availableWidth - preferredTotal;
          for (var index = 0; index < columnCount; index++) {
            // Give wider-content columns a proportionate share of spare
            // space while keeping all cells at the same column width.
            final share = preferredWidths[index] / preferredTotal;
            fittingColumnWidths[index] = FixedColumnWidth(
              preferredWidths[index] + extraWidth * share,
            );
          }
        }

        final table = Table(
          columnWidths: needsHorizontalScroll ? null : fittingColumnWidths,
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.35),
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.10),
              ),
              children: headers
                  .map((header) => _tableCell(header, isHeader: true))
                  .toList(),
            ),
            for (final row in rows)
              TableRow(
                children: List.generate(
                  columnCount,
                  (index) => _tableCell(index < row.length ? row[index] : ''),
                ),
              ),
          ],
        );

        return needsHorizontalScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : table;
      },
    );
  }

  Widget _tableCell(String value, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _text(
        value.isEmpty ? ' ' : value,
        style: _bodyStyle.copyWith(
          fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMenuSection(Map<String, dynamic> block) {
    final items =
        (block['items'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          block['title']?.toString() ?? 'Menu',
          style: _bodyStyle.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      items[index]['name']?.toString() ?? '',
                      style: _bodyStyle.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if ((items[index]['description']?.toString() ?? '')
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _text(
                          items[index]['description'].toString(),
                          style: _bodyStyle.copyWith(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
              if ((items[index]['price']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _text(
                    items[index]['price'].toString(),
                    style: _bodyStyle.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildColumns(Map<String, dynamic> block) {
    final columns =
        (block['columns'] as List?)
            ?.whereType<List>()
            .map((column) => column.map((line) => line.toString()).toList())
            .toList() ??
        const <List<String>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          if (index > 0) const Divider(height: 28),
          for (final line in columns[index])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _text(line, style: _bodyStyle),
            ),
        ],
      ],
    );
  }

  Widget _buildSection(Map<String, dynamic> block) {
    final lines =
        (block['lines'] as List?)
            ?.map((line) => line?.toString() ?? '')
            .where((line) => line.isNotEmpty)
            .toList() ??
        const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          block['title']?.toString() ?? '',
          style: _bodyStyle.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _text(lines[index], style: _bodyStyle),
        ],
      ],
    );
  }
}
