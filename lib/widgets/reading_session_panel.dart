import '../theme/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/buddy_store.dart';

class ReadingSessionPanel extends StatefulWidget {
  final String Function() text;
  const ReadingSessionPanel({super.key, required this.text});
  @override
  State<ReadingSessionPanel> createState() => _ReadingSessionPanelState();
}

class _ReadingSessionPanelState extends State<ReadingSessionPanel>
    with WidgetsBindingObserver {
  final _clock = Stopwatch();
  Timer? _ticker;
  String? _id, _day;
  int _words = 0;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _clock.isRunning) {
      _clock.stop();
      _ticker?.cancel();
      if (mounted) setState(() {});
    }
  }

  void _run() {
    if (_id == null) {
      final now = DateTime.now();
      _id = now.microsecondsSinceEpoch.toString();
      _day = BuddyStore.dayKey(now);
      _words = RegExp(r'\S+').allMatches(widget.text()).length;
    }
    _clock.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _finish() async {
    _clock.stop();
    _ticker?.cancel();
    if (_clock.elapsed.inSeconds == 0) {
      setState(() {
        _id = null;
        _clock.reset();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('Session ended. No reading time was recorded.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_clock.elapsed.inSeconds > 0) {
        await BuddyStore.addSession(
          ReadingSession(
            id: _id!,
            day: _day!,
            seconds: _clock.elapsed.inSeconds,
            words: _words,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _id = null;
          _clock.reset();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Reading session finished. Your progress is saved.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText(
              'Could not save your session. Tap Finish to try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _id == null
              ? 'Make a little time for reading'
              : 'Session: ${_clock.elapsed.inMinutes}:${(_clock.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const LText(
          'Tap a word for help. Finish before leaving to save your session.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => _clock.isRunning
                        ? setState(() {
                            _clock.stop();
                            _ticker?.cancel();
                          })
                        : _run(),
              icon: Icon(_clock.isRunning ? Icons.pause : Icons.timer_outlined),
              label: Text(
                _id == null
                    ? 'Start session'
                    : _clock.isRunning
                    ? 'Pause session'
                    : 'Resume session',
              ),
            ),
            if (_id != null)
              TextButton(
                onPressed: _saving ? null : _finish,
                child: Text(_saving ? 'Saving…' : 'Finish session'),
              ),
          ],
        ),
      ],
    ),
  );
}
