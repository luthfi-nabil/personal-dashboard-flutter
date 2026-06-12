import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/db.dart';
import '../core/seed.dart';
import '../core/utils.dart';
import '../core/sync.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/source_card.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _usernameCtl;
  late TextEditingController _apiBaseCtl;
  late TextEditingController _healthBaseCtl;
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(configProvider);
    _usernameCtl = TextEditingController(text: cfg.username);
    _apiBaseCtl = TextEditingController(text: cfg.apiBase);
    _healthBaseCtl = TextEditingController(text: cfg.healthBase);
  }

  @override
  void dispose() {
    _usernameCtl.dispose();
    _apiBaseCtl.dispose();
    _healthBaseCtl.dispose();
    super.dispose();
  }

  void _saveAccountConfig() {
    final cfg = ref.read(configProvider);
    ref.read(configProvider.notifier).update(cfg.copyWith(
          username: _usernameCtl.text.trim(),
          apiBase: _apiBaseCtl.text.trim(),
          healthBase: _healthBaseCtl.text.trim(),
        ));
    ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> _syncNow() async {
    await ref.read(appDataProvider.notifier).refresh();
    if (!mounted) return;
    final failed = ref.read(appDataProvider).hasError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failed ? 'Sync failed' : 'Synced')),
    );
  }

  Future<void> _exportJson() async {
    final data = await ref.read(appDataProvider.future);
    final json = const JsonEncoder.withIndent('  ').convert({
      'sources': data.sources.map((s) => s.toMap()).toList(),
      'categories': data.categories.map((c) => c.toMap()).toList(),
      'transactions': data.transactions.map((t) => t.toMap()).toList(),
    });
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/personal-dashboard.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'personal-dashboard.json');
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset & re-seed?'),
        content: const Text('This will wipe all local data and restore sample data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDb.instance.clearAll();
    await seedIfEmpty();
    await ref.read(appDataProvider.notifier).refresh();
  }

  void _openSourceEditor({Source? source}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.colorsOf(context).bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SourceEditorSheet(
        source: source,
        onSaved: () async {
          await ref.read(appDataProvider.notifier).refresh();
        },
      ),
    );
  }

  void _openCategoryEditor({Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.colorsOf(context).bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CategoryEditorSheet(
        category: category,
        onSaved: () async {
          await ref.read(appDataProvider.notifier).refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final cfg = ref.watch(configProvider);
    final dataAsync = ref.watch(appDataProvider);

    return dataAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SizedBox(height: 14),
          Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.02)),
          const SizedBox(height: 18),

          // ── Account ────────────────────────────────────────────
          _SectionTitle('Account', c),
          const SizedBox(height: 10),
          _card(c, Column(
            children: [
              TextField(
                controller: _usernameCtl,
                style: TextStyle(color: c.ink, fontSize: 15),
                onSubmitted: (_) => _saveAccountConfig(),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. luthfi',
                  hintStyle: TextStyle(color: c.muted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiBaseCtl,
                style: TextStyle(color: c.ink, fontSize: 15),
                onSubmitted: (_) => _saveAccountConfig(),
                decoration: InputDecoration(
                  labelText: 'Transaction API base URL',
                  hintStyle: TextStyle(color: c.muted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _healthBaseCtl,
                style: TextStyle(color: c.ink, fontSize: 15),
                onSubmitted: (_) => _saveAccountConfig(),
                decoration: InputDecoration(
                  labelText: 'Health API base URL',
                  hintStyle: TextStyle(color: c.muted),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _saveAccountConfig, child: Text('Save', style: TextStyle(color: c.accent))),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: cfg.autoSync,
                    activeColor: c.accent,
                    onChanged: (v) => ref.read(configProvider.notifier).update(cfg.copyWith(autoSync: v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Auto-sync when online', style: TextStyle(color: c.ink, fontSize: 14))),
                  TextButton(onPressed: _syncNow, child: Text('Sync now', style: TextStyle(color: c.accent))),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  cfg.isConfigured
                      ? (SyncService.instance.isOnline ? 'Connected, ready to sync' : 'Configured but offline - showing cached data')
                      : 'Set a username to connect to your server',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/api-log'),
                  icon: Icon(Icons.network_check, size: 16, color: c.accent),
                  label: Text('API Watcher', style: TextStyle(color: c.accent)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                ),
              ),
            ],
          )),
          const SizedBox(height: 18),

          // ── Appearance ─────────────────────────────────────────
          _SectionTitle('Appearance', c),
          const SizedBox(height: 10),
          _card(c, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme', style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _SegRow(
                options: const ['ink', 'warm', 'dark'],
                current: cfg.theme,
                c: c,
                onSelect: (v) => ref.read(configProvider.notifier).update(cfg.copyWith(theme: v)),
              ),
              const SizedBox(height: 14),
              Text('Density', style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _SegRow(
                options: const ['compact', 'regular', 'comfy'],
                current: cfg.density,
                c: c,
                onSelect: (v) => ref.read(configProvider.notifier).update(cfg.copyWith(density: v)),
              ),
              const SizedBox(height: 14),
              Text('Currency format', style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _SegRow(
                options: const ['full', 'short'],
                labels: const ['Rp 12.596.000', 'Rp 12,6 jt'],
                current: cfg.currency,
                c: c,
                onSelect: (v) => ref.read(configProvider.notifier).update(cfg.copyWith(currency: v)),
              ),
            ],
          )),
          const SizedBox(height: 18),

          // ── Sources ────────────────────────────────────────────
          Row(children: [
            _SectionTitle('Sources (${data.sources.length})', c),
            const Spacer(),
            TextButton(
              onPressed: () => _openSourceEditor(),
              child: Text('+ Add', style: TextStyle(color: c.accent, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
          ...data.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SourceCard(
                  source: s,
                  currency: cfg.currency,
                  onTap: () => _openSourceEditor(source: s),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.muted),
                ),
              )),
          const SizedBox(height: 18),

          // ── Categories ─────────────────────────────────────────
          Row(children: [
            _SectionTitle('Categories (${data.categories.length})', c),
            const Spacer(),
            TextButton(
              onPressed: () => _openCategoryEditor(),
              child: Text('+ Add', style: TextStyle(color: c.accent, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
          // ── Kind filter pills ─────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'spending', 'earning'].map((kind) {
                final active = _categoryFilter == kind;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _categoryFilter = kind),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? c.ink : c.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: active ? c.ink : c.line2,
                          width: active ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        kind == 'all' ? 'All' : kind,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? c.bg : c.muted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final filtered = _categoryFilter == 'all'
                ? data.categories
                : data.categories.where((cat) => cat.kind == _categoryFilter).toList();
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No categories for this kind.',
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 6, runSpacing: 6,
              children: filtered.map((cat) {
                final color = catColor(cat.name);
                return GestureDetector(
                  onTap: () => _openCategoryEditor(category: cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.line2, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(cat.name, style: TextStyle(fontSize: 13, color: c.ink)),
                        const SizedBox(width: 4),
                        Text(cat.kind, style: TextStyle(fontSize: 11, color: c.muted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 18),

          // ── Data ───────────────────────────────────────────────
          _SectionTitle('Data', c),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _exportJson,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.line, width: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Export all (JSON)', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.neg,
                    side: BorderSide(color: c.neg.withOpacity(0.3), width: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Reset & re-seed', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(AppColors c, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line2, width: 0.5),
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final AppColors c;
  const _SectionTitle(this.text, this.c);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: c.muted, letterSpacing: 0.06));
  }
}

class _SegRow extends StatelessWidget {
  final List<String> options;
  final List<String>? labels;
  final String current;
  final AppColors c;
  final ValueChanged<String> onSelect;
  const _SegRow({required this.options, this.labels, required this.current, required this.c, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line2, width: 0.5),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final opt = options[i];
          final label = (labels != null && i < labels!.length) ? labels![i] : opt;
          final active = opt == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: active ? c.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)] : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: active ? c.ink : c.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Source editor sheet ────────────────────────────────────────────────────
class _SourceEditorSheet extends ConsumerStatefulWidget {
  final Source? source;
  final VoidCallback onSaved;
  const _SourceEditorSheet({this.source, required this.onSaved});

  @override
  ConsumerState<_SourceEditorSheet> createState() => _SourceEditorSheetState();
}

class _SourceEditorSheetState extends ConsumerState<_SourceEditorSheet> {
  final _nameCtl = TextEditingController();
  String _kind = 'debit';
  final _kinds = ['debit', 'credit', 'cash', 'ewallet', 'savings'];

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _nameCtl.text = widget.source!.name;
      _kind = widget.source!.kind;
    }
  }

  @override
  void dispose() { _nameCtl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (widget.source == null) {
      if (name.isEmpty) return;
      final source = await Repo.instance.createSource(name, kind: _kind);
      // Remember the chosen kind locally - the API has no concept of it.
      await AppDb.instance.putSource(source);
    } else {
      // Name/kind aren't editable server-side; "kind" is a local-only label.
      await AppDb.instance.putSource(widget.source!.copyWith(kind: _kind));
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete source?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Repo.instance.deleteSource(widget.source!.id);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(widget.source != null ? 'Edit source' : 'Add source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              enabled: widget.source == null,
              style: TextStyle(color: c.ink),
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: widget.source != null ? "Name can't be changed once created" : null,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: _kinds.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) { if (v != null) setState(() => _kind = v); },
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (widget.source != null)
                TextButton(
                  onPressed: _delete,
                  child: Text('Delete', style: TextStyle(color: c.neg)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Category editor sheet ──────────────────────────────────────────────────
class _CategoryEditorSheet extends ConsumerStatefulWidget {
  final Category? category;
  final VoidCallback onSaved;
  const _CategoryEditorSheet({this.category, required this.onSaved});

  @override
  ConsumerState<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  final _nameCtl = TextEditingController();
  String _kind = 'spending';

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtl.text = widget.category!.name;
      _kind = widget.category!.kind;
    }
  }

  @override
  void dispose() { _nameCtl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;
    await Repo.instance.createCategory(name: name, kind: _kind);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Repo.instance.deleteCategory(id: widget.category!.id, kind: widget.category!.kind);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(widget.category != null ? 'Edit category' : 'Add category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              enabled: widget.category == null,
              style: TextStyle(color: c.ink),
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: widget.category != null ? "Categories can't be renamed once created" : null,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: const [
                DropdownMenuItem(value: 'spending', child: Text('spending')),
                DropdownMenuItem(value: 'earning', child: Text('earning')),
              ],
              onChanged: widget.category != null ? null : (v) { if (v != null) setState(() => _kind = v); },
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (widget.category != null)
                TextButton(
                  onPressed: _delete,
                  child: Text('Delete', style: TextStyle(color: c.neg)),
                ),
              const Spacer(),
              if (widget.category == null)
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
