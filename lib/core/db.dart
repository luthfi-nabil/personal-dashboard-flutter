import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'models.dart';

/// Tables that are scoped per-user via a `userId` column. An empty-string
/// `userId` represents the logged-out / demo (seeded) data set.
const _userScopedTables = [
  'sources',
  'categories',
  'transactions',
  'insulin_items',
  'insulin_assigns',
  'insulin_usages',
];

class AppDb {
  static final AppDb instance = AppDb._();
  AppDb._();

  late Database _db;

  Future<void> init(DatabaseFactory factory) async {
    final path =
        join(await factory.getDatabasesPath(), 'personal_dashboard.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE sources (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
          )''');
          await db.execute('''CREATE TABLE categories (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
          )''');
          await db.execute('''CREATE TABLE transactions (
            id TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT DEFAULT '',
            category TEXT,
            source TEXT,
            fromSource TEXT,
            toSource TEXT,
            date TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
          )''');
          await db.execute('''CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
          await db.execute('''CREATE TABLE insulin_items (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            units REAL NOT NULL,
            uom TEXT NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
          )''');
          await db.execute('''CREATE TABLE insulin_assigns (
            id TEXT NOT NULL,
            itemId TEXT NOT NULL,
            batchNo TEXT NOT NULL,
            date TEXT NOT NULL,
            itemName TEXT DEFAULT '',
            totalUnits REAL DEFAULT 0,
            lastUsedAt TEXT,
            notes TEXT,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
          )''');
          await db.execute('''CREATE TABLE insulin_usages (
            id TEXT NOT NULL,
            assignId TEXT NOT NULL,
            units REAL NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            userId TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id, userId)
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
          if (oldVersion < 3) {
            // Existing cached rows can't be attributed to a user in
            // hindsight, so they become part of the logged-out/demo
            // (userId = '') data set.
            for (final table in _userScopedTables) {
              await db.execute(
                  "ALTER TABLE $table ADD COLUMN userId TEXT NOT NULL DEFAULT ''");
            }
          }
          if (oldVersion < 4) {
            await _migrateToPerUserPrimaryKeys(db);
          }
        },
      ),
    );
  }

  // ── Sources ────────────────────────────────────────────────────────
  Future<List<Source>> getSources(String userId) async {
    final rows =
        await _db.query('sources', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(Source.fromMap).toList();
  }

  Future<void> putSource(Source s, String userId) async {
    await _db.insert('sources', {...s.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSource(String id, String userId) async {
    await _db.delete('sources',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // ── Categories ─────────────────────────────────────────────────────
  Future<List<Category>> getCategories(String userId) async {
    final rows =
        await _db.query('categories', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(Category.fromMap).toList();
  }

  Future<void> putCategory(Category c, String userId) async {
    await _db.insert('categories', {...c.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(String id, String userId) async {
    await _db.delete('categories',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // ── Transactions ───────────────────────────────────────────────────
  Future<List<Transaction>> getTransactions(String userId) async {
    final rows = await _db.query('transactions',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> putTransaction(Transaction t, String userId) async {
    await _db.insert('transactions', {...t.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id, String userId) async {
    await _db.delete('transactions',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  /// Transactions created while the API was unreachable ("local mode"),
  /// queued here until [Repo.syncPendingTransactions] can push them.
  Future<List<Transaction>> getPendingTransactions(String userId) async {
    final rows = await _db.query('transactions',
        where: "userId = ? AND syncState = 'pending'",
        whereArgs: [userId],
        orderBy: 'date ASC');
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
  Future<List<InsulinItem>> getInsulinItems(String userId) async {
    final rows = await _db
        .query('insulin_items', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(InsulinItem.fromMap).toList();
  }

  Future<void> putInsulinItem(InsulinItem t, String userId) async {
    await _db.insert('insulin_items', {...t.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinItem(String id, String userId) async {
    await _db.delete('insulin_items',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<List<InsulinAssign>> getInsulinAssigns(String userId) async {
    final rows = await _db
        .query('insulin_assigns', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(InsulinAssign.fromMap).toList();
  }

  Future<void> putInsulinAssign(InsulinAssign t, String userId) async {
    await _db.insert('insulin_assigns', {...t.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinAssign(String id, String userId) async {
    await _db.delete('insulin_assigns',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<List<InsulinUsage>> getInsulinUsages(String userId) async {
    final rows = await _db
        .query('insulin_usages', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(InsulinUsage.fromMap).toList();
  }

  Future<void> putInsulinUsage(InsulinUsage t, String userId) async {
    await _db.insert('insulin_usages', {...t.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinUsage(String id, String userId) async {
    await _db.delete('insulin_usages',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // ── Bulk replace (online-first cache refresh) ───────────────────────
  Future<void> replaceSources(List<Source> items, String userId) async {
    await _db.transaction((txn) async {
      await txn.delete('sources', where: 'userId = ?', whereArgs: [userId]);
      for (final s in items) {
        await txn.insert('sources', {...s.toMap(), 'userId': userId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceCategories(List<Category> items, String userId) async {
    await _db.transaction((txn) async {
      await txn.delete('categories', where: 'userId = ?', whereArgs: [userId]);
      for (final c in items) {
        await txn.insert('categories', {...c.toMap(), 'userId': userId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Replaces the cached server transactions while preserving any rows
  /// still queued in "local mode" (`syncState == 'pending'`), so an
  /// offline-created transaction isn't wiped out before it's synced.
  Future<void> replaceTransactions(
      List<Transaction> items, String userId) async {
    await _db.transaction((txn) async {
      await txn.delete('transactions',
          where: "userId = ? AND syncState != 'pending'", whereArgs: [userId]);
      for (final t in items) {
        await txn.insert('transactions', {...t.toMap(), 'userId': userId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceInsulinItems(
      List<InsulinItem> items, String userId) async {
    await _db.transaction((txn) async {
      await txn
          .delete('insulin_items', where: 'userId = ?', whereArgs: [userId]);
      for (final i in items) {
        await txn.insert('insulin_items', {...i.toMap(), 'userId': userId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceInsulinAssigns(
      List<InsulinAssign> items, String userId) async {
    await _db.transaction((txn) async {
      await txn
          .delete('insulin_assigns', where: 'userId = ?', whereArgs: [userId]);
      for (final a in items) {
        await txn.insert('insulin_assigns', {...a.toMap(), 'userId': userId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── Bulk ───────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    for (final table in [
      'sources',
      'categories',
      'transactions',
      'meta',
      'insulin_items',
      'insulin_assigns',
      'insulin_usages'
    ]) {
      await _db.delete(table);
    }
  }
}

/// Version 3 added `userId`, but retained `id` as a global primary key.
/// Rebuild the scoped tables so identical server IDs can be cached for
/// different users without one account replacing another account's row.
Future<void> _migrateToPerUserPrimaryKeys(Database db) async {
  const schemas = <String, String>{
    'sources': '''CREATE TABLE sources (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      syncState TEXT DEFAULT 'pending',
      updatedAt TEXT NOT NULL,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
    'categories': '''CREATE TABLE categories (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      syncState TEXT DEFAULT 'pending',
      updatedAt TEXT NOT NULL,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
    'transactions': '''CREATE TABLE transactions (
      id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT DEFAULT '',
      category TEXT,
      source TEXT,
      fromSource TEXT,
      toSource TEXT,
      date TEXT NOT NULL,
      syncState TEXT DEFAULT 'pending',
      updatedAt TEXT NOT NULL,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
    'insulin_items': '''CREATE TABLE insulin_items (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      units REAL NOT NULL,
      uom TEXT NOT NULL,
      date TEXT NOT NULL,
      notes TEXT,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
    'insulin_assigns': '''CREATE TABLE insulin_assigns (
      id TEXT NOT NULL,
      itemId TEXT NOT NULL,
      batchNo TEXT NOT NULL,
      date TEXT NOT NULL,
      itemName TEXT DEFAULT '',
      totalUnits REAL DEFAULT 0,
      lastUsedAt TEXT,
      notes TEXT,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
    'insulin_usages': '''CREATE TABLE insulin_usages (
      id TEXT NOT NULL,
      assignId TEXT NOT NULL,
      units REAL NOT NULL,
      date TEXT NOT NULL,
      notes TEXT,
      userId TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (id, userId)
    )''',
  };

  const columns = <String, String>{
    'sources': 'id, name, kind, syncState, updatedAt, userId',
    'categories': 'id, name, kind, syncState, updatedAt, userId',
    'transactions':
        'id, type, amount, description, category, source, fromSource, toSource, date, syncState, updatedAt, userId',
    'insulin_items': 'id, name, units, uom, date, notes, userId',
    'insulin_assigns':
        'id, itemId, batchNo, date, itemName, totalUnits, lastUsedAt, notes, userId',
    'insulin_usages': 'id, assignId, units, date, notes, userId',
  };

  for (final table in _userScopedTables) {
    final oldTable = '${table}_v3';
    await db.execute('ALTER TABLE $table RENAME TO $oldTable');
    await db.execute(schemas[table]!);
    await db.execute(
      'INSERT INTO $table (${columns[table]}) '
      'SELECT ${columns[table]} FROM $oldTable',
    );
    await db.execute('DROP TABLE $oldTable');
  }
}
