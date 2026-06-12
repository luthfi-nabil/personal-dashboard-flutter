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
  }

  Future<void> save(AppConfig cfg) async {
    _current = cfg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cfg.toJson());
    _notify();
  }
}
