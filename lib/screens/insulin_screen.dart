import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/remote_api.dart';
import '../core/utils.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';

class InsulinScreen extends ConsumerStatefulWidget {
  const InsulinScreen({super.key});

  @override
  ConsumerState<InsulinScreen> createState() => _InsulinScreenState();
}

class _InsulinScreenState extends ConsumerState<InsulinScreen> {
  Future<void> _refresh() => ref.read(appDataProvider.notifier).refresh();

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openItemEditor() {
    final c = AppTheme.colorsOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InsulinItemSheet(
        onSaved: _refresh,
        onError: _showError,
      ),
    );
  }

  void _openAssignEditor(List<InsulinItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an insulin type first.')),
      );
      return;
    }
    final c = AppTheme.colorsOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InsulinAssignSheet(
        items: items,
        onSaved: _refresh,
        onError: _showError,
      ),
    );
  }

  void _openUsageSheet(InsulinAssign assign) {
    final c = AppTheme.colorsOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InsulinUsageSheet(
        assign: assign,
        onSaved: _refresh,
        onError: _showError,
      ),
    );
  }

  Future<void> _deleteAssign(InsulinAssign a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete batch?'),
        content: Text('This removes batch "${a.batchNo}" and its usage history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Repo.instance.deleteInsulinAssign(a.id);
      await _refresh();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final dataAsync = ref.watch(appDataProvider);

    return dataAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SizedBox(height: 14),
            Text('Insulin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.02)),
            const SizedBox(height: 18),

            // ── Insulin types ──────────────────────────────────────
            Row(children: [
              _SectionTitle('Types (${data.insulinItems.length})', c),
              const Spacer(),
              TextButton(
                onPressed: _openItemEditor,
                child: Text('+ Add type', style: TextStyle(color: c.accent, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            if (data.insulinItems.isEmpty)
              _emptyHint(c, 'No insulin types yet. Add one to get started.')
            else
              ...data.insulinItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.line2, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.vaccines_outlined, size: 20, color: c.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_fmtNum(item.units)} ${item.uom}'
                                  '${(item.notes?.isNotEmpty ?? false) ? ' · ${item.notes}' : ''}',
                                  style: TextStyle(fontSize: 12, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 18),

            // ── Batches ────────────────────────────────────────────
            Row(children: [
              _SectionTitle('Batches (${data.insulinAssigns.length})', c),
              const Spacer(),
              TextButton(
                onPressed: () => _openAssignEditor(data.insulinItems),
                child: Text('+ Add batch', style: TextStyle(color: c.accent, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            if (data.insulinAssigns.isEmpty)
              _emptyHint(c, 'No batches yet. Add a batch for an insulin type.')
            else
              ...data.insulinAssigns.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.line2, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.itemName.isNotEmpty ? a.itemName : 'Unknown type',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Batch ${a.batchNo}', style: TextStyle(fontSize: 12, color: c.muted)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _deleteAssign(a),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: c.neg),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _StatChip(
                                  label: 'Used',
                                  value: '${_fmtNum(a.totalUnits)} units',
                                  c: c,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  label: 'Last used',
                                  value: a.lastUsedAt != null ? fmtDate(a.lastUsedAt!, 'short') : '—',
                                  c: c,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _openUsageSheet(a),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.ink,
                                side: BorderSide(color: c.line, width: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Log usage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _emptyHint(AppColors c, String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line2, width: 0.5),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: c.muted)),
      );
}

String _fmtNum(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  const _StatChip({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
        ],
      ),
    );
  }
}

// ── Insulin type sheet ──────────────────────────────────────────────────────
class _InsulinItemSheet extends ConsumerStatefulWidget {
  final Future<void> Function() onSaved;
  final void Function(Object error) onError;
  const _InsulinItemSheet({required this.onSaved, required this.onError});

  @override
  ConsumerState<_InsulinItemSheet> createState() => _InsulinItemSheetState();
}

class _InsulinItemSheetState extends ConsumerState<_InsulinItemSheet> {
  final _nameCtl = TextEditingController();
  final _unitsCtl = TextEditingController();
  final _uomCtl = TextEditingController(text: 'unit');
  final _notesCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _unitsCtl.dispose();
    _uomCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final units = double.tryParse(_unitsCtl.text.replaceAll(',', '.'));
    final uom = _uomCtl.text.trim();
    if (name.isEmpty || units == null || uom.isEmpty) return;

    setState(() => _saving = true);
    try {
      await Repo.instance.createInsulinItem(
        name: name,
        units: units,
        uom: uom,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Text('Add insulin type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Lantus'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _unitsCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: TextStyle(color: c.ink),
                  decoration: const InputDecoration(labelText: 'Units', hintText: 'e.g. 100'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _uomCtl,
                  style: TextStyle(color: c.ink),
                  decoration: const InputDecoration(labelText: 'Unit of measure', hintText: 'e.g. unit, ml, IU'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtl,
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                    : const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Insulin batch (assign) sheet ────────────────────────────────────────────
class _InsulinAssignSheet extends ConsumerStatefulWidget {
  final List<InsulinItem> items;
  final Future<void> Function() onSaved;
  final void Function(Object error) onError;
  const _InsulinAssignSheet({required this.items, required this.onSaved, required this.onError});

  @override
  ConsumerState<_InsulinAssignSheet> createState() => _InsulinAssignSheetState();
}

class _InsulinAssignSheetState extends ConsumerState<_InsulinAssignSheet> {
  final _batchCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  late String _itemId = widget.items.first.id;
  bool _saving = false;

  @override
  void dispose() {
    _batchCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final batchNo = _batchCtl.text.trim();
    if (batchNo.isEmpty) return;

    setState(() => _saving = true);
    try {
      await Repo.instance.createInsulinAssign(
        itemId: _itemId,
        batchNo: batchNo,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Text('Add batch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _itemId,
              decoration: const InputDecoration(labelText: 'Insulin type'),
              items: widget.items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
              onChanged: (v) { if (v != null) setState(() => _itemId = v); },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _batchCtl,
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Batch number', hintText: 'e.g. B-2026-001'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtl,
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                    : const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Log insulin usage sheet ─────────────────────────────────────────────────
class _InsulinUsageSheet extends ConsumerStatefulWidget {
  final InsulinAssign assign;
  final Future<void> Function() onSaved;
  final void Function(Object error) onError;
  const _InsulinUsageSheet({required this.assign, required this.onSaved, required this.onError});

  @override
  ConsumerState<_InsulinUsageSheet> createState() => _InsulinUsageSheetState();
}

class _InsulinUsageSheetState extends ConsumerState<_InsulinUsageSheet> {
  final _unitsCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _unitsCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final units = double.tryParse(_unitsCtl.text.replaceAll(',', '.'));
    if (units == null || units <= 0) return;

    setState(() => _saving = true);
    try {
      await Repo.instance.logInsulinUsage(
        assignId: widget.assign.id,
        units: units,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Text(
                'Log usage · ${widget.assign.itemName.isNotEmpty ? widget.assign.itemName : 'Batch ${widget.assign.batchNo}'}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink),
              ),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: c.muted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _unitsCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Units used', hintText: 'e.g. 10'),
              autofocus: true,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtl,
              style: TextStyle(color: c.ink),
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                    : const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
