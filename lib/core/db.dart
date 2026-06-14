import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'models.dart';

class AppDb {
  static final AppDb instance = AppDb._();
  AppDb._();

  late Database _db;

  Future<void> init(DatabaseFactory factory) async {
    final path = join(await factory.getDatabasesPath(), 'personal_dashboard.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT DEFAULT '',
            category TEXT,
            source TEXT,
            fromSource TEXT,
            toSource TEXT,
            date TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
          await db.execute('''CREATE TABLE insulin_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            units REAL NOT NULL,
            uom TEXT NOT NULL,
            date TEXT NOT NULL,
            notes TEXT
          )''');
          await db.execute('''CREATE TABLE insulin_assigns (
            id TEXT PRIMARY KEY,
            itemId TEXT NOT NULL,
            batchNo TEXT NOT NULL,
            date TEXT NOT NULL,
            itemName TEXT DEFAULT '',
            totalUnits REAL DEFAULT 0,
            lastUsedAt TEXT,
            notes TEXT
          )''');
          await db.execute('''CREATE TABLE insulin_usages (
            id TEXT PRIMARY KEY,
            assignId TEXT NOT NULL,
            units REAL NOT NULL,
            date TEXT NOT NULL,
            notes TEXT
          )''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('DROP TABLE IF EXISTS insulin_items');
            await db.execute('DROP TABLE IF EXISTS insulin_assigns');
            await db.execute('''CREATE TABLE insulin_items (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              units REAL NOT NULL,
              uom TEXT NOT NULL,
              date TEXT NOT NULL,
              notes TEXT
            )''');
            await db.execute('''CREATE TABLE insulin_assigns (
              id TEXT PRIMARY KEY,
              itemId TEXT NOT NULL,
              batchNo TEXT NOT NULL,
              date TEXT NOT NULL,
              itemName TEXT DEFAULT '',
              totalUnits REAL DEFAULT 0,
              lastUsedAt TEXT,
              notes TEXT
            )''');
          }
        },
      ),
    );
  }

  // ── Sources ────────────────────────────────────────────────────────
  Future<List<Source>> getSources() async {
    final rows = await _db.query('sources');
    return rows.map(Source.fromMap).toList();
  }

  Future<void> putSource(Source s) async {
    await _db.insert('sources', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSource(String id) async {
    await _db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  // ── Categories ─────────────────────────────────────────────────────
  Future<List<Category>> getCategories() async {
    final rows = await _db.query('categories');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> putCategory(Category c) async {
    await _db.insert('categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(String id) async {
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Transactions ───────────────────────────────────────────────────
  Future<List<Transaction>> getTransactions() async {
    final rows = await _db.query('transactions', orderBy: 'date DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> putTransaction(Transaction t) async {
    await _db.insert('transactions', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Transactions created while the API was unreachable ("local mode"),
  /// queued here until [Repo.syncPendingTransactions] can push them.
  Future<List<Transaction>> getPendingTransactions() async {
    final rows = await _db.query('transactions', where: "syncState = 'pending'", orderBy: 'date ASC');
    return rows.map(Transaction.fromMap).toList();
  }

  // ── Meta ───────────────────────────────────────────────────────────
  Future<String?> getMeta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    await _db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Insulin ────────────────────────────────────────────────────────
  Future<List<InsulinItem>> getInsulinItems() async {
    final rows = await _db.query('insulin_items');
    return rows.map(InsulinItem.fromMap).toList();
  }

  Future<void> putInsulinItem(InsulinItem t) async {
    await _db.insert('insulin_items', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinItem(String id) async {
    await _db.delete('insulin_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InsulinAssign>> getInsulinAssigns() async {
    final rows = await _db.query('insulin_assigns');
    return rows.map(InsulinAssign.fromMap).toList();
  }

  Future<void> putInsulinAssign(InsulinAssign t) async {
    await _db.insert('insulin_assigns', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinAssign(String id) async {
    await _db.delete('insulin_assigns', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InsulinUsage>> getInsulinUsages() async {
    final rows = await _db.query('insulin_usages');
    return rows.map(InsulinUsage.fromMap).toList();
  }

  Future<void> putInsulinUsage(InsulinUsage t) async {
    await _db.insert('insulin_usages', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinUsage(String id) async {
    await _db.delete('insulin_usages', where: 'id = ?', whereArgs: [id]);
  }

  // ── Bulk replace (online-first cache refresh) ───────────────────────
  Future<void> replaceSources(List<Source> items) async {
    await _db.transaction((txn) async {
      await txn.delete('sources');
      for (final s in items) {
        await txn.insert('sources', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceCategories(List<Category> items) async {
    await _db.transaction((txn) async {
      await txn.delete('categories');
      for (final c in items) {
        await txn.insert('categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Replaces the cached server transactions while preserving any rows
  /// still queued in "local mode" (`syncState == 'pending'`), so an
  /// offline-created transaction isn't wiped out before it's synced.
  Future<void> replaceTransactions(List<Transaction> items) async {
    await _db.transaction((txn) async {
      await txn.delete('transactions', where: "syncState != 'pending'");
      for (final t in items) {
        await txn.insert('transactions', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceInsulinItems(List<InsulinItem> items) async {
    await _db.transaction((txn) async {
      await txn.delete('insulin_items');
      for (final i in items) {
        await txn.insert('insulin_items', i.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceInsulinAssigns(List<InsulinAssign> items) async {
    await _db.transaction((txn) async {
      await txn.delete('insulin_assigns');
      for (final a in items) {
        await txn.insert('insulin_assigns', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── Bulk ───────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    for (final table in [
      'sources', 'categories', 'transactions', 'meta',
      'insulin_items', 'insulin_assigns', 'insulin_usages'
    ]) {
      await _db.delete(table);
    }
  }
}
