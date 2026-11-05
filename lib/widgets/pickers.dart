import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../domain/schedule.dart';
import 'ui.dart';

/// 4-column grid of income or expense categories.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.type, required this.value, required this.onChanged});
  final String type, value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = categoriesFor(type);
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth + 8) / 4 - 8;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in cats)
              GestureDetector(
                onTap: () {
                  haptic();
                  onChanged(cat.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: cat.id == value ? tint(hex(cat.color), 0.08) : c.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cat.id == value ? hex(cat.color) : Colors.transparent, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tint(hex(cat.color), 0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(appIcon(cat.icon), size: 18, color: hex(cat.color)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: T(
                          cat.name,
                          v: TV.caption,
                          maxLines: 1,
                          align: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cash / UPI / Card / Bank selector.
class MethodPicker extends StatelessWidget {
  const MethodPicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: gap(
        [
          for (final m in paymentMethods)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  haptic();
                  onChanged(m.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == m.id ? c.primarySoft : c.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: value == m.id ? c.primary : c.border, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(appIcon(m.icon), size: 20, color: value == m.id ? c.primary : c.textMuted),
                      const SizedBox(height: 4),
                      T(
                        m.name,
                        v: TV.caption,
                        color: value == m.id ? c.primary : c.textMuted,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        8,
        horizontal: true,
      ),
    );
  }
}

const _offsetOptions = [(7, '7 days before'), (3, '3 days before'), (1, '1 day before'), (0, 'On due date')];

/// Which days before a due date to send reminders.
class ReminderOffsets extends StatelessWidget {
  const ReminderOffsets({super.key, required this.value, required this.onChanged});
  final List<int> value;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, // left-aligned, whatever the parent's alignment
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (d, label) in _offsetOptions)
          AppChip(
            label: label,
            icon: value.contains(d) ? 'checkmark' : null,
            active: value.contains(d),
            onTap: () => onChanged(
              value.contains(d) ? value.where((x) => x != d).toList() : ([...value, d]..sort((a, b) => b - a)),
            ),
          ),
      ],
    ),
  );
}

/// Human-readable summary of reminder offsets, e.g. "7d before, on due date".
String offsetsLabel(List<int> offsets) => offsets.map((d) => d == 0 ? 'on due date' : '${d}d before').join(', ');

/// Tappable field that opens the platform date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.minimumDate});
  final String value;
  final ValueChanged<String> onChanged;
  final String? minimumDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ScalePress(
      onTap: () async {
        final current = parseISO(value);
        final first = minimumDate != null ? parseISO(minimumDate!) : DateTime(2000);
        final picked = await showDatePicker(
          context: context,
          initialDate: current.isBefore(first) ? first : current,
          firstDate: first,
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(toISO(picked));
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(appIcon('calendar-outline'), size: 18, color: c.textFaint),
            const SizedBox(width: 10),
            Expanded(child: T(fmtLong(value))),
            Icon(appIcon('chevron-down'), size: 16, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Month grid with coloured dots for payment due dates.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.onMonthChange,
    required this.selected,
    required this.onSelect,
    required this.items,
  });
  final String month, selected;
  final ValueChanged<String> onMonthChange, onSelect;
  final List<Occurrence> items;

  static const _week = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = parseISO('$month-01');
    final lead = first.weekday - 1; // Monday first
    final total = daysInMonth(first.year, first.month);
    final today = todayISO();
    final byDay = <String, List<Occurrence>>{};
    for (final o in items) {
      (byDay[o.dueDate] ??= []).add(o);
    }
    final cells = <String?>[
      ...List.filled(lead, null),
      for (var i = 1; i <= total; i++) '$month-${i.toString().padLeft(2, '0')}',
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    Color dot(Occurrence o) => switch (o.status) {
      OccStatus.paid => c.income,
      OccStatus.overdue => c.expense,
      OccStatus.pending => c.orange,
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppIconButton(
              icon: 'chevron-back',
              tooltip: 'Previous month',
              bg: c.cardAlt,
              size: 34,
              onTap: () => onMonthChange(shiftMonthKey(month, -1)),
            ),
            Expanded(
              child: T(monthLabel(month, long: true), v: TV.h3, align: TextAlign.center, maxLines: 1),
            ),
            AppIconButton(
              icon: 'chevron-forward',
              tooltip: 'Next month',
              bg: c.cardAlt,
              size: 34,
              onTap: () => onMonthChange(shiftMonthKey(month, 1)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in _week)
              Expanded(
                child: T(d, v: TV.caption, faint: true, align: TextAlign.center),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var r = 0; r < cells.length / 7; r++)
          Row(
            children: [
              for (final d in cells.sublist(r * 7, r * 7 + 7))
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: d == null
                        ? null
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              haptic();
                              onSelect(d);
                            },
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: d == selected ? c.primary : (d == today ? c.primarySoft : Colors.transparent),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    T(
                                      '${int.parse(d.substring(8))}',
                                      v: TV.label,
                                      color: d == selected ? Colors.white : (d == today ? c.primary : c.text),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      child: Row(
                                        children: [
                                          for (final o in (byDay[d] ?? const <Occurrence>[]).take(3))
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: d == selected ? Colors.white : dot(o),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
