import 'package:uuid/uuid.dart';
import 'db.dart';
import 'config.dart';
import 'models.dart';
import 'remote_api.dart';
import 'sync.dart';

const _uuid = Uuid();

/// Online-first data layer. When configured (a username is set) and online,
/// reads go straight to transaction-api / health-api and the result is
/// cached locally; otherwise (offline, or not yet configured) cached/seeded
/// data from SQLite is used.
///
/// Writes go straight to the REST APIs. If a write fails because the API is
/// unreachable ([ApiUnavailableException] - timeout or connection failure),
/// the transaction is saved locally with `syncState: 'pending'` ("local
/// mode") and [syncPendingTransactions] retries it once the API is reachable
/// again (see [SyncService]).
class Repo {
  static final Repo instance = Repo._();
  Repo._();

  String _nowIso() => DateTime.now().toIso8601String();

  AppConfig get _cfg => ConfigService.instance.current;

  /// Scopes the local SQLite cache to the signed-in user. An empty string
  /// (logged out) maps to the seeded/demo data set.
  String get _userId => _cfg.userId;

  // ── Aggregate read ───────────────────────────────────────────────────
  Future<AppData> all() async {
    final cfg = _cfg;
    if (cfg.isLoggedIn && SyncService.instance.isOnline) {
      try {
        final data = await _fetchRemote(cfg);
        await _cacheRemote(data, cfg.userId);
        return _withPending(data, cfg.userId);
      } on ApiUnauthorizedException {
        // The JWT is missing/expired - sign out so the UI routes to /login.
        await ConfigService.instance.logout();
      } catch (_) {
        // fall back to local cache below
      }
    }
    return _fromCache(cfg.userId);
  }

  /// Merges transactions still queued in "local mode" into freshly-fetched
  /// remote [data] so they remain visible until [syncPendingTransactions]
  /// pushes them.
  Future<AppData> _withPending(AppData data, String userId) async {
    final results = await Future.wait([
      AppDb.instance.getPendingTransactions(userId),
      AppDb.instance.getPendingInsulinItems(userId),
      AppDb.instance.getPendingInsulinAssigns(userId),
      AppDb.instance.getPendingInsulinUsages(userId),
      AppDb.instance.getPendingBloodSugarLogs(userId),
    ]);
    final pendingTransactions = results[0] as List<Transaction>;
    final pendingInsulinItems = results[1] as List<InsulinItem>;
    final pendingInsulinAssigns = results[2] as List<InsulinAssign>;
    final pendingInsulinUsages = results[3] as List<InsulinUsage>;
    final pendingBloodSugarLogs = results[4] as List<BloodSugarLog>;
    if (results.every((rows) => rows.isEmpty)) return data;

    List<T> mergePending<T>(
      List<T> pending,
      List<T> current,
      String Function(T item) idOf,
    ) {
      final pendingIds = pending.map(idOf).toSet();
      return [
        ...pending,
        ...current.where((item) => !pendingIds.contains(idOf(item))),
      ];
    }

    final transactions = mergePending(
      pendingTransactions,
      data.transactions,
      (transaction) => transaction.id,
    )..sort((a, b) => b.date.compareTo(a.date));
    final insulinItems = mergePending(
      pendingInsulinItems,
      data.insulinItems,
      (item) => item.id,
    );
    final insulinAssigns = mergePending(
      pendingInsulinAssigns,
      data.insulinAssigns,
      (assign) => assign.id,
    );
    final insulinUsages = mergePending(
      pendingInsulinUsages,
      data.insulinUsages,
      (usage) => usage.id,
    )..sort((a, b) => b.date.compareTo(a.date));
    final bloodSugarLogs = mergePending(
      pendingBloodSugarLogs,
      data.bloodSugarLogs,
      (log) => log.id,
    )..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return AppData(
      sources: data.sources,
      categories: data.categories,
      transactions: transactions,
      insulinItems: insulinItems,
      insulinAssigns: insulinAssigns,
      insulinUsages: insulinUsages,
      bloodSugarLogs: bloodSugarLogs,
    );
  }

  Future<AppData> _fromCache(String userId) async {
    final results = await Future.wait([
      AppDb.instance.getSources(userId),
      AppDb.instance.getCategories(userId),
      AppDb.instance.getTransactions(userId),
      AppDb.instance.getInsulinItems(userId),
      AppDb.instance.getInsulinAssigns(userId),
      AppDb.instance.getInsulinUsages(userId),
      AppDb.instance.getBloodSugarLogs(userId),
    ]);
    return AppData(
      sources: results[0] as List<Source>,
      categories: results[1] as List<Category>,
      transactions: results[2] as List<Transaction>,
      insulinItems: results[3] as List<InsulinItem>,
      insulinAssigns: results[4] as List<InsulinAssign>,
      insulinUsages: results[5] as List<InsulinUsage>,
      bloodSugarLogs: results[6] as List<BloodSugarLog>,
    );
  }

  Future<AppData> _fetchRemote(AppConfig cfg) async {
    final api = RemoteApi(cfg);

    final results = await Future.wait([
      api.getSources(),
      api.getEarningCategories(),
      api.getSpendingCategories(),
      api.getEarnings(),
      api.getSpendings(),
    ]);
    final rawSources = results[0];
    final rawEarningCats = results[1];
    final rawSpendingCats = results[2];
    final rawEarnings = results[3];
    final rawSpendings = results[4];

    String? transferCategoryName;
    try {
      for (final s in await api.getSettings()) {
        if (s['app_setting_key'] == 'TRANSFER_CATEGORY_NAME') {
          transferCategoryName = s['app_setting_value'] as String?;
        }
      }
    } catch (_) {
      // transfer pairing is best-effort
    }

    final existingKinds = {
      for (final s in await AppDb.instance.getSources(cfg.userId)) s.id: s.kind,
    };

    final sources = rawSources.map((m) {
      final id = m['source_id'] as String;
      return Source(
        id: id,
        name: m['source'] as String,
        kind: existingKinds[id] ?? 'cash',
        syncState: 'synced',
        updatedAt: (m['created_date'] ?? _nowIso()).toString(),
      );
    }).toList();

    final categories = <Category>[
      ...rawEarningCats.map((m) => Category(
            id: m['earning_category_id'] as String,
            name: m['earning_category'] as String,
            kind: 'earning',
            syncState: 'synced',
            updatedAt: (m['created_date'] ?? _nowIso()).toString(),
          )),
      ...rawSpendingCats.map((m) => Category(
            id: m['spending_category_id'] as String,
            name: m['spending_category'] as String,
            kind: 'spending',
            syncState: 'synced',
            updatedAt: (m['created_date'] ?? _nowIso()).toString(),
          )),
    ];

    final transactions =
        _pairTransfers(rawEarnings, rawSpendings, transferCategoryName);

    var insulinItems = <InsulinItem>[];
    var insulinAssigns = <InsulinAssign>[];
    var insulinUsages = <InsulinUsage>[];
    var bloodSugarLogs = <BloodSugarLog>[];
    var healthFetched = false;
    try {
      final healthResults = await Future.wait([
        api.getInsulinItems(),
        api.getInsulinAssignUsage(),
        api.getInsulinUsages(),
        api.getBloodSugarLogs(),
      ]);
      insulinItems = healthResults[0].map(InsulinItem.fromMap).toList();
      insulinAssigns = healthResults[1].map(InsulinAssign.fromMap).toList();
      insulinUsages = healthResults[2].map(InsulinUsage.fromMap).toList();
      bloodSugarLogs = healthResults[3].map(BloodSugarLog.fromMap).toList();
      healthFetched = true;
    } catch (_) {
      // health-api may be unreachable independently of transaction-api
    }
    if (!healthFetched) {
      insulinItems = await AppDb.instance.getInsulinItems(cfg.userId);
      insulinAssigns = await AppDb.instance.getInsulinAssigns(cfg.userId);
      insulinUsages = await AppDb.instance.getInsulinUsages(cfg.userId);
      bloodSugarLogs = await AppDb.instance.getBloodSugarLogs(cfg.userId);
    }

    return AppData(
      sources: sources,
      categories: categories,
      transactions: transactions,
      insulinItems: insulinItems,
      insulinAssigns: insulinAssigns,
      insulinUsages: insulinUsages,
      bloodSugarLogs: bloodSugarLogs,
    );
  }

  /// Earnings/spendings tagged with the "Transfer" category are recombined
  /// into a single `Transaction(type: 'transfer')` when a matching
  /// description+amount pair is found, so balances/cashflow charts (which
  /// special-case `type == 'transfer'`) behave the same as with seed data.
  List<Transaction> _pairTransfers(
    List<Map<String, dynamic>> earnings,
    List<Map<String, dynamic>> spendings,
    String? transferCategoryName,
  ) {
    final txns = <Transaction>[];
    final usedEarnings = <int>{};
    final usedSpendings = <int>{};

    if (transferCategoryName != null) {
      for (var si = 0; si < spendings.length; si++) {
        final s = spendings[si];
        if (s['spending_category'] != transferCategoryName) continue;

        int? bestIdx;
        Duration? bestDiff;
        for (var ei = 0; ei < earnings.length; ei++) {
          if (usedEarnings.contains(ei)) continue;
          final e = earnings[ei];
          if (e['earning_category'] != transferCategoryName) continue;
          if ((e['total_amount'] as num).toDouble() !=
              (s['total_amount'] as num).toDouble()) continue;
          if (e['description'] != s['description']) continue;
          final ed = DateTime.tryParse(e['created_date']?.toString() ?? '');
          final sd = DateTime.tryParse(s['created_date']?.toString() ?? '');
          final diff = (ed != null && sd != null)
              ? ed.difference(sd).abs()
              : Duration.zero;
          if (bestDiff == null || diff < bestDiff) {
            bestDiff = diff;
            bestIdx = ei;
          }
        }

        if (bestIdx != null) {
          final e = earnings[bestIdx];
          usedSpendings.add(si);
          usedEarnings.add(bestIdx);
          txns.add(Transaction(
            id: '${s['spending_id']}_${e['earning_id']}',
            type: 'transfer',
            amount: (s['total_amount'] as num).toDouble(),
            description: s['description'] as String? ?? '',
            fromSource: s['source'] as String?,
            toSource: e['source'] as String?,
            date: (s['created_date'] ?? _nowIso()).toString(),
            syncState: 'synced',
            updatedAt: (s['created_date'] ?? _nowIso()).toString(),
          ));
        }
      }
    }

    for (var i = 0; i < earnings.length; i++) {
      if (usedEarnings.contains(i)) continue;
      final e = earnings[i];
      txns.add(Transaction(
        id: e['earning_id'] as String,
        type: 'earning',
        amount: (e['total_amount'] as num).toDouble(),
        description: e['description'] as String? ?? '',
        category: e['earning_category'] as String?,
        source: e['source'] as String?,
        date: (e['created_date'] ?? _nowIso()).toString(),
        syncState: 'synced',
        updatedAt: (e['created_date'] ?? _nowIso()).toString(),
      ));
    }
    for (var i = 0; i < spendings.length; i++) {
      if (usedSpendings.contains(i)) continue;
      final s = spendings[i];
      txns.add(Transaction(
        id: s['spending_id'] as String,
        type: 'spending',
        amount: (s['total_amount'] as num).toDouble(),
        description: s['description'] as String? ?? '',
        category: s['spending_category'] as String?,
        source: s['source'] as String?,
        date: (s['created_date'] ?? _nowIso()).toString(),
        syncState: 'synced',
        updatedAt: (s['created_date'] ?? _nowIso()).toString(),
      ));
    }

    txns.sort((a, b) => b.date.compareTo(a.date));
    return txns;
  }

  Future<void> _cacheRemote(AppData data, String userId) async {
    await AppDb.instance.replaceSources(data.sources, userId);
    await AppDb.instance.replaceCategories(data.categories, userId);
    await AppDb.instance.replaceTransactions(data.transactions, userId);
    await AppDb.instance.replaceInsulinItems(data.insulinItems, userId);
    await AppDb.instance.replaceInsulinAssigns(data.insulinAssigns, userId);
    await AppDb.instance.replaceInsulinUsages(data.insulinUsages, userId);
    await AppDb.instance.replaceBloodSugarLogs(data.bloodSugarLogs, userId);
    await AppDb.instance.setMeta('lastSync', _nowIso());
  }

  // ── Sources ──────────────────────────────────────────────────────────
  Future<Source> createSource(String name, {String kind = 'cash'}) async {
    final m = await RemoteApi(_cfg).createSource(name);
    return Source(
      id: m['source_id'] as String,
      name: m['source'] as String,
      kind: kind,
      syncState: 'synced',
      updatedAt: _nowIso(),
    );
  }

  Future<void> deleteSource(String id) => RemoteApi(_cfg).deleteSource(id);

  // ── Categories ───────────────────────────────────────────────────────
  Future<Category> createCategory(
      {required String name, required String kind}) async {
    final api = RemoteApi(_cfg);
    final m = kind == 'earning'
        ? await api.createEarningCategory(name)
        : await api.createSpendingCategory(name);
    return Category(
      id: (m['earning_category_id'] ?? m['spending_category_id']) as String,
      name: (m['earning_category'] ?? m['spending_category']) as String,
      kind: kind,
      syncState: 'synced',
      updatedAt: _nowIso(),
    );
  }

  Future<void> deleteCategory({required String id, required String kind}) {
    final api = RemoteApi(_cfg);
    return kind == 'earning'
        ? api.deleteEarningCategory(id)
        : api.deleteSpendingCategory(id);
  }

  // ── Transactions (create-only; the APIs have no edit/delete) ─────────
  //
  // Each `createXxx` returns `true` if the API was unreachable and the
  // transaction was queued locally ("local mode"), or `false` if it was
  // sent to the server immediately. Other failures (e.g. validation errors
  // from a reachable server) are thrown as [ApiException] as before.

  Future<bool> createEarning({
    required double amount,
    required String description,
    required Category category,
    required Source source,
  }) async {
    try {
      await RemoteApi(_cfg).createEarning(
        totalAmount: amount,
        description: description,
        earningCategoryId: category.id,
        earningCategory: category.name,
        sourceId: source.id,
        source: source.name,
      );
      return false;
    } on ApiUnavailableException {
      await _queuePending(Transaction(
        id: _uuid.v4(),
        type: 'earning',
        amount: amount,
        description: description,
        category: category.name,
        source: source.name,
        date: _nowIso(),
        syncState: 'pending',
        updatedAt: _nowIso(),
      ));
      return true;
    }
  }

  Future<bool> createSpending({
    required double amount,
    required String description,
    required Category category,
    required Source source,
  }) async {
    try {
      await RemoteApi(_cfg).createSpending(
        totalAmount: amount,
        description: description,
        spendingCategoryId: category.id,
        spendingCategory: category.name,
        sourceId: source.id,
        source: source.name,
      );
      return false;
    } on ApiUnavailableException {
      await _queuePending(Transaction(
        id: _uuid.v4(),
        type: 'spending',
        amount: amount,
        description: description,
        category: category.name,
        source: source.name,
        date: _nowIso(),
        syncState: 'pending',
        updatedAt: _nowIso(),
      ));
      return true;
    }
  }

  /// Creates a transfer as a paired spending (fromSource) + earning
  /// (toSource), both tagged with the server's configured Transfer category.
  Future<bool> createTransfer({
    required double amount,
    required String description,
    required Source fromSource,
    required Source toSource,
  }) async {
    try {
      final remote = RemoteApi(_cfg);
      final settings = await remote.getSettings();
      String catId = '';
      String catName = 'Transfer';
      for (final s in settings) {
        if (s['app_setting_key'] == 'TRANSFER_CATEGORY_ID')
          catId = s['app_setting_value'] as String? ?? '';
        if (s['app_setting_key'] == 'TRANSFER_CATEGORY_NAME')
          catName = s['app_setting_value'] as String? ?? catName;
      }
      if (catId.isEmpty) {
        throw const ApiException(
            'Transfer category is not configured on the server.');
      }
      await remote.createSpending(
        totalAmount: amount,
        description: description,
        spendingCategoryId: catId,
        spendingCategory: catName,
        sourceId: fromSource.id,
        source: fromSource.name,
      );
      await remote.createEarning(
        totalAmount: amount,
        description: description,
        earningCategoryId: catId,
        earningCategory: catName,
        sourceId: toSource.id,
        source: toSource.name,
      );
      return false;
    } on ApiUnavailableException {
      await _queuePending(Transaction(
        id: _uuid.v4(),
        type: 'transfer',
        amount: amount,
        description: description,
        fromSource: fromSource.name,
        toSource: toSource.name,
        date: _nowIso(),
        syncState: 'pending',
        updatedAt: _nowIso(),
      ));
      return true;
    }
  }

  Future<void> _queuePending(Transaction t) async {
    await AppDb.instance.putTransaction(t, _userId);
    await _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final pending = await AppDb.instance.getPendingWriteCount(_userId);
    SyncService.instance.updatePendingCount(pending);
  }

  /// Retries transactions queued while in "local mode". Stops at the first
  /// [ApiUnavailableException] (the API is still unreachable) and leaves the
  /// rest queued for the next sync; other errors (e.g. a category/source
  /// that no longer exists) are skipped so one bad entry can't block the
  /// rest. Successfully-sent entries are removed from the local queue - the
  /// follow-up `onRefresh` (triggered by [SyncService]) re-fetches them from
  /// the server with their real ids.
  Future<void> syncPendingTransactions() async {
    final cfg = _cfg;
    final pending = await AppDb.instance.getPendingTransactions(cfg.userId);
    if (pending.isEmpty) {
      SyncService.instance.updatePendingCount(
          await AppDb.instance.getPendingWriteCount(cfg.userId));
      return;
    }

    final remote = RemoteApi(cfg);
    final sources = await AppDb.instance.getSources(cfg.userId);
    final categories = await AppDb.instance.getCategories(cfg.userId);

    for (final t in pending) {
      try {
        switch (t.type) {
          case 'earning':
            final cat = categories
                .firstWhere((c) => c.kind == 'earning' && c.name == t.category);
            final src = sources.firstWhere((s) => s.name == t.source);
            await remote.createEarning(
              totalAmount: t.amount,
              description: t.description,
              earningCategoryId: cat.id,
              earningCategory: cat.name,
              sourceId: src.id,
              source: src.name,
            );
            break;
          case 'spending':
            final cat = categories.firstWhere(
                (c) => c.kind == 'spending' && c.name == t.category);
            final src = sources.firstWhere((s) => s.name == t.source);
            await remote.createSpending(
              totalAmount: t.amount,
              description: t.description,
              spendingCategoryId: cat.id,
              spendingCategory: cat.name,
              sourceId: src.id,
              source: src.name,
            );
            break;
          case 'transfer':
            final from = sources.firstWhere((s) => s.name == t.fromSource);
            final to = sources.firstWhere((s) => s.name == t.toSource);
            final settings = await remote.getSettings();
            String catId = '';
            String catName = 'Transfer';
            for (final s in settings) {
              if (s['app_setting_key'] == 'TRANSFER_CATEGORY_ID')
                catId = s['app_setting_value'] as String? ?? '';
              if (s['app_setting_key'] == 'TRANSFER_CATEGORY_NAME')
                catName = s['app_setting_value'] as String? ?? catName;
            }
            if (catId.isEmpty) {
              throw const ApiException(
                  'Transfer category is not configured on the server.');
            }
            await remote.createSpending(
              totalAmount: t.amount,
              description: t.description,
              spendingCategoryId: catId,
              spendingCategory: catName,
              sourceId: from.id,
              source: from.name,
            );
            await remote.createEarning(
              totalAmount: t.amount,
              description: t.description,
              earningCategoryId: catId,
              earningCategory: catName,
              sourceId: to.id,
              source: to.name,
            );
            break;
        }
        await AppDb.instance.deleteTransaction(t.id, cfg.userId);
      } on ApiUnavailableException {
        break;
      } catch (_) {
        // Leave this entry queued and move on to the next.
      }
    }

    SyncService.instance.updatePendingCount(
        await AppDb.instance.getPendingWriteCount(cfg.userId));
  }

  // ── Insulin ──────────────────────────────────────────────────────────
  Future<InsulinItem> createInsulinItem({
    required String name,
    required double units,
    required String uom,
    String? notes,
  }) async {
    try {
      final m = await RemoteApi(_cfg)
          .createInsulinItem(name: name, units: units, uom: uom, notes: notes);
      final item = InsulinItem.fromMap(m);
      await AppDb.instance.putInsulinItem(item, _userId);
      return item;
    } on ApiUnavailableException {
      final item = InsulinItem(
        id: _uuid.v4(),
        name: name,
        units: units,
        uom: uom,
        date: _nowIso(),
        notes: notes,
        syncState: 'pending',
      );
      await AppDb.instance.putInsulinItem(item, _userId);
      await _refreshPendingCount();
      return item;
    }
  }

  Future<InsulinAssign> createInsulinAssign({
    required String itemId,
    required String batchNo,
    String? notes,
  }) async {
    try {
      final m = await RemoteApi(_cfg).createInsulinAssign(
          insulinItemId: itemId, batchNo: batchNo, notes: notes);
      final assign = InsulinAssign.fromMap(m);
      await AppDb.instance.putInsulinAssign(assign, _userId);
      return assign;
    } on ApiUnavailableException {
      final item = await _cachedInsulinItem(itemId);
      final assign = InsulinAssign(
        id: _uuid.v4(),
        itemId: itemId,
        batchNo: batchNo,
        date: _nowIso(),
        itemName: item?.name ?? '',
        totalUnits: item?.units ?? 0,
        notes: notes,
        syncState: 'pending',
      );
      await AppDb.instance.putInsulinAssign(assign, _userId);
      await _refreshPendingCount();
      return assign;
    }
  }

  Future<void> deleteInsulinAssign(String id) =>
      RemoteApi(_cfg).deleteInsulinAssign(id);

  Future<InsulinUsage> logInsulinUsage({
    required String assignId,
    required double units,
    String? notes,
  }) async {
    try {
      final m = await RemoteApi(_cfg).createInsulinUsage(
          insulinAssignId: assignId, units: units, notes: notes);
      final usage = InsulinUsage.fromMap(m);
      await AppDb.instance.putInsulinUsage(usage, _userId);
      return usage;
    } on ApiUnavailableException {
      final usage = InsulinUsage(
        id: _uuid.v4(),
        assignId: assignId,
        units: units,
        date: _nowIso(),
        notes: notes,
        syncState: 'pending',
      );
      await AppDb.instance.putInsulinUsage(usage, _userId);
      await _refreshPendingCount();
      return usage;
    }
  }

  Future<BloodSugarLog> logBloodSugar({
    required double level,
    String unit = 'mg/dL',
    String? mealContext,
    String? notes,
  }) async {
    try {
      final m = await RemoteApi(_cfg).createBloodSugarLog(
        level: level,
        unit: unit,
        mealContext: mealContext,
        notes: notes,
      );
      final log = BloodSugarLog.fromMap(m);
      await AppDb.instance.putBloodSugarLog(log, _userId);
      return log;
    } on ApiUnavailableException {
      final log = BloodSugarLog(
        id: _uuid.v4(),
        level: level,
        unit: unit,
        measuredAt: _nowIso(),
        mealContext: mealContext,
        notes: notes,
        syncState: 'pending',
      );
      await AppDb.instance.putBloodSugarLog(log, _userId);
      await _refreshPendingCount();
      return log;
    }
  }

  Future<void> syncPendingHealthWrites() async {
    final cfg = _cfg;
    final remote = RemoteApi(cfg);
    final itemIdMap = <String, String>{};
    final assignIdMap = <String, String>{};

    for (final item
        in await AppDb.instance.getPendingInsulinItems(cfg.userId)) {
      try {
        final m = await remote.createInsulinItem(
          name: item.name,
          units: item.units,
          uom: item.uom,
          notes: item.notes,
        );
        final synced = InsulinItem.fromMap(m);
        itemIdMap[item.id] = synced.id;
        await AppDb.instance.deleteInsulinItem(item.id, cfg.userId);
        await AppDb.instance.putInsulinItem(synced, cfg.userId);
      } on ApiUnavailableException {
        break;
      } catch (_) {
        // Keep the pending row for a later retry.
      }
    }

    final unresolvedItems = {
      for (final item
          in await AppDb.instance.getPendingInsulinItems(cfg.userId))
        item.id
    };
    for (final assign
        in await AppDb.instance.getPendingInsulinAssigns(cfg.userId)) {
      final itemId = itemIdMap[assign.itemId] ?? assign.itemId;
      if (unresolvedItems.contains(itemId)) continue;
      try {
        final m = await remote.createInsulinAssign(
          insulinItemId: itemId,
          batchNo: assign.batchNo,
          notes: assign.notes,
        );
        final synced = InsulinAssign.fromMap(m);
        assignIdMap[assign.id] = synced.id;
        await AppDb.instance.deleteInsulinAssign(assign.id, cfg.userId);
        await AppDb.instance.putInsulinAssign(synced, cfg.userId);
      } on ApiUnavailableException {
        break;
      } catch (_) {
        // Keep the pending row for a later retry.
      }
    }

    final unresolvedAssigns = {
      for (final assign
          in await AppDb.instance.getPendingInsulinAssigns(cfg.userId))
        assign.id
    };
    for (final usage
        in await AppDb.instance.getPendingInsulinUsages(cfg.userId)) {
      final assignId = assignIdMap[usage.assignId] ?? usage.assignId;
      if (unresolvedAssigns.contains(assignId)) continue;
      try {
        final m = await remote.createInsulinUsage(
          insulinAssignId: assignId,
          units: usage.units,
          notes: usage.notes,
        );
        final synced = InsulinUsage.fromMap(m);
        await AppDb.instance.deleteInsulinUsage(usage.id, cfg.userId);
        await AppDb.instance.putInsulinUsage(synced, cfg.userId);
      } on ApiUnavailableException {
        break;
      } catch (_) {
        // Keep the pending row for a later retry.
      }
    }

    for (final log
        in await AppDb.instance.getPendingBloodSugarLogs(cfg.userId)) {
      try {
        final m = await remote.createBloodSugarLog(
          level: log.level,
          unit: log.unit,
          mealContext: log.mealContext,
          notes: log.notes,
        );
        final synced = BloodSugarLog.fromMap(m);
        await AppDb.instance.deleteBloodSugarLog(log.id, cfg.userId);
        await AppDb.instance.putBloodSugarLog(synced, cfg.userId);
      } on ApiUnavailableException {
        break;
      } catch (_) {
        // Keep the pending row for a later retry.
      }
    }

    SyncService.instance.updatePendingCount(
        await AppDb.instance.getPendingWriteCount(cfg.userId));
  }

  Future<InsulinItem?> _cachedInsulinItem(String id) async {
    final items = await AppDb.instance.getInsulinItems(_userId);
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
