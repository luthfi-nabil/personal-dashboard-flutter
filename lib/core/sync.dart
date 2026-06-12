import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'config.dart';

enum SyncStatus { idle, syncing, done, error }

/// Tracks connectivity and periodically asks the app to refresh data from
/// transaction-api / health-api. There is no local write queue - the APIs
/// only support create/delete, so writes go straight through and the app
/// just re-fetches afterwards.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _online = true;
  bool get isOnline => _online;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  /// Set by the app (typically `appDataProvider`'s notifier) to refresh
  /// cached data. Safe to call repeatedly; errors are reported via [status].
  Future<void> Function()? onRefresh;

  final _listeners = <void Function(SyncStatus)>[];
  void addListener(void Function(SyncStatus) l) => _listeners.add(l);
  void removeListener(void Function(SyncStatus) l) => _listeners.remove(l);
  void _emit(SyncStatus s) {
    _status = s;
    for (final l in _listeners) l(s);
  }

  Future<void> start() async {
    final results = await Connectivity().checkConnectivity();
    _online = results.any((r) => r != ConnectivityResult.none);

    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _online;
      _online = results.any((r) => r != ConnectivityResult.none);
      if (!wasOnline && _online) syncNow();
    });

    ConfigService.instance.addListener(_restartTimer);
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final cfg = ConfigService.instance.current;
    if (!cfg.isConfigured || !cfg.autoSync) return;
    _timer = Timer.periodic(Duration(seconds: cfg.syncIntervalSec), (_) {
      if (_online) syncNow();
    });
  }

  Future<void> syncNow() async {
    if (_status == SyncStatus.syncing) return;
    final cfg = ConfigService.instance.current;
    if (!cfg.isConfigured || !_online) return;

    _emit(SyncStatus.syncing);
    try {
      await onRefresh?.call();
      _emit(SyncStatus.done);
    } catch (_) {
      _emit(SyncStatus.error);
    }
  }

  void dispose() {
    _timer?.cancel();
    _connSub?.cancel();
    ConfigService.instance.removeListener(_restartTimer);
  }
}
