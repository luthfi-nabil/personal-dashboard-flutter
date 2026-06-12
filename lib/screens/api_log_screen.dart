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

    return Container(
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
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
