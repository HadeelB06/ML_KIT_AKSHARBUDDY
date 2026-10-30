import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_item.dart';

/// Single source of truth for saved readings.
///
/// The in-memory list is the authoritative source at runtime; SharedPreferences
/// is the persistence layer. All mutating methods update the list synchronously
/// so callers see the change immediately, then fire-and-forget a background
/// write so the existing synchronous call-sites (e.g. OutputScreen) need no
/// changes.
class LibraryStorage {
  static String? _lastOpened;
  static List<LibraryItem> continueReading() {
    if (_items.isEmpty) return [];
    return [
      _items.firstWhere(
        (i) => i.date.toIso8601String() == _lastOpened,
        orElse: () => _items.first,
      ),
    ];
  }

  static Future<void> markOpened(String id) async {
    _lastOpened = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_opened_reading', id);
  }

  static const _key = 'aksharally_library';

  static final List<LibraryItem> _items = [];

  // ── startup ───────────────────────────────────────────────────────────────

  /// Call once before runApp() to hydrate the in-memory list from disk.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lastOpened = prefs.getString('last_opened_reading');
    final raw = prefs.getStringList(_key) ?? [];
    _items.clear();
    for (final s in raw) {
      try {
        _items.add(LibraryItem.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip any malformed entry rather than crashing.
      }
    }
  }

  // ── read ──────────────────────────────────────────────────────────────────

  /// Returns items in newest-first order (maintained by addItem's insert(0)).
  static List<LibraryItem> getItems() => List.unmodifiable(_items);

  // ── write ─────────────────────────────────────────────────────────────────

  /// Inserts at position 0 (newest-first) and persists in the background.
  static void addItem(LibraryItem item) {
    _items.insert(0, item);
    _persist();
  }

  /// Removes the item at [index] and persists in the background.
  static void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _persist();
  }

  /// Removes all items and persists in the background.
  static void clearAll() {
    _items.clear();
    _persist();
  }

  // ── persistence ───────────────────────────────────────────────────────────

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
