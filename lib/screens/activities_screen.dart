import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/repo.dart';
import '../theme/app_theme.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

enum _ActivityViewMode { today, week, categories }

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  late Future<_ActivityViewData> _future;
  _ActivityViewMode _mode = _ActivityViewMode.today;
  _ActivityViewData? _lastData;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ActivityViewData> _load() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final results = await Future.wait([
      Repo.instance.getActivityTemplates(),
      Repo.instance.getDailyActivities(now),
      Repo.instance.getDailyActivitiesBetween(weekStart, now),
      Repo.instance.getActivityCategories(),
    ]);
    final templates = results[0] as List<ActivityTemplate>;
    final today = results[1] as List<DailyActivity>;
    final week = results[2] as List<DailyActivity>;
    final activityCategories = results[3] as List<ActivityCategory>;
    final categorySet = <String>{
      ...activityCategories.map((item) => item.name),
      ...templates.map((item) => item.category),
      ...today.map((item) => item.category),
      ...week.map((item) => item.category),
    }..removeWhere((category) => category.trim().isEmpty);
    final categories = categorySet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _ActivityViewData(
      templates: templates,
      today: today,
      week: week,
      activityCategories: activityCategories,
      categories: categories,
      weekStart: weekStart,
      weekEnd: now,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
  }

  void _setData(_ActivityViewData data) {
    if (!mounted) return;
    setState(() => _lastData = data);
  }

  _ActivityViewData? get _currentData => _lastData;

  void _selectMode(_ActivityViewMode mode) {
    setState(() => _mode = mode);
  }

  Future<void> _addTemplate() async {
    final categories = _lastData?.categories ??
        (await Repo.instance.getActivityCategories())
            .map((category) => category.name)
            .toList();
    if (!mounted) return;
    final result = await showDialog<_TemplateDraft>(
      context: context,
      builder: (dialogContext) => _TemplateDialog(categories: categories),
    );
    if (result == null || result.title.trim().isEmpty) return;
    final template = await Repo.instance.createActivityTemplate(
      title: result.title.trim(),
      notes: result.notes.trim(),
      category: result.category.trim(),
    );
    final data = _currentData;
    if (data == null) {
      await _refresh();
      return;
    }
    _setData(data.withTemplate(template));
  }

  Future<void> _addCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _CategoryDialog(),
    );
    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    try {
      final category = await Repo.instance.createActivityCategory(name);
      if (category == null) return;
      final data = _currentData;
      if (data == null) {
        await _refresh();
        return;
      }
      _setData(data.withActivityCategory(category));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add category: $err')),
      );
    }
  }

  Future<void> _removeActivityCategory(ActivityCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove activity category?'),
        content: Text('Existing activity history tagged "${category.name}" '
            'will keep the category text.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Repo.instance.deleteActivityCategory(category);
      final data = _currentData;
      if (data == null) {
        await _refresh();
        return;
      }
      _setData(data.withoutActivityCategory(category));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove category: $err')),
      );
    }
  }

  Future<void> _doneToday(ActivityTemplate template) async {
    final activity = await Repo.instance.markActivityDoneToday(template);
    if (activity == null) return;
    final data = _currentData;
    if (data == null) {
      await _refresh();
      return;
    }
    _setData(data.withDoneActivity(activity));
  }

  Future<void> _removeTemplate(ActivityTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove activity template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Repo.instance.deleteActivityTemplate(template);
    final data = _currentData;
    if (data == null) {
      await _refresh();
      return;
    }
    _setData(data.withoutTemplate(template));
  }

  Future<void> _removeActivity(DailyActivity activity) async {
    await Repo.instance.removeDailyActivity(activity);
    final data = _currentData;
    if (data == null) {
      await _refresh();
      return;
    }
    _setData(data.withoutDoneActivity(activity));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return FutureBuilder<_ActivityViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          _lastData = snapshot.data;
        }
        final loading = snapshot.connectionState != ConnectionState.done;
        final data = _lastData ?? snapshot.data ?? _ActivityViewData.empty();
        final doneTemplateIds =
            data.today.map((activity) => activity.templateId).toSet();
        final weekMetrics = _WeeklyActivityMetrics.from(
          activities: data.week,
          templates: data.templates,
          start: data.weekStart,
          end: data.weekEnd,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activities',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.accent),
                    ),
                  ),
                PopupMenuButton<_ActivityViewMode>(
                  tooltip: 'Activity view',
                  onSelected: _selectMode,
                  icon: const Icon(Icons.analytics_outlined),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: _ActivityViewMode.today,
                      checked: _mode == _ActivityViewMode.today,
                      child: const Text('Today'),
                    ),
                    CheckedPopupMenuItem(
                      value: _ActivityViewMode.week,
                      checked: _mode == _ActivityViewMode.week,
                      child: const Text('Week metrics'),
                    ),
                    CheckedPopupMenuItem(
                      value: _ActivityViewMode.categories,
                      checked: _mode == _ActivityViewMode.categories,
                      child: const Text('Categories'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Add activity category',
                  onPressed: _addCategory,
                  icon: const Icon(Icons.new_label_outlined),
                ),
                TextButton.icon(
                  onPressed: _addTemplate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Template'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryBand(
              doneCount: data.today.length,
              templateCount: data.templates.length,
              c: c,
            ),
            const SizedBox(height: 20),
            if (_mode == _ActivityViewMode.today) ...[
              _SectionTitle('Today (${data.today.length})', c),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                _EmptyPanel(c: c, text: 'Could not load activities.')
              else if (data.today.isEmpty)
                _EmptyPanel(c: c, text: 'No activities marked done today.')
              else
                ...data.today.map(
                  (activity) => _DoneActivityTile(
                    activity: activity,
                    c: c,
                    onRemove: () => _removeActivity(activity),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionTitle('Templates (${data.templates.length})', c),
              const SizedBox(height: 10),
              if (data.templates.isEmpty)
                _EmptyPanel(c: c, text: 'No activity templates yet.')
              else
                ...data.templates.map(
                  (template) => _TemplateTile(
                    template: template,
                    doneToday: doneTemplateIds.contains(template.id),
                    c: c,
                    onDone: () => _doneToday(template),
                    onRemove: () => _removeTemplate(template),
                  ),
                ),
            ] else if (_mode == _ActivityViewMode.week) ...[
              _SectionTitle('Last 7 days', c),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                _EmptyPanel(c: c, text: 'Could not load activity metrics.')
              else
                _WeekMetricsView(metrics: weekMetrics, c: c),
            ] else ...[
              _ActivityCategoriesView(
                data: data,
                c: c,
                onAdd: _addCategory,
                onRemove: _removeActivityCategory,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActivityViewData {
  final List<ActivityTemplate> templates;
  final List<DailyActivity> today;
  final List<DailyActivity> week;
  final List<ActivityCategory> activityCategories;
  final List<String> categories;
  final DateTime weekStart;
  final DateTime weekEnd;

  const _ActivityViewData({
    required this.templates,
    required this.today,
    required this.week,
    required this.activityCategories,
    required this.categories,
    required this.weekStart,
    required this.weekEnd,
  });

  factory _ActivityViewData.empty() {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    return _ActivityViewData(
      templates: const [],
      today: const [],
      week: const [],
      activityCategories: const [],
      categories: const [],
      weekStart: weekStart,
      weekEnd: now,
    );
  }

  _ActivityViewData copyWith({
    List<ActivityTemplate>? templates,
    List<DailyActivity>? today,
    List<DailyActivity>? week,
    List<ActivityCategory>? activityCategories,
    List<String>? categories,
  }) {
    return _ActivityViewData(
      templates: templates ?? this.templates,
      today: today ?? this.today,
      week: week ?? this.week,
      activityCategories: activityCategories ?? this.activityCategories,
      categories: categories ?? this.categories,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }

  _ActivityViewData withTemplate(ActivityTemplate template) {
    final nextTemplates = [
      ...templates.where((item) => item.id != template.id),
      template,
    ]..sort(_compareTemplates);
    return copyWith(
      templates: nextTemplates,
      categories: _mergeCategory(categories, template.category),
    );
  }

  _ActivityViewData withoutTemplate(ActivityTemplate template) {
    return copyWith(
      templates: templates.where((item) => item.id != template.id).toList(),
    );
  }

  _ActivityViewData withDoneActivity(DailyActivity activity) {
    final nextToday = [
      ...today.where((item) => item.id != activity.id),
      activity,
    ]..sort(_compareDoneToday);
    final nextWeek = [
      ...week.where((item) => item.id != activity.id),
      activity,
    ]..sort(_compareDoneInRange);
    return copyWith(
      today: nextToday,
      week: nextWeek,
      categories: _mergeCategory(categories, activity.category),
    );
  }

  _ActivityViewData withoutDoneActivity(DailyActivity activity) {
    return copyWith(
      today: today.where((item) => item.id != activity.id).toList(),
      week: week.where((item) => item.id != activity.id).toList(),
    );
  }

  _ActivityViewData withCategory(String category) {
    return copyWith(categories: _mergeCategory(categories, category));
  }

  _ActivityViewData withActivityCategory(ActivityCategory category) {
    final trimmed = category.name.trim();
    if (trimmed.isEmpty) return this;
    final nextCategories = [
      ...activityCategories.where(
          (item) => item.name.trim().toLowerCase() != trimmed.toLowerCase()),
      category.copyWith(name: trimmed),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return copyWith(
      activityCategories: nextCategories,
      categories: _mergeCategory(categories, trimmed),
    );
  }

  _ActivityViewData withoutActivityCategory(ActivityCategory category) {
    final name = category.name.trim().toLowerCase();
    return copyWith(
      activityCategories: activityCategories
          .where((item) => item.name.trim().toLowerCase() != name)
          .toList(),
    );
  }
}

int _compareTemplates(ActivityTemplate a, ActivityTemplate b) {
  final orderCompare = a.sortOrder.compareTo(b.sortOrder);
  if (orderCompare != 0) return orderCompare;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int _compareDoneToday(DailyActivity a, DailyActivity b) =>
    b.doneAt.compareTo(a.doneAt);

int _compareDoneInRange(DailyActivity a, DailyActivity b) {
  final dateCompare = b.activityDate.compareTo(a.activityDate);
  if (dateCompare != 0) return dateCompare;
  return b.doneAt.compareTo(a.doneAt);
}

List<String> _mergeCategory(List<String> categories, String category) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return categories;
  final next = {...categories, trimmed}.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return next;
}

class _TemplateDraft {
  final String title;
  final String notes;
  final String category;

  const _TemplateDraft({
    required this.title,
    required this.notes,
    required this.category,
  });
}

class _TemplateDialog extends StatefulWidget {
  final List<String> categories;

  const _TemplateDialog({required this.categories});

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _titleCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String _selectedCategory = '';

  @override
  void dispose() {
    _titleCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _TemplateDraft(
        title: _titleCtl.text,
        notes: _notesCtl.text,
        category: _selectedCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New activity template'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Activity'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'Select a category',
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('No category')),
              ...widget.categories.map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtl,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _nameCtl = TextEditingController();

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, _nameCtl.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New activity category'),
      content: TextField(
        controller: _nameCtl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Category',
          hintText: 'e.g. Health, Work, Exercise',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final int doneCount;
  final int templateCount;
  final AppColors c;

  const _SummaryBand({
    required this.doneCount,
    required this.templateCount,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(label: 'Done today', value: '$doneCount', c: c),
          ),
          Container(width: 1, height: 34, color: c.line),
          Expanded(
            child: _Metric(label: 'Templates', value: '$templateCount', c: c),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;

  const _Metric({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: c.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}

class _WeeklyActivityMetrics {
  final int totalDone;
  final int activeDays;
  final double completionRate;
  final String rangeLabel;
  final List<_DayMetric> days;
  final List<_ActivityCount> topActivities;
  final List<_CategoryCount> topCategories;

  const _WeeklyActivityMetrics({
    required this.totalDone,
    required this.activeDays,
    required this.completionRate,
    required this.rangeLabel,
    required this.days,
    required this.topActivities,
    required this.topCategories,
  });

  factory _WeeklyActivityMetrics.from({
    required List<DailyActivity> activities,
    required List<ActivityTemplate> templates,
    required DateTime start,
    required DateTime end,
  }) {
    final countsByDate = <String, int>{};
    final countsByTitle = <String, int>{};
    final countsByCategory = <String, int>{};
    for (var offset = 0; offset < 7; offset++) {
      countsByDate[_dateKey(start.add(Duration(days: offset)))] = 0;
    }
    for (final activity in activities) {
      countsByDate.update(
        activity.activityDate,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      countsByTitle.update(
        activity.title,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (activity.category.isNotEmpty) {
        countsByCategory.update(
          activity.category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final days = countsByDate.entries.map((entry) {
      final date = _parseDateKey(entry.key);
      return _DayMetric(
        label: _weekdayLabel(date),
        dateLabel: _shortDate(date),
        count: entry.value,
      );
    }).toList();
    final maxCount =
        days.fold<int>(0, (max, day) => day.count > max ? day.count : max);

    final topActivities = countsByTitle.entries
        .map((entry) => _ActivityCount(title: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return a.title.compareTo(b.title);
      });

    final topCategories = countsByCategory.entries
        .map((entry) => _CategoryCount(category: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final possibleCount = templates.length * 7;
    final completionRate =
        possibleCount == 0 ? 0.0 : (activities.length / possibleCount);

    return _WeeklyActivityMetrics(
      totalDone: activities.length,
      activeDays: days.where((day) => day.count > 0).length,
      completionRate: completionRate.clamp(0, 1).toDouble(),
      rangeLabel: '${_shortDate(start)} - ${_shortDate(end)}',
      days: days
          .map((day) => day.copyWith(
                ratio: maxCount == 0 ? 0 : day.count / maxCount,
              ))
          .toList(),
      topActivities: topActivities.take(5).toList(),
      topCategories: topCategories,
    );
  }
}

class _DayMetric {
  final String label;
  final String dateLabel;
  final int count;
  final double ratio;

  const _DayMetric({
    required this.label,
    required this.dateLabel,
    required this.count,
    this.ratio = 0,
  });

  _DayMetric copyWith({double? ratio}) => _DayMetric(
        label: label,
        dateLabel: dateLabel,
        count: count,
        ratio: ratio ?? this.ratio,
      );
}

class _ActivityCount {
  final String title;
  final int count;

  const _ActivityCount({required this.title, required this.count});
}

class _CategoryCount {
  final String category;
  final int count;

  const _CategoryCount({required this.category, required this.count});
}

class _ActivityCategoryRecap {
  final String category;
  final List<DailyActivity> activities;

  const _ActivityCategoryRecap({
    required this.category,
    required this.activities,
  });

  int get count => activities.length;
}

class _ActivityCategoriesView extends StatelessWidget {
  final _ActivityViewData data;
  final AppColors c;
  final VoidCallback onAdd;
  final ValueChanged<ActivityCategory> onRemove;

  const _ActivityCategoriesView({
    required this.data,
    required this.c,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final recaps = _activityCategoryRecaps(data);
    final recapByName = {
      for (final recap in recaps) recap.category.toLowerCase(): recap,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                  'Activity categories (${data.activityCategories.length})', c),
            ),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Category'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.activityCategories.isEmpty)
          _EmptyPanel(c: c, text: 'No activity categories yet.')
        else
          ...data.activityCategories.map((category) {
            final recap = recapByName[category.name.toLowerCase()] ??
                _ActivityCategoryRecap(
                  category: category.name,
                  activities: const [],
                );
            return _ActivityCategoryTile(
              category: category,
              recap: recap,
              c: c,
              onRemove: () => onRemove(category),
            );
          }),
        const SizedBox(height: 20),
        _SectionTitle('Completed by category - last 7 days', c),
        const SizedBox(height: 10),
        if (recaps.every((recap) => recap.count == 0))
          _EmptyPanel(c: c, text: 'No completed activity recap yet.')
        else
          ...recaps
              .where((recap) => recap.count > 0)
              .map((recap) => _ActivityCategoryRecapTile(recap: recap, c: c)),
      ],
    );
  }
}

class _ActivityCategoryTile extends StatelessWidget {
  final ActivityCategory category;
  final _ActivityCategoryRecap recap;
  final AppColors c;
  final VoidCallback onRemove;

  const _ActivityCategoryTile({
    required this.category,
    required this.recap,
    required this.c,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (category.syncState == 'pending') ...[
                      const SizedBox(width: 8),
                      _TinyStatusChip(text: 'Pending', c: c),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${recap.count} completed in the last 7 days',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove category',
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _ActivityCategoryRecapTile extends StatelessWidget {
  final _ActivityCategoryRecap recap;
  final AppColors c;

  const _ActivityCategoryRecapTile({
    required this.recap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(recap.category);
    final shownActivities = recap.activities.take(4).toList();
    final remaining = recap.activities.length - shownActivities.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recap.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${recap.count}',
                style: TextStyle(
                  color: c.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...shownActivities.map((activity) {
            final date = DateTime.tryParse(activity.activityDate);
            final dateLabel =
                date == null ? activity.activityDate : _shortDate(date);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      dateLabel,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.ink, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (remaining > 0)
            Text(
              '+$remaining more',
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _TinyStatusChip extends StatelessWidget {
  final String text;
  final AppColors c;

  const _TinyStatusChip({required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

List<_ActivityCategoryRecap> _activityCategoryRecaps(_ActivityViewData data) {
  final names = <String>{
    ...data.activityCategories.map((category) => category.name),
    ...data.week.map((activity) => activity.category),
  }..removeWhere((name) => name.trim().isEmpty);
  final recaps = names.map((name) {
    final activities = data.week
        .where((activity) =>
            activity.category.trim().toLowerCase() == name.trim().toLowerCase())
        .toList();
    return _ActivityCategoryRecap(
      category: name.trim(),
      activities: activities,
    );
  }).toList();
  final uncategorized =
      data.week.where((activity) => activity.category.trim().isEmpty).toList();
  if (uncategorized.isNotEmpty) {
    recaps.add(_ActivityCategoryRecap(
      category: 'Uncategorized',
      activities: uncategorized,
    ));
  }
  recaps.sort((a, b) {
    final countCompare = b.count.compareTo(a.count);
    if (countCompare != 0) return countCompare;
    return a.category.toLowerCase().compareTo(b.category.toLowerCase());
  });
  return recaps;
}

class _WeekMetricsView extends StatelessWidget {
  final _WeeklyActivityMetrics metrics;
  final AppColors c;

  const _WeekMetricsView({required this.metrics, required this.c});

  @override
  Widget build(BuildContext context) {
    final completionPercent = (metrics.completionRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.line, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Done',
                      value: '${metrics.totalDone}',
                      c: c,
                    ),
                  ),
                  Container(width: 1, height: 34, color: c.line),
                  Expanded(
                    child: _Metric(
                      label: 'Active days',
                      value: '${metrics.activeDays}/7',
                      c: c,
                    ),
                  ),
                  Container(width: 1, height: 34, color: c.line),
                  Expanded(
                    child: _Metric(
                      label: 'Completion',
                      value: '$completionPercent%',
                      c: c,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                metrics.rangeLabel,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle('Daily progress', c),
        const SizedBox(height: 10),
        if (metrics.totalDone == 0)
          _EmptyPanel(c: c, text: 'No activities completed in the last week.')
        else
          ...metrics.days.map((day) => _DayMetricRow(day: day, c: c)),
        if (metrics.topCategories.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle('By category', c),
          const SizedBox(height: 10),
          ...metrics.topCategories.map(
            (cat) => _CategoryCountRow(
              cat: cat,
              total: metrics.totalDone,
              c: c,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionTitle('Most completed', c),
        const SizedBox(height: 10),
        if (metrics.topActivities.isEmpty)
          _EmptyPanel(c: c, text: 'No weekly activity totals yet.')
        else
          ...metrics.topActivities.map(
            (activity) => _ActivityCountRow(activity: activity, c: c),
          ),
      ],
    );
  }
}

class _DayMetricRow extends StatelessWidget {
  final _DayMetric day;
  final AppColors c;

  const _DayMetricRow({required this.day, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.label,
                  style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
                ),
                Text(
                  day.dateLabel,
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: day.ratio,
                backgroundColor: c.line2,
                valueColor: AlwaysStoppedAnimation<Color>(c.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 28,
            child: Text(
              '${day.count}',
              textAlign: TextAlign.right,
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCountRow extends StatelessWidget {
  final _CategoryCount cat;
  final int total;
  final AppColors c;

  const _CategoryCountRow({
    required this.cat,
    required this.total,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : cat.count / total;
    final color = _categoryColor(cat.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.category,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: ratio,
                    backgroundColor: c.line2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${cat.count}',
            style: TextStyle(
              color: c.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCountRow extends StatelessWidget {
  final _ActivityCount activity;
  final AppColors c;

  const _ActivityCountRow({required this.activity, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${activity.count}',
            style: TextStyle(
              color: c.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final ActivityTemplate template;
  final bool doneToday;
  final AppColors c;
  final VoidCallback onDone;
  final VoidCallback onRemove;

  const _TemplateTile({
    required this.template,
    required this.doneToday,
    required this.c,
    required this.onDone,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            doneToday ? Icons.check_circle_rounded : Icons.task_alt_rounded,
            color: doneToday ? c.pos : c.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (template.category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _CategoryChip(category: template.category, color: c.muted),
                ],
                if (template.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    template.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: doneToday ? null : onDone,
            icon: Icon(
              doneToday ? Icons.done_all_rounded : Icons.done_rounded,
              size: 18,
            ),
            label: Text(doneToday ? 'Done' : 'Done today'),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _DoneActivityTile extends StatelessWidget {
  final DailyActivity activity;
  final AppColors c;
  final VoidCallback onRemove;

  const _DoneActivityTile({
    required this.activity,
    required this.c,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final doneTime = DateTime.tryParse(activity.doneAt)?.toLocal();
    final timeLabel = doneTime == null
        ? ''
        : '${doneTime.hour.toString().padLeft(2, '0')}:${doneTime.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: c.pos),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (activity.category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _CategoryChip(category: activity.category, color: c.muted),
                ],
                if (activity.notes.trim().isNotEmpty || timeLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      [
                        if (timeLabel.isNotEmpty) timeLabel,
                        if (activity.notes.trim().isNotEmpty) activity.notes,
                      ].join(' - '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove from today',
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final Color color;

  const _CategoryChip({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _categoryColor(String category) {
  const palette = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFFF5722),
    Color(0xFF009688),
  ];
  final hash = category.codeUnits.fold(0, (sum, c) => sum + c);
  return palette[hash % palette.length];
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

DateTime _parseDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(parts[0]) ?? DateTime.now().year,
    int.tryParse(parts[1]) ?? DateTime.now().month,
    int.tryParse(parts[2]) ?? DateTime.now().day,
  );
}

String _shortDate(DateTime date) => '${date.month}/${date.day}';

String _weekdayLabel(DateTime date) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[date.weekday - 1];
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
        color: c.ink,
        fontWeight: FontWeight.w700,
        fontSize: 16,
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
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Text(text, style: TextStyle(color: c.muted)),
    );
  }
}
