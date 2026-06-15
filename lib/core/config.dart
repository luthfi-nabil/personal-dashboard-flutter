import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._();
  ConfigService._();

  static const _key = 'pd-config-v1';
  AppConfig _current = const AppConfig();
  AppConfig get current => _current;

  final _listeners = <void Function()>[];
  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() { for (final l in _listeners) l(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) _current = AppConfig.fromJson(raw);
    // Drop a stale login-api JWT so the user is sent back to /login.
    if (_current.authToken.isNotEmpty && _current.isTokenExpired) {
      _current = _current.copyWith(authToken: '', tokenExpiresAt: '', userId: '');
      await prefs.setString(_key, _current.toJson());
    }
  }

  Future<void> save(AppConfig cfg) async {
    _current = cfg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cfg.toJson());
    _notify();
  }

  /// Clears the login-api session (JWT, user id) while keeping server URLs
  /// and app preferences (theme, currency, etc.) intact.
  Future<void> logout() => save(_current.copyWith(
        authToken: '',
        tokenExpiresAt: '',
        userId: '',
      ));
}

/// Bridges [ConfigService]'s listener callbacks to a [ChangeNotifier] so
/// `go_router` can be told to re-run its `redirect` whenever the login
/// session changes (e.g. after login or logout).
class ConfigListenable extends ChangeNotifier {
  ConfigListenable() {
    ConfigService.instance.addListener(notifyListeners);
  }

  @override
  void dispose() {
    ConfigService.instance.removeListener(notifyListeners);
    super.dispose();
  }
}
