import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/config.dart';
import '../core/sync.dart';

// ── App data ────────────────────────────────────────────────────────────────
class AppDataNotifier extends AsyncNotifier<AppData> {
  @override
  Future<AppData> build() {
    SyncService.instance.onRefresh = refresh;
    return Repo.instance.all();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => Repo.instance.all());
  }
}

final appDataProvider =
    AsyncNotifierProvider<AppDataNotifier, AppData>(AppDataNotifier.new);

// ── Config ───────────────────────────────────────────────────────────────────
class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() => ConfigService.instance.current;

  Future<void> update(AppConfig cfg) async {
    await ConfigService.instance.save(cfg);
    state = cfg;
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(ConfigNotifier.new);

// ── Sync status ───────────────────────────────────────────────────────────────
final StateProvider<SyncStatus> syncStatusProvider = StateProvider<SyncStatus>((ref) {
  SyncService.instance.addListener((s) {
    ref.read(syncStatusProvider.notifier).state = s;
  });
  return SyncService.instance.status;
});
