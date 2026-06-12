import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/txn_tile.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final String name;
  const CategoryDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppTheme.colorsOf(context);
    final cfg = ref.watch(configProvider);
    final dataAsync = ref.watch(appDataProvider);

    return dataAsync.when(
      loading: () => Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        final items = data.transactions.where((t) => t.category == name).toList();
        final total = items.fold<double>(0, (s, t) => s + t.amount);
        final color = catColor(name);

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        left: BorderSide(color: color, width: 4),
                        top: BorderSide(color: c.line2, width: 0.5),
                        right: BorderSide(color: c.line2, width: 0.5),
                        bottom: BorderSide(color: c.line2, width: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(fmtRp(total, cfg.currency),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.ink)),
                        const SizedBox(height: 4),
                        Text('${items.length} transactions',
                            style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: items.isEmpty
                      ? Center(child: Text('No activity', style: TextStyle(color: c.muted)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: c.surface, borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.line2, width: 0.5),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Column(
                                children: items.map((t) => TxnTile(
                                  t: t, currency: cfg.currency,
                                  onTap: () => context.push('/add/${t.id}'),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
