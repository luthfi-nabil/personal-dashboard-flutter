import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'remote_api.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._();
  ConfigService._();

  static const _key = 'pd-config-v1';
  static const _passKey = 'pd-saved-password-v1';
  AppConfig _current = const AppConfig();
  AppConfig get current => _current;

  final _listeners = <void Function()>[];
  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) _current = AppConfig.fromJson(raw);
  }

  Future<void> save(AppConfig cfg) async {
    _current = cfg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cfg.toJson());
    _notify();
  }

  Future<void> savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passKey, password);
  }

  Future<String?> _getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passKey);
  }

  /// Re-authenticates using stored credentials and saves the new token.
  /// Returns true if a fresh token was obtained, false otherwise.
  Future<bool> tryRefreshToken() async {
    final username = _current.username;
    final password = await _getSavedPassword();
    if (username.isEmpty || password == null || password.isEmpty) return false;
    try {
      final auth =
          await RemoteApi(_current).login(username: username, password: password);
      final expiresIn = (auth['expires_in'] as num?)?.toInt();
      final expiresAt = expiresIn == null || expiresIn <= 0
          ? ''
          : DateTime.now()
              .add(Duration(seconds: expiresIn))
              .toIso8601String();
      await save(_current.copyWith(
        authToken: auth['token'] as String? ?? '',
        tokenExpiresAt: expiresAt,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears the login-api session (JWT, user id) while keeping server URLs
  /// and app preferences (theme, currency, etc.) intact.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passKey);
    await save(_current.copyWith(
      authToken: '',
      tokenExpiresAt: '',
      userId: '',
    ));
  }
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
