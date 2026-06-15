import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_log.dart';
import '../theme/app_theme.dart';

/// Shows recent transaction-api / health-api calls made via [RemoteApi] so
/// connectivity issues (404s, timeouts, etc.) can be checked directly on
/// device without a dev console attached.
class ApiLogScreen extends StatefulWidget {
  const ApiLogScreen({super.key});

  @override
  State<ApiLogScreen> createState() => _ApiLogScreenState();
}

class _ApiLogScreenState extends State<ApiLogScreen> {
  @override
  void initState() {
    super.initState();
    ApiCallLog.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    ApiCallLog.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final entries = ApiCallLog.instance.entries;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        title: const Text('API Watcher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: entries.isEmpty ? null : () => ApiCallLog.instance.clear(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No API calls recorded yet.\nUse the app, or tap "Sync now" in Settings, '
                  'to see requests appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EntryTile(entry: entries[i], c: c),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final ApiCallEntry entry;
  final AppColors c;
  const _EntryTile({required this.entry, required this.c});

  @override
  Widget build(BuildContext context) {
    final ok = entry.isOk;
    final statusLabel = entry.error ?? '${entry.statusCode}';
    final color = ok ? c.pos : c.neg;
    final path = entry.uri.path + (entry.uri.query.isNotEmpty ? '?${entry.uri.query}' : '');
    final origin = '${entry.uri.scheme}://${entry.uri.authority}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetail(context, entry, c),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line2, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(entry.method,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(path,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(origin, style: TextStyle(fontSize: 11, color: c.muted), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${entry.duration.inMilliseconds} ms', style: TextStyle(fontSize: 11, color: c.muted)),
                const SizedBox(width: 8),
                Text(_fmtTime(entry.time), style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

void _showDetail(BuildContext context, ApiCallEntry entry, AppColors c) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _DetailSheet(entry: entry, c: c),
  );
}

/// Pretty-prints [raw] as indented JSON if possible, otherwise returns it
/// unchanged (e.g. for non-JSON error bodies).
String _prettyBody(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

class _DetailSheet extends StatelessWidget {
  final ApiCallEntry entry;
  final AppColors c;
  const _DetailSheet({required this.entry, required this.c});

  @override
  Widget build(BuildContext context) {
    final ok = entry.isOk;
    final color = ok ? c.pos : c.neg;
    final statusLabel = entry.error ?? '${entry.statusCode}';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: c.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(entry.method,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${entry.uri}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 14, color: color),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Text('${entry.duration.inMilliseconds} ms', style: TextStyle(fontSize: 12, color: c.muted)),
                const SizedBox(width: 12),
                Text(_fmtTime(entry.time), style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
            if (entry.requestBody != null) ...[
              const SizedBox(height: 20),
              _SectionLabel('Request body', c: c),
              _CodeBlock(text: _prettyBody(entry.requestBody!), c: c),
            ],
            if (entry.responseBody != null) ...[
              const SizedBox(height: 20),
              _SectionLabel('Response body', c: c),
              _CodeBlock(text: _prettyBody(entry.responseBody!), c: c),
            ],
            if (entry.error != null) ...[
              const SizedBox(height: 20),
              _SectionLabel('Error', c: c),
              _CodeBlock(text: entry.error!, c: c),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors c;
  const _SectionLabel(this.text, {required this.c});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted, letterSpacing: 0.5)),
      );
}

class _CodeBlock extends StatelessWidget {
  final String text;
  final AppColors c;
  const _CodeBlock({required this.text, required this.c});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line2, width: 0.5),
        ),
        child: SelectableText(
          text,
          style: TextStyle(fontSize: 12, color: c.ink, fontFamily: 'monospace', height: 1.4),
        ),
      );
}
