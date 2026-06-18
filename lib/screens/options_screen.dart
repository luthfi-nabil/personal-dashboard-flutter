import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/utils.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/source_card.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  String _categoryFilter = 'all';

  void _openSourceEditor({Source? source}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.colorsOf(context).bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          Text(
            'Options',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            _SectionTitle('Sources (${data.sources.length})', c),
            const Spacer(),
            TextButton(
              onPressed: () => _openSourceEditor(),
              child: Text('+ Add',
                  style: TextStyle(color: c.accent, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
          if (data.sources.isEmpty)
            _EmptyPanel(c: c, text: 'No sources yet.')
          else
            ...data.sources.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SourceCard(
                    source: s,
                    currency: cfg.currency,
                    onTap: () => _openSourceEditor(source: s),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: c.muted,
                    ),
                  ),
                )),
          const SizedBox(height: 18),
          Row(children: [
            _SectionTitle('Categories (${data.categories.length})', c),
            const Spacer(),
            TextButton(
              onPressed: () => _openCategoryEditor(),
              child: Text('+ Add',
                  style: TextStyle(color: c.accent, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
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
                : data.categories
                    .where((cat) => cat.kind == _categoryFilter)
                    .toList();
            if (filtered.isEmpty) {
              return _EmptyPanel(c: c, text: 'No categories for this kind.');
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filtered.map((cat) {
                final color = catColor(cat.name);
                return GestureDetector(
                  onTap: () => _openCategoryEditor(category: cat),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.line2, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(cat.name,
                            style: TextStyle(fontSize: 13, color: c.ink)),
                        const SizedBox(width: 4),
                        Text(cat.kind,
                            style: TextStyle(fontSize: 11, color: c.muted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final AppColors c;

  const _SectionTitle(this.text, this.c);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.muted,
        letterSpacing: 0.06,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final AppColors c;
  final String text;

  const _EmptyPanel({required this.c, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line2, width: 0.5),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: c.muted)),
    );
  }
}

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
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final userId = ref.read(configProvider).userId;
    if (widget.source == null) {
      if (name.isEmpty) return;
      final source = await Repo.instance.createSource(name, kind: _kind);
      await AppDb.instance.putSource(source, userId);
    } else {
      await AppDb.instance
          .putSource(widget.source!.copyWith(kind: _kind), userId);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete source?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(widget.source != null ? 'Edit source' : 'Add source',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              enabled: widget.source == null,
              style: TextStyle(color: c.ink),
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: widget.source != null
                    ? "Name can't be changed once created"
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: _kinds
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              },
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
                style: ElevatedButton.styleFrom(
                    backgroundColor: c.ink,
                    foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  final Category? category;
  final VoidCallback onSaved;

  const _CategoryEditorSheet({this.category, required this.onSaved});

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
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
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Repo.instance
        .deleteCategory(id: widget.category!.id, kind: widget.category!.kind);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(widget.category != null ? 'Edit category' : 'Add category',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              enabled: widget.category == null,
              style: TextStyle(color: c.ink),
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: widget.category != null
                    ? "Categories can't be renamed once created"
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: const [
                DropdownMenuItem(value: 'spending', child: Text('spending')),
                DropdownMenuItem(value: 'earning', child: Text('earning')),
              ],
              onChanged: widget.category != null
                  ? null
                  : (v) {
                      if (v != null) setState(() => _kind = v);
                    },
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: c.ink,
                      foregroundColor: c.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
