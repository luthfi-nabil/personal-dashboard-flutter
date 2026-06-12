import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/remote_api.dart';
import '../core/utils.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AddTransactionScreen({super.key, this.editId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amtCtl = TextEditingController();
  final _descCtl = TextEditingController();

  String _type = 'spending';
  String _source = '';
  String _fromSource = '';
  String _toSource = '';
  String _category = '';
  bool _saving = false;

  @override
  void dispose() {
    _amtCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _save(AppData data) async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'transfer' && _fromSource == _toSource) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and To sources must be different.')),
      );
      return;
    }

    final amount = double.tryParse(_amtCtl.text.replaceAll(',', '.')) ?? 0;
    final description = _descCtl.text.trim();

    setState(() => _saving = true);
    try {
      switch (_type) {
        case 'earning':
          final category = data.categories.firstWhere((c) => c.kind == 'earning' && c.name == _category);
          final source = data.sources.firstWhere((s) => s.name == _source);
          await Repo.instance.createEarning(
            amount: amount,
            description: description,
            category: category,
            source: source,
          );
          break;
        case 'spending':
          final category = data.categories.firstWhere((c) => c.kind == 'spending' && c.name == _category);
          final source = data.sources.firstWhere((s) => s.name == _source);
          await Repo.instance.createSpending(
            amount: amount,
            description: description,
            category: category,
            source: source,
          );
          break;
        case 'transfer':
          final from = data.sources.firstWhere((s) => s.name == _fromSource);
          final to = data.sources.firstWhere((s) => s.name == _toSource);
          await Repo.instance.createTransfer(
            amount: amount,
            description: description,
            fromSource: from,
            toSource: to,
          );
          break;
      }
      await ref.read(appDataProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Failed to save transaction.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final dataAsync = ref.watch(appDataProvider);

    return dataAsync.when(
      loading: () => Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        // Transactions loaded from transaction-api have no edit/delete endpoint,
        // so they're shown read-only - only brand-new transactions can be created here.
        if (widget.editId != null && widget.editId!.isNotEmpty) {
          final existing = data.transactions.where((t) => t.id == widget.editId).firstOrNull;
          if (existing != null) {
            return _ReadOnlyTransactionView(transaction: existing, c: c);
          }
        }

        final filteredCats = data.categories.where((cat) => cat.kind == _type).toList();
        if (_category.isNotEmpty && !filteredCats.any((cat) => cat.name == _category)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _category = '');
          });
        }

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _IconBtn(icon: Icons.close_rounded, onTap: () => context.pop(), c: c),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add transaction',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // Type selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line2, width: 0.5),
                    ),
                    child: Row(
                      children: ['spending', 'earning', 'transfer'].map((tp) {
                        final active = _type == tp;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _type = tp),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: active ? c.surface2 : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: active
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)]
                                    : null,
                              ),
                              child: Text(
                                tp[0].toUpperCase() + tp.substring(1),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: active ? c.ink : c.muted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount field
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line2, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Rp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.muted)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _amtCtl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: c.ink),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: c.ink.withOpacity(0.18), fontSize: 32, fontWeight: FontWeight.w700),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final n = double.tryParse(v.replaceAll(',', '.'));
                              if (n == null || n <= 0) return 'Enter a valid amount';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  _Field(label: 'Description', child: TextFormField(
                    controller: _descCtl,
                    style: TextStyle(fontSize: 15, color: c.ink),
                    decoration: InputDecoration(hintText: 'What was it?', hintStyle: TextStyle(color: c.muted)),
                  )),
                  const SizedBox(height: 14),

                  // Source fields
                  if (_type == 'transfer') ...[
                    _Field(label: 'From', child: _SourceDropdown(
                      value: _fromSource, sources: data.sources, c: c,
                      hint: 'Select source…',
                      onChanged: (v) => setState(() => _fromSource = v ?? ''),
                    )),
                    const SizedBox(height: 14),
                    _Field(label: 'To', child: _SourceDropdown(
                      value: _toSource, sources: data.sources, c: c,
                      hint: 'Select destination…',
                      onChanged: (v) => setState(() => _toSource = v ?? ''),
                    )),
                  ] else ...[
                    _Field(label: 'Source', child: _SourceDropdown(
                      value: _source, sources: data.sources, c: c,
                      hint: 'Select source…',
                      onChanged: (v) => setState(() => _source = v ?? ''),
                    )),
                    const SizedBox(height: 14),
                    _Field(label: 'Category', child: _CategoryDropdown(
                      value: _category, categories: filteredCats, c: c,
                      onChanged: (v) => setState(() => _category = v ?? ''),
                    )),
                  ],
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _save(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.ink,
                        foregroundColor: c.bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.bg),
                            )
                          : const Text(
                              'Save transaction',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Transactions loaded from transaction-api have no edit/delete endpoint,
/// so they are shown as a read-only summary.
class _ReadOnlyTransactionView extends ConsumerWidget {
  final Transaction transaction;
  final AppColors c;
  const _ReadOnlyTransactionView({required this.transaction, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(configProvider);
    final t = transaction;
    final isEarning = t.type == 'earning';
    final isTransfer = t.type == 'transfer';
    final amountColor = isTransfer ? c.transfer : (isEarning ? c.pos : c.neg);
    final sign = isTransfer ? '' : (isEarning ? '+' : '−');

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _IconBtn(icon: Icons.close_rounded, onTap: () => context.pop(), c: c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line2, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.type[0].toUpperCase() + t.type.substring(1),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$sign${fmtRp(t.amount, cfg.currency)}',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: amountColor),
                  ),
                  const SizedBox(height: 18),
                  if (t.description.isNotEmpty) _DetailRow(label: 'Description', value: t.description, c: c),
                  if (isTransfer) ...[
                    _DetailRow(label: 'From', value: t.fromSource ?? '—', c: c),
                    _DetailRow(label: 'To', value: t.toSource ?? '—', c: c),
                  ] else ...[
                    _DetailRow(label: 'Source', value: t.source ?? '—', c: c),
                    _DetailRow(label: 'Category', value: t.category ?? '—', c: c),
                  ],
                  _DetailRow(label: 'Date', value: fmtDate(t.date, 'long'), c: c, last: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: c.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This transaction is synced from the server and cannot be edited or deleted here.',
                      style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  final bool last;
  const _DetailRow({required this.label, required this.value, required this.c, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.muted)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.ink)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
        ),
        child,
      ],
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  final String value;
  final List<Source> sources;
  final AppColors c;
  final String hint;
  final ValueChanged<String?> onChanged;
  const _SourceDropdown({required this.value, required this.sources, required this.c, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      hint: Text(hint, style: TextStyle(color: c.muted)),
      decoration: InputDecoration(
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: sources.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      dropdownColor: c.surface,
      style: TextStyle(color: c.ink, fontSize: 15),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<Category> categories;
  final AppColors c;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({required this.value, required this.categories, required this.c, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      hint: Text('— none —', style: TextStyle(color: c.muted)),
      decoration: InputDecoration(
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: categories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      dropdownColor: c.surface,
      style: TextStyle(color: c.ink, fontSize: 15),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppColors c;
  const _IconBtn({required this.icon, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: c.ink),
      ),
    );
  }
}
