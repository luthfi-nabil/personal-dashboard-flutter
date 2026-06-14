import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'api_log.dart';
import 'models.dart';

/// Max time to wait for transaction-api / health-api to respond.
const _requestTimeout = Duration(seconds: 10);

/// Thrown when transaction-api / health-api return an error response.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Thrown when transaction-api / health-api could not be reached at all
/// (timeout, connection refused, DNS failure, etc.) as opposed to
/// [ApiException], which signals an HTTP-level error from a reachable
/// server. Repo treats this as "go to local mode" - the write is queued
/// locally and retried once the API is reachable again.
class ApiUnavailableException extends ApiException {
  const ApiUnavailableException(super.message);
}

/// Thin REST client for the real `/api/user/{created_by}/...` endpoints
/// exposed by transaction-api and health-api. Neither service validates a
/// token on these routes — `created_by` is just a path segment, so the
/// configured username is used directly as the user identifier.
class RemoteApi {
  final AppConfig cfg;
  const RemoteApi(this.cfg);

  String get _createdBy => Uri.encodeComponent(cfg.username.trim());

  String _trim(String base) => base.replaceAll(RegExp(r'/+$'), '');

  Uri _txnUri(String path, [Map<String, dynamic>? query]) {
    final clean = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return Uri.parse('${_trim(cfg.apiBase)}/api/user/$_createdBy$path')
        .replace(queryParameters: clean.isNotEmpty ? clean : null);
  }

  Uri _healthUri(String path) =>
      Uri.parse('${_trim(cfg.healthBase)}/api/user/$_createdBy$path');

  // ── Low-level helpers ──────────────────────────────────────────────────
  dynamic _unwrap(http.Response res) {
    Map<String, dynamic>? body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = null;
      }
    }
    if (res.statusCode >= 400) {
      final msg = body?['description']?.toString().isNotEmpty == true
          ? body!['description'].toString()
          : (body?['message']?.toString() ?? 'HTTP ${res.statusCode}');
      throw ApiException(msg);
    }
    if (body == null) return null;
    if (body['success'] == false) {
      throw ApiException(body['description']?.toString().isNotEmpty == true
          ? body['description'].toString()
          : (body['message']?.toString() ?? 'Request failed'));
    }
    return body['data'];
  }

  /// Logs every outgoing request and its outcome under the 'RemoteApi' tag
  /// (visible in the `flutter run` console / DevTools logging view) so it's
  /// easy to confirm whether the app is actually hitting the APIs.
  Future<dynamic> _send(String method, Uri uri, Future<http.Response> Function() request, [Object? body]) async {
    developer.log('→ $method $uri${body != null ? ' $body' : ''}', name: 'RemoteApi');
    final sw = Stopwatch()..start();
    http.Response res;
    try {
      res = await request().timeout(_requestTimeout);
    } on TimeoutException {
      developer.log('✗ $method $uri timed out after $_requestTimeout', name: 'RemoteApi', level: 1000);
      ApiCallLog.instance.add(ApiCallEntry(
        time: DateTime.now(),
        method: method,
        uri: uri,
        duration: sw.elapsed,
        error: 'Timed out after ${_requestTimeout.inSeconds}s',
      ));
      throw ApiUnavailableException('Request timed out: $method $uri');
    } catch (e) {
      developer.log('✗ $method $uri failed: $e', name: 'RemoteApi', level: 1000);
      ApiCallLog.instance.add(ApiCallEntry(
        time: DateTime.now(),
        method: method,
        uri: uri,
        duration: sw.elapsed,
        error: e.toString(),
      ));
      // Connection refused / DNS failure / etc. - the API is unreachable,
      // not just returning an error, so treat the same as a timeout.
      throw ApiUnavailableException('Could not reach $method $uri: $e');
    }
    developer.log('← $method $uri (${res.statusCode})', name: 'RemoteApi');
    ApiCallLog.instance.add(ApiCallEntry(
      time: DateTime.now(),
      method: method,
      uri: uri,
      duration: sw.elapsed,
      statusCode: res.statusCode,
    ));
    return _unwrap(res);
  }

  Future<dynamic> _get(Uri uri) => _send('GET', uri, () => http.get(uri));

  Future<dynamic> _post(Uri uri, Map<String, dynamic> body) => _send(
        'POST',
        uri,
        () => http.post(uri, headers: {'content-type': 'application/json'}, body: jsonEncode(body)),
        body,
      );

  Future<void> _delete(Uri uri) => _send('DELETE', uri, () => http.delete(uri));

  List<Map<String, dynamic>> _list(dynamic data) =>
      (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ── transaction-api: settings ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSettings() async =>
      _list(await _get(_txnUri('/settings')));

  // ── transaction-api: sources ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSources() async =>
      _list(await _get(_txnUri('/source')));

  Future<List<Map<String, dynamic>>> getSourceBalances() async =>
      _list(await _get(_txnUri('/source-balance')));

  Future<Map<String, dynamic>> createSource(String name) async =>
      Map<String, dynamic>.from(await _post(_txnUri('/source'), {'source': name}) as Map);

  Future<void> deleteSource(String sourceId) async =>
      _delete(_txnUri('/source/$sourceId'));

  // ── transaction-api: earning categories ────────────────────────────────
  Future<List<Map<String, dynamic>>> getEarningCategories() async =>
      _list(await _get(_txnUri('/earning-categories')));

  Future<Map<String, dynamic>> createEarningCategory(String name) async =>
      Map<String, dynamic>.from(
          await _post(_txnUri('/earning-categories'), {'earning_category': name}) as Map);

  Future<void> deleteEarningCategory(String id) async =>
      _delete(_txnUri('/earning-categories/$id'));

  // ── transaction-api: spending categories ───────────────────────────────
  Future<List<Map<String, dynamic>>> getSpendingCategories() async =>
      _list(await _get(_txnUri('/spending-categories')));

  Future<Map<String, dynamic>> createSpendingCategory(String name) async =>
      Map<String, dynamic>.from(
          await _post(_txnUri('/spending-categories'), {'spending_category': name}) as Map);

  Future<void> deleteSpendingCategory(String id) async =>
      _delete(_txnUri('/spending-categories/$id'));

  // ── transaction-api: earnings ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEarnings() async =>
      _list(await _get(_txnUri('/earnings')));

  Future<Map<String, dynamic>> createEarning({
    required double totalAmount,
    required String description,
    required String earningCategoryId,
    required String earningCategory,
    required String sourceId,
    required String source,
  }) async =>
      Map<String, dynamic>.from(await _post(_txnUri('/earnings'), {
        'total_amount': totalAmount,
        'description': description,
        'earning_category_id': earningCategoryId,
        'earning_category': earningCategory,
        'source_id': sourceId,
        'source': source,
      }) as Map);

  // ── transaction-api: spendings ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSpendings() async =>
      _list(await _get(_txnUri('/spendings')));

  Future<Map<String, dynamic>> createSpending({
    required double totalAmount,
    required String description,
    required String spendingCategoryId,
    required String spendingCategory,
    required String sourceId,
    required String source,
  }) async =>
      Map<String, dynamic>.from(await _post(_txnUri('/spendings'), {
        'total_amount': totalAmount,
        'description': description,
        'spending_category_id': spendingCategoryId,
        'spending_category': spendingCategory,
        'source_id': sourceId,
        'source': source,
      }) as Map);

  // ── health-api: insulin items ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getInsulinItems() async =>
      _list(await _get(_healthUri('/insulin-item')));

  Future<Map<String, dynamic>> createInsulinItem({
    required String name,
    required double units,
    required String uom,
    String? notes,
  }) async =>
      Map<String, dynamic>.from(await _post(_healthUri('/insulin-item'), {
        'insulin_item_name': name,
        'units': units,
        'uom': uom,
        'notes': notes,
      }) as Map);

  // ── health-api: insulin assigns (batches) ──────────────────────────────
  Future<List<Map<String, dynamic>>> getInsulinAssignUsage() async =>
      _list(await _get(_healthUri('/insulin-assign-usage')));

  Future<Map<String, dynamic>> createInsulinAssign({
    required String insulinItemId,
    required String batchNo,
    String? notes,
  }) async =>
      Map<String, dynamic>.from(await _post(_healthUri('/insulin-assign'), {
        'insulin_item_id': insulinItemId,
        'batch_no': batchNo,
        'notes': notes,
      }) as Map);

  Future<void> deleteInsulinAssign(String id) async =>
      _delete(_healthUri('/insulin-assign/$id'));

  // ── health-api: insulin usage ──────────────────────────────────────────
  Future<Map<String, dynamic>> createInsulinUsage({
    required String insulinAssignId,
    required double units,
    String? notes,
  }) async =>
      Map<String, dynamic>.from(await _post(_healthUri('/insulin-usage'), {
        'insulin_assign_id': insulinAssignId,
        'units': units,
        'notes': notes,
      }) as Map);
}
