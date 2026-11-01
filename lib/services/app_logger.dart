import 'dart:collection';
import 'package:flutter/foundation.dart';

class AppLogEntry {
  final DateTime time;
  final String message;
  AppLogEntry(this.time, this.message);
}

/// In-memory app-wide log, shown on the Diagnostics screen's "App Log" tab.
/// Not persisted across app restarts by design (matches the backend's
/// Live Log, which is also in-memory/troubleshooting-only).
class AppLogger extends ChangeNotifier {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int maxEntries = 300;
  final Queue<AppLogEntry> _entries = ListQueue<AppLogEntry>();

  List<AppLogEntry> get entries => _entries.toList().reversed.toList();

  void log(String message) {
    _entries.add(AppLogEntry(DateTime.now(), message));
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    notifyListeners();
    debugPrint('[ISENS] $message');
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
