import 'dart:convert';

class Source {
  final String id;
  final String name;
  final String kind;
  final String syncState;
  final String updatedAt;

  const Source({
    required this.id,
    required this.name,
    required this.kind,
    this.syncState = 'pending',
    required this.updatedAt,
  });

  factory Source.fromMap(Map<String, dynamic> m) => Source(
        id: m['id'] as String,
        name: m['name'] as String,
        kind: m['kind'] as String,
        syncState: m['syncState'] as String? ?? 'pending',
        updatedAt: m['updatedAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'syncState': syncState,
        'updatedAt': updatedAt,
      };

  Source copyWith(
          {String? id,
          String? name,
          String? kind,
          String? syncState,
          String? updatedAt}) =>
      Source(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        syncState: syncState ?? this.syncState,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Category {
  final String id;
  final String name;
  final String kind;
  final String syncState;
  final String updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.syncState = 'pending',
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        kind: m['kind'] as String,
        syncState: m['syncState'] as String? ?? 'pending',
        updatedAt: m['updatedAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'syncState': syncState,
        'updatedAt': updatedAt,
      };

  Category copyWith(
          {String? id,
          String? name,
          String? kind,
          String? syncState,
          String? updatedAt}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        syncState: syncState ?? this.syncState,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final String description;
  final String? category;
  final String? source;
  final String? fromSource;
  final String? toSource;
  final String date;
  final String syncState;
  final String updatedAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description = '',
    this.category,
    this.source,
    this.fromSource,
    this.toSource,
    required this.date,
    this.syncState = 'pending',
    required this.updatedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String? ?? '',
        category: m['category'] as String?,
        source: m['source'] as String?,
        fromSource: m['fromSource'] as String?,
        toSource: m['toSource'] as String?,
        date: m['date'] as String,
        syncState: m['syncState'] as String? ?? 'pending',
        updatedAt: m['updatedAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'description': description,
        'category': category,
        'source': source,
        'fromSource': fromSource,
        'toSource': toSource,
        'date': date,
        'syncState': syncState,
        'updatedAt': updatedAt,
      };

  Transaction copyWith({
    String? id,
    String? type,
    double? amount,
    String? description,
    String? category,
    String? source,
    String? fromSource,
    String? toSource,
    String? date,
    String? syncState,
    String? updatedAt,
  }) =>
      Transaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        source: source ?? this.source,
        fromSource: fromSource ?? this.fromSource,
        toSource: toSource ?? this.toSource,
        date: date ?? this.date,
        syncState: syncState ?? this.syncState,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class AppConfig {
  final String apiBase;
  final String healthBase;
  final String loginBase;
  final bool autoSync;
  final int syncIntervalSec;
  final String theme;
  final String density;
  final String currency;
  final String username;
  final String email;
  final String phoneNumber;
  final String telegramUsername;
  final String authToken;
  final String tokenExpiresAt;
  final String userId;

  const AppConfig({
    this.apiBase = 'http://127.0.0.1:8080',
    this.healthBase = 'http://127.0.0.1:8082',
    this.loginBase = 'http://127.0.0.1:3002',
    this.autoSync = true,
    this.syncIntervalSec = 30,
    this.theme = 'ink',
    this.density = 'regular',
    this.currency = 'full',
    this.username = '',
    this.email = '',
    this.phoneNumber = '',
    this.telegramUsername = '',
    this.authToken = '',
    this.tokenExpiresAt = '',
    this.userId = '',
  });

  /// Whether [tokenExpiresAt] is set and in the past.
  bool get isTokenExpired {
    if (tokenExpiresAt.isEmpty) return false;
    final exp = DateTime.tryParse(tokenExpiresAt);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// The app is "logged in" once login-api has issued a JWT (used as a
  /// Bearer token for transaction-api / health-api `/api/user/...` routes)
  /// and that token hasn't expired yet.
  bool get isLoggedIn => authToken.trim().isNotEmpty && !isTokenExpired;

  /// Kept as an alias of [isLoggedIn] for call sites that historically
  /// checked whether the app was "configured".
  bool get isConfigured => isLoggedIn;

  factory AppConfig.fromJson(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return AppConfig(
      apiBase: m['apiBase'] as String? ?? 'http://127.0.0.1:8080',
      healthBase: m['healthBase'] as String? ?? 'http://127.0.0.1:8082',
      loginBase: m['loginBase'] as String? ?? 'http://127.0.0.1:3002',
      autoSync: m['autoSync'] as bool? ?? true,
      syncIntervalSec: m['syncIntervalSec'] as int? ?? 30,
      theme: m['theme'] as String? ?? 'ink',
      density: m['density'] as String? ?? 'regular',
      currency: m['currency'] as String? ?? 'full',
      username: m['username'] as String? ?? '',
      email: m['email'] as String? ?? '',
      phoneNumber: m['phoneNumber'] as String? ?? '',
      telegramUsername: m['telegramUsername'] as String? ?? '',
      authToken: m['authToken'] as String? ?? '',
      tokenExpiresAt: m['tokenExpiresAt'] as String? ?? '',
      userId: m['userId'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode({
        'apiBase': apiBase,
        'healthBase': healthBase,
        'loginBase': loginBase,
        'autoSync': autoSync,
        'syncIntervalSec': syncIntervalSec,
        'theme': theme,
        'density': density,
        'currency': currency,
        'username': username,
        'email': email,
        'phoneNumber': phoneNumber,
        'telegramUsername': telegramUsername,
        'authToken': authToken,
        'tokenExpiresAt': tokenExpiresAt,
        'userId': userId,
      });

  AppConfig copyWith({
    String? apiBase,
    String? healthBase,
    String? loginBase,
    bool? autoSync,
    int? syncIntervalSec,
    String? theme,
    String? density,
    String? currency,
    String? username,
    String? email,
    String? phoneNumber,
    String? telegramUsername,
    String? authToken,
    String? tokenExpiresAt,
    String? userId,
  }) =>
      AppConfig(
        apiBase: apiBase ?? this.apiBase,
        healthBase: healthBase ?? this.healthBase,
        loginBase: loginBase ?? this.loginBase,
        autoSync: autoSync ?? this.autoSync,
        syncIntervalSec: syncIntervalSec ?? this.syncIntervalSec,
        theme: theme ?? this.theme,
        density: density ?? this.density,
        currency: currency ?? this.currency,
        username: username ?? this.username,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        telegramUsername: telegramUsername ?? this.telegramUsername,
        authToken: authToken ?? this.authToken,
        tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
        userId: userId ?? this.userId,
      );
}

class AppData {
  final List<Source> sources;
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<InsulinItem> insulinItems;
  final List<InsulinAssign> insulinAssigns;
  final List<InsulinUsage> insulinUsages;
  final List<BloodSugarLog> bloodSugarLogs;

  const AppData({
    required this.sources,
    required this.categories,
    required this.transactions,
    this.insulinItems = const [],
    this.insulinAssigns = const [],
    this.insulinUsages = const [],
    this.bloodSugarLogs = const [],
  });
}

class InsulinItem {
  final String id;
  final String name;
  final double units;
  final String uom;
  final String date;
  final String? notes;

  const InsulinItem({
    required this.id,
    required this.name,
    required this.units,
    required this.uom,
    required this.date,
    this.notes,
  });

  factory InsulinItem.fromMap(Map<String, dynamic> m) => InsulinItem(
        id: m['insulin_item_id'] ?? m['id'],
        name: m['insulin_item_name'] ?? m['name'],
        units: (m['units'] as num).toDouble(),
        uom: m['uom'],
        date: m['created_at'] ?? m['date'],
        notes: m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'units': units,
        'uom': uom,
        'date': date,
        'notes': notes,
      };
}

class InsulinAssign {
  final String id;
  final String itemId;
  final String batchNo;
  final String date;
  final String itemName;
  final double totalUnits;
  final String? lastUsedAt;
  final String? notes;

  const InsulinAssign({
    required this.id,
    required this.itemId,
    required this.batchNo,
    required this.date,
    this.itemName = '',
    this.totalUnits = 0,
    this.lastUsedAt,
    this.notes,
  });

  factory InsulinAssign.fromMap(Map<String, dynamic> m) => InsulinAssign(
        id: m['insulin_assign_id'] ?? m['id'],
        itemId: m['insulin_item_id'] ?? m['itemId'],
        batchNo: m['batch_no'] ?? m['batchNo'],
        date: m['added_at'] ?? m['date'],
        itemName:
            m['insulin_item_name'] as String? ?? m['itemName'] as String? ?? '',
        totalUnits:
            ((m['total_units'] ?? m['totalUnits']) as num?)?.toDouble() ?? 0,
        lastUsedAt: m['last_used_at'] as String? ?? m['lastUsedAt'] as String?,
        notes: m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemId': itemId,
        'batchNo': batchNo,
        'date': date,
        'itemName': itemName,
        'totalUnits': totalUnits,
        'lastUsedAt': lastUsedAt,
        'notes': notes,
      };
}

class InsulinUsage {
  final String id;
  final String assignId;
  final double units;
  final String date;
  final String? notes;

  const InsulinUsage({
    required this.id,
    required this.assignId,
    required this.units,
    required this.date,
    this.notes,
  });

  factory InsulinUsage.fromMap(Map<String, dynamic> m) => InsulinUsage(
        id: m['insulin_usage_id'] ?? m['id'],
        assignId: m['insulin_assign_id'] ?? m['assignId'],
        units: (m['units'] as num).toDouble(),
        date: m['administered_at'] ?? m['date'],
        notes: m['notes'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'assignId': assignId,
        'units': units,
        'date': date,
        'notes': notes,
      };
}

class BloodSugarLog {
  final String id;
  final double level;
  final String unit;
  final String measuredAt;
  final String? mealContext;
  final String? notes;

  const BloodSugarLog({
    required this.id,
    required this.level,
    required this.unit,
    required this.measuredAt,
    this.mealContext,
    this.notes,
  });

  factory BloodSugarLog.fromMap(Map<String, dynamic> m) => BloodSugarLog(
        id: m['blood_sugar_id'] ?? m['id'],
        level: (m['level'] as num).toDouble(),
        unit: m['unit'] as String? ?? 'mg/dL',
        measuredAt: m['measured_at'] ?? m['measuredAt'],
        mealContext:
            m['meal_context'] as String? ?? m['mealContext'] as String?,
        notes: m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'level': level,
        'unit': unit,
        'measuredAt': measuredAt,
        'mealContext': mealContext,
        'notes': notes,
      };
}
