import 'db.dart';
import 'config.dart';
import 'models.dart';
import 'remote_api.dart';
import 'sync.dart';

/// Online-first data layer. When configured (a username is set) and online,
/// reads go straight to transaction-api / health-api and the result is
/// cached locally; otherwise (offline, or not yet configured) cached/seeded
/// data from SQLite is used. Writes go straight to the REST APIs - there is
/// no offline write queue since the APIs only support create/delete.
class Repo {
  static final Repo instance = Repo._();
  Repo._();

  String _nowIso() => DateTime.now().toIso8601String();

  AppConfig get _cfg => ConfigService.instance.current;

  // ── Aggregate read ───────────────────────────────────────────────────
  Future<AppData> all() async {
    final cfg = _cfg;
    if (cfg.isConfigured && SyncService.instance.isOnline) {
      try {
        final data = await _fetchRemote(cfg);
        await _cacheRemote(data);
        return data;
      } catch (_) {
        // fall back to local cache below
      }
    }
    return _fromCache();
  }

  Future<AppData> _fromCache() async {
    final results = await Future.wait([
      AppDb.instance.getSources(),
      AppDb.instance.getCategories(),
      AppDb.instance.getTransactions(),
      AppDb.instance.getInsulinItems(),
      AppDb.instance.getInsulinAssigns(),
      AppDb.instance.getInsulinUsages(),
    ]);
    return AppData(
      sources: results[0] as List<Source>,
      categories: results[1] as List<Category>,
      transactions: results[2] as List<Transaction>,
      insulinItems: results[3] as List<InsulinItem>,
      insulinAssigns: results[4] as List<InsulinAssign>,
      insulinUsages: results[5] as List<InsulinUsage>,
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
      for (final s in await AppDb.instance.getSources()) s.id: s.kind,
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

    final transactions = _pairTransfers(rawEarnings, rawSpendings, transferCategoryName);

    var insulinItems = <InsulinItem>[];
    var insulinAssigns = <InsulinAssign>[];
    try {
      final healthResults = await Future.wait([
        api.getInsulinItems(),
        api.getInsulinAssignUsage(),
      ]);
      insulinItems = healthResults[0].map(InsulinItem.fromMap).toList();
      insulinAssigns = healthResults[1].map(InsulinAssign.fromMap).toList();
    } catch (_) {
      // health-api may be unreachable independently of transaction-api
    }

    final insulinUsages = await AppDb.instance.getInsulinUsages();

    return AppData(
      sources: sources,
      categories: categories,
      transactions: transactions,
      insulinItems: insulinItems,
      insulinAssigns: insulinAssigns,
      insulinUsages: insulinUsages,
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
          if ((e['total_amount'] as num).toDouble() != (s['total_amount'] as num).toDouble()) continue;
          if (e['description'] != s['description']) continue;
          final ed = DateTime.tryParse(e['created_date']?.toString() ?? '');
          final sd = DateTime.tryParse(s['created_date']?.toString() ?? '');
          final diff = (ed != null && sd != null) ? ed.difference(sd).abs() : Duration.zero;
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

  Future<void> _cacheRemote(AppData data) async {
    await AppDb.instance.replaceSources(data.sources);
    await AppDb.instance.replaceCategories(data.categories);
    await AppDb.instance.replaceTransactions(data.transactions);
    await AppDb.instance.replaceInsulinItems(data.insulinItems);
    await AppDb.instance.replaceInsulinAssigns(data.insulinAssigns);
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
  Future<Category> createCategory({required String name, required String kind}) async {
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
    return kind == 'earning' ? api.deleteEarningCategory(id) : api.deleteSpendingCategory(id);
  }

  // ── Transactions (create-only; the APIs have no edit/delete) ─────────
  Future<void> createEarning({
    required double amount,
    required String description,
    required Category category,
    required Source source,
  }) =>
      RemoteApi(_cfg).createEarning(
        totalAmount: amount,
        description: description,
        earningCategoryId: category.id,
        earningCategory: category.name,
        sourceId: source.id,
        source: source.name,
      );

  Future<void> createSpending({
    required double amount,
    required String description,
    required Category category,
    required Source source,
  }) =>
      RemoteApi(_cfg).createSpending(
        totalAmount: amount,
        description: description,
        spendingCategoryId: category.id,
        spendingCategory: category.name,
        sourceId: source.id,
        source: source.name,
      );

  /// Creates a transfer as a paired spending (fromSource) + earning
  /// (toSource), both tagged with the server's configured Transfer category.
  Future<void> createTransfer({
    required double amount,
    required String description,
    required Source fromSource,
    required Source toSource,
  }) async {
    final remote = RemoteApi(_cfg);
    final settings = await remote.getSettings();
    String catId = '';
    String catName = 'Transfer';
    for (final s in settings) {
      if (s['app_setting_key'] == 'TRANSFER_CATEGORY_ID') catId = s['app_setting_value'] as String? ?? '';
      if (s['app_setting_key'] == 'TRANSFER_CATEGORY_NAME') catName = s['app_setting_value'] as String? ?? catName;
    }
    if (catId.isEmpty) {
      throw const ApiException('Transfer category is not configured on the server.');
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
  }

  // ── Insulin ──────────────────────────────────────────────────────────
  Future<InsulinItem> createInsulinItem({
    required String name,
    required double units,
    required String uom,
    String? notes,
  }) async {
    final m = await RemoteApi(_cfg).createInsulinItem(name: name, units: units, uom: uom, notes: notes);
    return InsulinItem.fromMap(m);
  }

  Future<InsulinAssign> createInsulinAssign({
    required String itemId,
    required String batchNo,
    String? notes,
  }) async {
    final m = await RemoteApi(_cfg).createInsulinAssign(insulinItemId: itemId, batchNo: batchNo, notes: notes);
    return InsulinAssign.fromMap(m);
  }

  Future<void> deleteInsulinAssign(String id) => RemoteApi(_cfg).deleteInsulinAssign(id);

  Future<InsulinUsage> logInsulinUsage({
    required String assignId,
    required double units,
    String? notes,
  }) async {
    final m = await RemoteApi(_cfg).createInsulinUsage(insulinAssignId: assignId, units: units, notes: notes);
    final usage = InsulinUsage.fromMap(m);
    await AppDb.instance.putInsulinUsage(usage);
    return usage;
  }
}
