import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/txn_tile.dart';

class SourceDetailScreen extends ConsumerWidget {
  final String name;
  const SourceDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppTheme.colorsOf(context);
    final cfg = ref.watch(configProvider);
    final dataAsync = ref.watch(appDataProvider);

    return dataAsync.when(
      loading: () => Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        final tone = sourceTone(name);
        final bal = computeBalances(data.transactions);
        final balance = bal[name] ?? 0;

        final items = data.transactions.where((t) =>
            t.source == name || t.fromSource == name || t.toSource == name).toList();

        final inflow = items.fold<double>(0, (s, t) {
          if (t.type == 'earning' && t.source == name) return s + t.amount;
          if (t.type == 'transfer' && t.toSource == name) return s + t.amount;
          return s;
        });
        final outflow = items.fold<double>(0, (s, t) {
          if (t.type == 'spending' && t.source == name) return s + t.amount;
          if (t.type == 'transfer' && t.fromSource == name) return s + t.amount;
          return s;
        });

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
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.line2, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: tone.tone, borderRadius: BorderRadius.circular(16)),
                          child: Center(child: Text(tone.m,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fmtRp(balance, cfg.currency),
                          style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700,
                            color: balance < 0 ? c.neg : c.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FlowChip(label: 'In', value: fmtRp(inflow, cfg.currency), color: c.pos, c: c),
                            const SizedBox(width: 18),
                            _FlowChip(label: 'Out', value: fmtRp(outflow, cfg.currency), color: c.neg, c: c),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('History (${items.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: c.muted, letterSpacing: 0.06)),
                ),
                const SizedBox(height: 10),
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

class _FlowChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppColors c;
  const _FlowChip({required this.label, required this.value, required this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label $value', style: TextStyle(fontSize: 13, color: c.muted)),
      ],
    );
  }
}
