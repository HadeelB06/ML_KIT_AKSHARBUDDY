import '../theme/app_localizations.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(File) onImageSelected;

  const ImagePickerWidget({super.key, required this.onImageSelected});

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _image;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      setState(() {
        _image = file;
      });

      widget.onImageSelected(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// FIX: Give FIXED HEIGHT
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _image == null
              ? const Center(child: LText("No image selected"))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
        ),

        const SizedBox(height: 10),

        ElevatedButton(onPressed: pickImage, child: const LText("Pick Image")),
      ],
    );
  }
}
