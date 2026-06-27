import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/config.dart';
import '../core/sync.dart';

// ── App data ────────────────────────────────────────────────────────────────
class AppDataNotifier extends AutoDisposeAsyncNotifier<AppData> {
  @override
  Future<AppData> build() async {
    // Rebuild the cached/remote data view whenever the active account
    // changes. Without this dependency, the provider survives logout/login
    // and can keep showing the previous user's AppData.
    ref.watch(configProvider.select((cfg) => cfg.userId));
    SyncService.instance.onRefresh = refreshRemote;
    ref.onDispose(() => SyncService.instance.onRefresh = null);
    final cached = await Repo.instance.cached();
    unawaited(SyncService.instance.syncNow());
    return cached;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => Repo.instance.cached());
    await SyncService.instance.syncNow();
  }

  Future<void> refreshRemote() async {
    final remote = await Repo.instance.refreshRemote();
    if (remote != null) {
      state = AsyncValue.data(remote);
    }
  }
}

final appDataProvider =
    AsyncNotifierProvider.autoDispose<AppDataNotifier, AppData>(
  AppDataNotifier.new,
);

// ── Config ───────────────────────────────────────────────────────────────────
class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    ConfigService.instance.addListener(_onExternalChange);
    ref.onDispose(
        () => ConfigService.instance.removeListener(_onExternalChange));
    return ConfigService.instance.current;
  }

  /// Keeps this provider in sync when [ConfigService] is updated directly
  /// (e.g. [ConfigService.logout] called from [Repo] after a `401`).
  void _onExternalChange() {
    state = ConfigService.instance.current;
  }

  Future<void> update(AppConfig cfg) async {
    await ConfigService.instance.save(cfg);
    state = cfg;
  }
}

final configProvider =
    NotifierProvider<ConfigNotifier, AppConfig>(ConfigNotifier.new);

// ── Sync status ───────────────────────────────────────────────────────────────
final StateProvider<SyncStatus> syncStatusProvider =
    StateProvider<SyncStatus>((ref) {
  SyncService.instance.addListener((s) {
    ref.read(syncStatusProvider.notifier).state = s;
  });
  return SyncService.instance.status;
});

/// Number of records saved locally because the API was unreachable
/// ("local mode") and not yet pushed to the server.
final StateProvider<int> pendingSyncCountProvider = StateProvider<int>((ref) {
  SyncService.instance.addPendingListener((count) {
    ref.read(pendingSyncCountProvider.notifier).state = count;
  });
  return SyncService.instance.pendingCount;
});
