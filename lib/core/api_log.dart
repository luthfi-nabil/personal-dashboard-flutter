import 'package:flutter/foundation.dart';

/// A single recorded call made via [RemoteApi], kept for the in-app
/// "API Watcher" screen so request/response status can be checked on-device
/// (e.g. on mobile, where the `developer.log` console isn't reachable).
class ApiCallEntry {
  final DateTime time;
  final String method;
  final Uri uri;
  final Duration duration;
  final int? statusCode;
  final String? error;
  final String? requestBody;
  final String? responseBody;

  const ApiCallEntry({
    required this.time,
    required this.method,
    required this.uri,
    required this.duration,
    this.statusCode,
    this.error,
    this.requestBody,
    this.responseBody,
  });

  bool get isOk => error == null && statusCode != null && statusCode! < 400;
}

/// In-memory log of recent API calls, newest first.
class ApiCallLog extends ChangeNotifier {
  ApiCallLog._();
  static final instance = ApiCallLog._();

  static const _maxEntries = 200;

  final List<ApiCallEntry> _entries = [];
  List<ApiCallEntry> get entries => List.unmodifiable(_entries);

  void add(ApiCallEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
