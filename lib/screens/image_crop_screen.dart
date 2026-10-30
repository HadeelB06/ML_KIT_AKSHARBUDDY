import '../theme/app_localizations.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/image_input_service.dart';

/// Selection coordinates refer to the full-resolution, EXIF-oriented preview.
class ImageCropScreen extends StatefulWidget {
  final PreparedImage image;
  const ImageCropScreen({super.key, required this.image});
  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> with LanguageRebuild<ImageCropScreen> {
  Offset? start, end;
  Size displayed = Size.zero;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const LText('Select one column, paragraph or question'),
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: LText('Drag a rectangle around the part you want to read.'),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final scale = math.min(
                c.maxWidth / widget.image.width,
                c.maxHeight / widget.image.height,
              );
              final w = widget.image.width * scale,
                  h = widget.image.height * scale;
              displayed = Size(w, h);
              Offset clamp(Offset p) =>
                  Offset(p.dx.clamp(0, w), p.dy.clamp(0, h));
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: GestureDetector(
                    onPanStart: (d) => setState(() {
                      start = clamp(d.localPosition);
                      end = start;
                    }),
                    onPanUpdate: (d) =>
                        setState(() => end = clamp(d.localPosition)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(widget.image.path), fit: BoxFit.fill),
                        if (start != null && end != null)
                          Positioned.fromRect(
                            rect: Rect.fromPoints(start!, end!),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: .12),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: start == null || end == null
                ? null
                : () {
                    final rect = Rect.fromPoints(start!, end!);
                    if (rect.width < 8 || rect.height < 8 || displayed.isEmpty) {
                      return;
                    }
                    Navigator.pop(context, <double>[
                      rect.left / displayed.width,
                      rect.top / displayed.height,
                      rect.right / displayed.width,
                      rect.bottom / displayed.height,
                    ]);
                  },
            child: const LText('Use this crop'),
          ),
        ),
      ],
    ),
  );
}
