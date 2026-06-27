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

enum _ActivityViewMode { today, week }

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
    ]);
    return _ActivityViewData(
      templates: results[0] as List<ActivityTemplate>,
      today: results[1] as List<DailyActivity>,
      week: results[2] as List<DailyActivity>,
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

  void _selectMode(_ActivityViewMode mode) {
    setState(() => _mode = mode);
  }

  Future<void> _addTemplate() async {
    final result = await showDialog<_TemplateDraft>(
      context: context,
      builder: (dialogContext) => const _TemplateDialog(),
    );
    if (result == null || result.title.trim().isEmpty) return;
    await Repo.instance.createActivityTemplate(
      title: result.title.trim(),
      notes: result.notes.trim(),
      category: result.category.trim(),
    );
    await _refresh();
  }

  Future<void> _doneToday(ActivityTemplate template) async {
    await Repo.instance.markActivityDoneToday(template);
    await _refresh();
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
    await _refresh();
  }

  Future<void> _removeActivity(DailyActivity activity) async {
    await Repo.instance.removeDailyActivity(activity);
    await _refresh();
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
        final data = snapshot.data ?? _lastData ?? _ActivityViewData.empty();
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
                  ],
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
            ] else ...[
              _SectionTitle('Last 7 days', c),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                _EmptyPanel(c: c, text: 'Could not load activity metrics.')
              else
                _WeekMetricsView(metrics: weekMetrics, c: c),
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
  final DateTime weekStart;
  final DateTime weekEnd;

  const _ActivityViewData({
    required this.templates,
    required this.today,
    required this.week,
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
      weekStart: weekStart,
      weekEnd: now,
    );
  }
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
  const _TemplateDialog();

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _titleCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _categoryCtl = TextEditingController();

  @override
  void dispose() {
    _titleCtl.dispose();
    _notesCtl.dispose();
    _categoryCtl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _TemplateDraft(
        title: _titleCtl.text,
        notes: _notesCtl.text,
        category: _categoryCtl.text,
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
          TextField(
            controller: _categoryCtl,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'e.g. Health, Work, Exercise',
            ),
            textInputAction: TextInputAction.next,
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
        .map((entry) =>
            _CategoryCount(category: entry.key, count: entry.value))
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
                  _CategoryChip(
                      category: template.category, color: c.muted),
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
                  _CategoryChip(
                      category: activity.category, color: c.muted),
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
