import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/db.dart';
import 'core/config.dart';
import 'core/sync.dart';
import 'core/seed.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite support
  DatabaseFactory factory;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  } else {
    factory = databaseFactory;
  }

  await AppDb.instance.init(factory);
  await ConfigService.instance.load();
  await seedIfEmpty();
  await SyncService.instance.start();

  runApp(const ProviderScope(child: PersonalDashboardApp()));
}
