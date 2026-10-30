import '../theme/app_localizations.dart';
import 'package:flutter/material.dart';
import 'reader_screen.dart';

class EnterTextScreen extends StatefulWidget {
  const EnterTextScreen({super.key});

  @override
  State<EnterTextScreen> createState() => _EnterTextScreenState();
}

class _EnterTextScreenState extends State<EnterTextScreen> with LanguageRebuild<EnterTextScreen> {
  final TextEditingController controller = TextEditingController();

  static const blueGradient = [Color(0xFF1565C0), Color(0xFF42A5F5)];

  static const creamGradient = [Color(0xFFFFF3E0), Color(0xFFFFE0B2)];

  /// ✅ GREEN GRADIENT (FIXED)
  static const greenGradient = [
    Color(0xFF43A047), // dark green
    Color(0xFF81C784), // light green
  ];

  void openReader() {
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText("Please enter some text first")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialText: controller.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 🔥 APP BAR (CREAM + BLUE TEXT)
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: creamGradient),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              const LinearGradient(colors: blueGradient).createShader(bounds),
          child: const LText(
            "Enter Text",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),

      /// 🔥 BODY
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// TEXT INPUT
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "Type or paste text here...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔥 GREEN GRADIENT BUTTON
            InkWell(
              onTap: openReader,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: greenGradient),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: LText(
                    "Simplify Text",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      /// 🔥 BOTTOM NAV STRIP (CREAM)
      bottomNavigationBar: Container(
        height: 10,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: creamGradient),
        ),
      ),
    );
  }
}
