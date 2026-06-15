import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:personal_dashboard/core/db.dart';
import 'package:personal_dashboard/core/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('v4 migration keeps cache rows isolated by user', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('personal-dashboard-db-');
    await factory.setDatabasesPath(tempDir.path);

    final path = join(tempDir.path, 'personal_dashboard.db');
    final oldDb = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT ''
          )''');
          await db.execute('''CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            syncState TEXT DEFAULT 'pending',
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT ''
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
            updatedAt TEXT NOT NULL,
            userId TEXT NOT NULL DEFAULT ''
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
            notes TEXT,
            userId TEXT NOT NULL DEFAULT ''
          )''');
          await db.execute('''CREATE TABLE insulin_assigns (
            id TEXT PRIMARY KEY,
            itemId TEXT NOT NULL,
            batchNo TEXT NOT NULL,
            date TEXT NOT NULL,
            itemName TEXT DEFAULT '',
            totalUnits REAL DEFAULT 0,
            lastUsedAt TEXT,
            notes TEXT,
            userId TEXT NOT NULL DEFAULT ''
          )''');
          await db.execute('''CREATE TABLE insulin_usages (
            id TEXT PRIMARY KEY,
            assignId TEXT NOT NULL,
            units REAL NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            userId TEXT NOT NULL DEFAULT ''
          )''');
        },
      ),
    );
    await oldDb.insert('sources', {
      'id': 'shared-id',
      'name': 'User A source',
      'kind': 'cash',
      'syncState': 'synced',
      'updatedAt': '2026-06-15T00:00:00',
      'userId': 'user-a',
    });
    await oldDb.close();

    await AppDb.instance.init(factory);
    await AppDb.instance.putSource(
      const Source(
        id: 'shared-id',
        name: 'User B source',
        kind: 'debit',
        syncState: 'synced',
        updatedAt: '2026-06-15T00:00:00',
      ),
      'user-b',
    );

    final userA = await AppDb.instance.getSources('user-a');
    final userB = await AppDb.instance.getSources('user-b');

    expect(userA.single.name, 'User A source');
    expect(userB.single.name, 'User B source');
  });
}
