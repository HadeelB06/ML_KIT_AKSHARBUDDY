import '../theme/app_localizations.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../widgets/buddy_brand.dart';
import '../models/ocr_document.dart';
import '../services/mlkit_ocr_service.dart';
import '../services/ocr_store.dart';
import '../services/image_input_service.dart';
import '../services/scan_service.dart';
import '../services/document_input_service.dart';
import 'input_result_screen.dart';
import 'image_crop_screen.dart';
import '../theme/app_settings.dart';
import 'output_screen.dart';

/// Public enum so HomeScreen can specify which tab opens by default.
enum ReadingTab { scan, type, upload }

class ReadingScreen extends StatefulWidget {
  final ReadingTab initialTab;
  final String? initialInput;

  const ReadingScreen({
    super.key,
    this.initialTab = ReadingTab.scan,
    this.initialInput,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with LanguageRebuild<ReadingScreen> {
  // ── Local UI state ─────────────────────────────────────────────────────────
  late ReadingTab _tab;

  // Explicit language selection is local to this input and recognizer.
  String _language = AppSettings.language;

  // Input state
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  File? _pickedFile;
  File? _originalFile;
  PreparedImage? _prepared;
  int _turns = 0;
  bool _enhance = false;
  List<double>? _crop;
  String _sourceType = 'gallery';
  bool _importantNumbers = false;
  InputCancellation? _cancellation;
  final List<String> _pageStatuses = [];
  String? _pickedFileName;

  // Processing state
  bool _isLoading = false;
  String _stage = 'Preparing text';
  String? _error;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;

    // Recover an image if Android recreated MainActivity
    // while the camera/gallery picker was open.
    _retrieveLostImage();
    if (widget.initialInput != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialInput) {
          case 'camera':
            _pickImage(ImageSource.camera);
            break;
          case 'image':
            _pickImage(ImageSource.gallery);
            break;
          case 'pdf':
            _pickFile(extensions: ['pdf']);
            break;
          case 'docx':
            _pickFile(extensions: ['docx']);
            break;
        }
      });
    }
  }

  Future<void> _retrieveLostImage() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();

      if (response.isEmpty) return;

      if (response.files != null && response.files!.isNotEmpty) {
        final XFile xf = response.files!.first;
        final file = File(xf.path);

        if (!await file.exists()) return;
        if (await file.length() == 0) return;

        if (!mounted) return;

        await _acceptFile(file, xf.name, 'camera');
      } else if (response.exception != null) {
        if (!mounted) return;

        setState(() {
          _error = response.exception.toString();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _textController.dispose();
    super.dispose();
  }

  // ── Input helpers ───────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? xf = await _picker.pickImage(
        source: source,
        // Keep the camera's full-resolution capture. JPEG compression here
        // can remove small characters, punctuation, prices, and table lines.
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xf == null) return;

      final file = File(xf.path);
      if (!await file.exists()) {
        throw Exception('The camera did not return a readable image.');
      }
      if (await file.length() == 0) {
        throw Exception('The captured image is empty. Please scan it again.');
      }

      await _acceptFile(
        file,
        xf.name,
        source == ImageSource.camera ? 'camera' : 'gallery',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Best input for paper: Google's on-device scanner flattens, de-shadows
  /// and crops the page before OCR.
  Future<void> _scanPage() async {
    File? file;
    try {
      file = await ScanService.scanPage();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'The page scanner is not available on this phone. Please use Take a photo.',
      );
      return;
    }
    if (file == null) return; // closed without scanning
    try {
      await _acceptFile(file, file.uri.pathSegments.last, 'camera');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickFile({List<String>? extensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions ?? ['pdf', 'docx', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.path == null) return;
      await _acceptFile(
        File(picked.path!),
        picked.name,
        picked.extension == 'pdf' ? 'pdf' : 'docx',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open file picker.');
    }
  }

  void _clearPick() => setState(() {
    _pickedFile = null;
    _originalFile = null;
    _prepared = null;
    _turns = 0;
    _enhance = false;
    _pickedFileName = null;
  });

  // ── Continue action ─────────────────────────────────────────────────────────

  Future<void> _onContinue() async {
    if (_tab == ReadingTab.type && _textController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter some text before continuing.');
      return;
    }
    if (_tab != ReadingTab.type && _pickedFile == null) {
      setState(
        () => _error = _tab == ReadingTab.scan
            ? 'Please capture or select an image first.'
            : 'Please select a file first.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _runPipelineAndNavigate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _acceptFile(File file, String name, String source) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _stage = 'Opening input';
      _error = null;
    });
    try {
      final original = await OcrStore.keepOriginal(file);
      final isImage = ![
        'pdf',
        'docx',
      ].contains(name.split('.').last.toLowerCase());
      final prepared = isImage
          ? await ImageInputService.prepare(original.path)
          : null;
      if (!mounted) return;
      setState(() {
        _originalFile = original;
        _pickedFile = prepared == null ? original : File(prepared.path);
        _prepared = prepared;
        _pickedFileName = name;
        _turns = 0;
        _enhance = false;
        _crop = null;
        _sourceType = source;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _imageEdit(String action) async {
    if (_originalFile == null) return;
    setState(() {
      _isLoading = true;
      _stage = 'Preparing original-resolution image';
    });
    try {
      var turns = _turns;
      final enhance = action == 'enhance' ? !_enhance : _enhance;
      var nextCrop = _crop;
      if (action == 'reset') nextCrop = null;
      if (action == 'rotate') {
        turns = (turns + 1) % 4;
        if (nextCrop != null) {
          nextCrop = [
            1 - nextCrop[3],
            nextCrop[0],
            1 - nextCrop[1],
            nextCrop[2],
          ];
        }
      }
      var prepared = await ImageInputService.prepare(
        _originalFile!.path,
        turns: turns,
        crop: action == 'crop' ? null : nextCrop,
        enhance: enhance,
      );
      if (action == 'crop' && mounted) {
        final crop = await Navigator.push<List<double>>(
          context,
          MaterialPageRoute(builder: (_) => ImageCropScreen(image: prepared)),
        );
        if (crop == null) return;
        nextCrop = crop;
        prepared = await ImageInputService.prepare(
          _originalFile!.path,
          turns: turns,
          crop: crop,
          enhance: enhance,
        );
      }
      if (mounted) {
        setState(() {
          _turns = turns;
          _enhance = enhance;
          _crop = nextCrop;
          _prepared = prepared;
          _pickedFile = File(prepared.path);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<int>?> _range(int total) async {
    final first = TextEditingController(text: '1'),
        last = TextEditingController(text: '$total');
    String? error;
    final value = await showDialog<List<int>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: LText('PDF · $total pages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('First page')),
              ),
              TextField(
                controller: last,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Last page')),
              ),
              if (error != null) Text(error!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const LText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(first.text), b = int.tryParse(last.text);
                if (a == null || b == null || a < 1 || b < a || b > total) {
                  set(() => error = 'Choose a valid page range.');
                  return;
                }
                Navigator.pop(c, [a, b]);
              },
              child: const LText('Read pages'),
            ),
          ],
        ),
      ),
    );
    // Controllers belong to the dialog route; wait for its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    first.dispose();
    last.dispose();
    return value;
  }

  Future<void> _runPipelineAndNavigate() async {
    if (_tab == ReadingTab.type) {
      final text =
          _textController.text; // Preserve typed/pasted content exactly.
      final document = OcrDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        language: _language,
        sourceType: 'text',
        pages: [
          OcrPage(rawOcrText: text, language: _language, sourceType: 'text'),
        ],
      );
      final path = await OcrStore.save(document);
      _push(
        OutputScreen(
          language: _language,
          displayText: text,
          originalText: text,
          extractionRecordPath: path,
          saveOnLoad: true,
        ),
      );
      return;
    }
    final original = _originalFile!;
    final service = DocumentInputService();
    OcrDocument document;
    if (_prepared != null) {
      setState(() => _stage = 'Recognizing text on this phone');
      final page = await MlkitOcrService().recognize(
        path: _pickedFile!.path,
        language: _language,
        sourceType: _sourceType,
        originalPath: original.path,
        importantNumbers: _importantNumbers,
      );
      document = OcrDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        language: _language,
        sourceType: _sourceType,
        originalPath: original.path,
        pages: [page],
        importantNumbers: _importantNumbers,
      );
    } else {
      setState(() => _stage = 'Opening document on this phone');
      final session = await service.open(original);
      if (!mounted) {
        await service.close(session);
        return;
      }
      final range = session.kind == 'pdf'
          ? await _range(session.pageCount)
          : <int>[1, 1];
      if (range == null || !mounted) {
        await service.close(session);
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _cancellation = InputCancellation();
      _pageStatuses.clear();
      document = await service.read(
        session,
        language: _language,
        first: range[0],
        last: range[1],
        importantNumbers: _importantNumbers,
        cancellation: _cancellation!,
        progress: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
        onPage: (page) {
          if (mounted) {
            setState(
              () =>
                  _pageStatuses.add('Page ${page.pageNumber}: ${page.status}'),
            );
          }
        },
      );
      _cancellation = null;
    }
    await OcrStore.save(document);
    _push(InputResultScreen(document: document));
  }

  Future<void> _savedExtractions() async {
    final files = await OcrStore.records();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: LText('Saved extraction results')),
            for (final f in files)
              ListTile(
                title: Text(f.uri.pathSegments.last),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final d = await OcrStore.load(f.path);
                  if (!c.mounted) return;
                  Navigator.pop(c);
                  if (mounted) _push(InputResultScreen(document: d));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const LText('New reading'),
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _savedExtractions,
          icon: const Icon(Icons.history),
          tooltip: tr('Saved extractions'),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BuddyHeading(
                  'Bring something to read',
                  'Printed text only. All input processing stays on this phone.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReadingTab.values
                      .map(
                        (tab) => ChoiceChip(
                          label: LText(
                            {
                              ReadingTab.scan: 'Photo',
                              ReadingTab.type: 'Text',
                              ReadingTab.upload: 'Document',
                            }[tab]!,
                          ),
                          selected: _tab == tab,
                          onSelected: _isLoading
                              ? null
                              : (_) => setState(() {
                                  _tab = tab;
                                  _error = null;
                                }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                BuddyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_tab == ReadingTab.type)
                        TextField(
                          controller: _textController,
                          minLines: 6,
                          maxLines: 16,
                          decoration: InputDecoration(
                            labelText: tr('Your text'),
                            hintText: tr('Type or paste here…'),
                          ),
                        ),
                      if (_tab == ReadingTab.scan) ...[
                        const LText(
                          'A clear, well-lit photo gives the best starting point.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _scanPage,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const LText('Scan a page (fixes tilt & shadows)'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const LText('Take a photo'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const LText('Choose an image'),
                        ),
                      ],
                      if (_tab == ReadingTab.upload) ...[
                        const LText(
                          'Choose a PDF or Word document from your device.',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _pickFile(extensions: ['pdf']),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const LText('Open PDF'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _pickFile(extensions: ['docx']),
                          icon: const Icon(Icons.description_outlined),
                          label: const LText('Open Word (.docx)'),
                        ),
                      ],
                      if (_pickedFile != null && _tab != ReadingTab.type) ...[
                        const SizedBox(height: 16),
                        Text(_pickedFileName ?? 'File selected'),
                        if (_prepared != null) ...[
                          SizedBox(
                            height: 230,
                            child: Image.file(
                              _pickedFile!,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (_prepared!.tip != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.tips_and_updates_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(child: LText(_prepared!.tip!)),
                                ],
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _imageEdit('rotate'),
                                child: const LText('Rotate 90° clockwise'),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _imageEdit('crop'),
                                child: const LText(
                                  'Select one column, paragraph or question',
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _imageEdit('reset'),
                                child: const LText('Reset crop'),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _imageEdit('enhance'),
                                child: Text(
                                  _enhance
                                      ? 'Use original colours'
                                      : 'Try grayscale + contrast (optional)',
                                ),
                              ),
                            ],
                          ),
                        ],
                        TextButton.icon(
                          onPressed: _isLoading ? null : _clearPick,
                          icon: const Icon(Icons.close),
                          label: const LText('Remove file'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                BuddyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        'Language of this reading',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                                  ('en', 'English'),
                                  ('hi', 'Hindi'),
                                  ('mr', 'Marathi'),
                                ]
                                .map(
                                  (l) => ChoiceChip(
                                    label: LText(l.$2),
                                    selected: _language == l.$1,
                                    onSelected: _isLoading
                                        ? null
                                        : (_) =>
                                              setState(() => _language = l.$1),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 12),
                      const LText(
                        'English uses Latin OCR. Hindi / Marathi use Devanagari OCR.',
                      ),
                      const LText(
                        'Original text only. No rewriting or simplification.',
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const LText(
                          'Medicine instructions, bill, receipt or form',
                        ),
                        value: _importantNumbers,
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(
                                () => _importantNumbers = v ?? false,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: LText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _onContinue,
                  icon: Icon(
                    _isLoading ? Icons.hourglass_top : Icons.arrow_forward,
                  ),
                  label: LText(
                    _isLoading
                        ? _stage
                        : (_prepared != null
                              ? 'Recognize text'
                              : 'Open my reading'),
                  ),
                ),
                if (_isLoading && _cancellation != null)
                  TextButton(
                    onPressed: () {
                      _cancellation!.cancel();
                      setState(
                        () => _stage =
                            'Stopping after the current page; completed pages are kept',
                      );
                    },
                    child: const LText('Cancel'),
                  ),
                for (final status in _pageStatuses) Text(status),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
