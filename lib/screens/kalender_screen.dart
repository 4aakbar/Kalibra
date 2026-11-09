import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/occurrences.dart';
import '../ui/schedule_items.dart';
import '../ui/theme.dart';
import '../ui/tour.dart';
import '../ui/widgets.dart';
import 'deadline_screen.dart' show openNewForm;
import 'home_shell.dart';

const _hourHeight = 52.0;

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});
  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  DateTime selected = startOfDay(DateTime.now());
  final filter = <CategoryId>{};

  void _shift(CalendarView view, int dir) => setState(() {
        selected = switch (view) {
          CalendarView.bulan => startOfDay(addMonths(selected, dir)),
          CalendarView.minggu => addDays(selected, 7 * dir),
          CalendarView.hari => addDays(selected, dir),
        };
      });

  void _select(DateTime d) => setState(() => selected = startOfDay(d));

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final view = app.prefs.calendarView;
    final today = startOfDay(DateTime.now());
    final visible = filter.isEmpty ? app.schedules : app.schedules.where((s) => filter.contains(s.category)).toList();

    final Widget body;
    if (app.schedules.isEmpty) {
      body = SingleChildScrollView(
        child: EmptyState(
          icon: Icons.calendar_month_rounded,
          title: 'Belum ada jadwal',
          body: 'Coba ketik di Chat: "Kuliah BasDat tiap Senin jam 8"',
          actionLabel: 'Buka Chat',
          onAction: () => openChatWith('Kuliah BasDat tiap Senin jam 8'),
        ),
      );
    } else {
      body = switch (view) {
        CalendarView.bulan => _MonthView(schedules: visible, selected: selected, onSelect: _select),
        CalendarView.minggu => _WeekView(
            schedules: visible,
            selected: selected,
            onSelect: _select,
            onLongPressSlot: (d) => openNewForm(context, ScheduleKind.acara, start: d),
          ),
        CalendarView.hari => _DayView(schedules: visible, selected: selected, onSelect: _select),
      };
    }

    return Stack(children: [
      Column(children: [
        const TabHeader(title: 'Kalender'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'Sebelumnya', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(view, -1)),
              Expanded(
                child: Text(view == CalendarView.hari ? formatLongDate(selected) : monthTitle(selected),
                    textAlign: TextAlign.center, style: KText.title.copyWith(color: c.ink)),
              ),
              IconButton(tooltip: 'Berikutnya', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _shift(view, 1)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Segmented<CalendarView>(
                  key: TourKeys.viewSwitch,
                  value: view,
                  options: const [(CalendarView.bulan, 'Bulan'), (CalendarView.minggu, 'Minggu'), (CalendarView.hari, 'Hari')],
                  onChanged: (v) => app.setPrefs((p) => p.copyWith(calendarView: v)),
                ),
              ),
              if (!isSameDay(selected, today)) ...[
                const SizedBox(width: 10),
                KChip(label: 'Hari ini', onTap: () => _select(today)),
              ],
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                KChip(label: 'Semua', selected: filter.isEmpty, onTap: () => setState(filter.clear)),
                for (final id in CategoryId.values) ...[
                  const SizedBox(width: 8),
                  CategoryChip(
                    id: id,
                    selected: filter.contains(id),
                    onTap: () => setState(() => filter.contains(id) ? filter.remove(id) : filter.add(id)),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        Expanded(child: body),
      ]),
      Positioned(
        right: 20,
        bottom: 20,
        child: KFab(
          label: 'Tambah jadwal manual',
          color: c.cat(CategoryId.organisasi).solid,
          onPressed: () {
            final n = DateTime.now();
            openNewForm(context, ScheduleKind.acara,
                start: DateTime(selected.year, selected.month, selected.day, math.min(n.hour + 1, 23)));
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Bulan

class _MonthView extends StatelessWidget {
  const _MonthView({required this.schedules, required this.selected, required this.onSelect});
  final List<Schedule> schedules;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final grid = monthGrid(selected);
    final occ = occurrencesInRange(schedules, grid.first, endOfDay(grid.last));
    final byDay = <String, List<Occurrence>>{};
    for (final o in occ) {
      // Acara multi-hari muncul di setiap tanggal yang dilewati.
      var d = startOfDay(o.start);
      while (!d.isAfter(o.end)) {
        byDay.putIfAbsent(dateKey(d), () => []).add(o);
        if (o.schedule.isDeadline) break;
        d = addDays(d, 1);
      }
    }
    final now = DateTime.now();
    final dayItems = byDay[dateKey(selected)] ?? const <Occurrence>[];

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      KCard(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            for (final h in hariSingkat)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(h, textAlign: TextAlign.center, style: KText.caption.copyWith(color: c.inkMuted)),
                ),
              ),
          ]),
          for (var row = 0; row < 6; row++)
            Row(children: [
              for (final d in grid.sublist(row * 7, row * 7 + 7))
                Expanded(child: _MonthCell(day: d, selected: selected, now: now, items: byDay[dateKey(d)] ?? const [], onTap: onSelect)),
            ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text(formatLongDate(selected), style: KText.title.copyWith(color: c.ink)),
      const SizedBox(height: 10),
      if (dayItems.isEmpty)
        Text('Kosong. Hari santai.', style: KText.body.copyWith(color: c.inkMuted))
      else
        for (final o in dayItems)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: OccurrenceCard(occ: o)),
    ]);
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day, required this.selected, required this.now, required this.items, required this.onTap});
  final DateTime day;
  final DateTime selected;
  final DateTime now;
  final List<Occurrence> items;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final inMonth = day.month == selected.month;
    final isSel = isSameDay(day, selected);
    final isToday = isSameDay(day, now);
    final late = items.any((o) => o.schedule.isDeadline && !o.schedule.done && o.start.isBefore(now));
    return Semantics(
      button: true,
      label: '${day.day} ${bulan[day.month - 1]}, ${items.isEmpty ? 'kosong' : '${items.length} kegiatan'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(day),
        child: Opacity(
          opacity: inMonth ? 1 : 0.35,
          child: SizedBox(
            height: 54,
            child: Column(children: [
              const SizedBox(height: 4),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSel ? c.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSel ? Border.all(color: c.primary, width: 2) : null,
                ),
                child: Text('${day.day}', style: KText.label.copyWith(color: isSel ? Colors.white : c.ink)),
              ),
              const SizedBox(height: 3),
              _DayMarkers(items: items, late: late),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 1–3 kegiatan = titik per kegiatan; 4+ = bar warna + angka. Deadline = titik bercincin.
class _DayMarkers extends StatelessWidget {
  const _DayMarkers({required this.items, required this.late});
  final List<Occurrence> items;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    if (items.isEmpty) return const SizedBox(height: 8);
    if (items.length <= 3) {
      return SizedBox(
        height: 8,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final o in items)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: o.schedule.isDeadline ? Colors.transparent : c.cat(o.schedule.category).solid,
                border: o.schedule.isDeadline
                    ? Border.all(
                        color: late && !o.schedule.done ? c.danger : c.cat(o.schedule.category).solid, width: 2)
                    : null,
              ),
            ),
        ]),
      );
    }
    final cats = items.map((o) => o.schedule.category).toSet().take(3).toList();
    return SizedBox(
      height: 10,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final k in cats)
          Container(
            width: 6,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: c.cat(k).solid, borderRadius: BorderRadius.circular(2)),
          ),
        Text('+${items.length - cats.length}', style: KText.caption.copyWith(fontSize: 9, height: 1, color: c.inkMuted)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Minggu

class _WeekView extends StatelessWidget {
  const _WeekView({required this.schedules, required this.selected, required this.onSelect, required this.onLongPressSlot});
  final List<Schedule> schedules;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onLongPressSlot;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final prefs = context.select<AppState, Preferences>((a) => a.prefs);
    final monday = startOfWeek(selected);
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final occ = occurrencesInRange(schedules, monday, endOfDay(days.last));
    final startMin = hhmmToMinutes(prefs.dayStart);
    final startHour = math.max(0, startMin ~/ 60 - 1);
    final endMin = hhmmToMinutes(prefs.dayEnd);
    final endHour = endMin <= startMin ? 24 : math.min(24, (endMin / 60).ceil() + 1);
    final hours = [for (var h = startHour; h < endHour; h++) h];
    final now = DateTime.now();
    final timed = occ.where((o) => !o.schedule.allDay && !o.schedule.isDeadline).toList();
    final allDay = occ.where((o) => o.schedule.allDay || o.schedule.isDeadline).toList();

    return Column(children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(left: 44, right: 8),
        child: Row(children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                button: true,
                label: formatLongDate(d),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(d),
                  child: Column(children: [
                    Text(dayShort(d), style: KText.caption.copyWith(color: c.inkMuted)),
                    const SizedBox(height: 2),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSameDay(d, selected) ? c.primary : Colors.transparent,
                        border: isSameDay(d, now) && !isSameDay(d, selected) ? Border.all(color: c.primary, width: 2) : null,
                      ),
                      child: Text('${d.day}',
                          style: KText.label.copyWith(color: isSameDay(d, selected) ? Colors.white : c.ink)),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      if (allDay.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 44, right: 8, top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final d in days)
              Expanded(
                child: Builder(builder: (context) {
                  final items = allDay.where((o) => isSameDay(o.start, d)).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final o in items.take(2))
                        Semantics(
                          button: true,
                          label: o.schedule.title,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => openDetail(context, o.schedule.id, o.dateKey),
                            child: Opacity(
                              opacity: o.schedule.done ? 0.5 : 1,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.cat(o.schedule.category).soft,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border(left: BorderSide(color: c.cat(o.schedule.category).solid, width: 3)),
                                ),
                                child: Text(o.schedule.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KText.caption.copyWith(fontSize: 10, height: 1.3, color: c.ink)),
                              ),
                            ),
                          ),
                        ),
                      if (items.length > 2)
                        Text('+${items.length - 2}', style: KText.caption.copyWith(fontSize: 10, color: c.inkMuted)),
                    ]),
                  );
                }),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      Container(height: 1, color: c.line),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                for (final h in hours)
                  SizedBox(
                    height: _hourHeight,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Transform.translate(
                        offset: const Offset(0, -6),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text('${(h % 24).toString().padLeft(2, '0')}.00',
                              style: KText.caption.copyWith(fontSize: 10, color: c.inkMuted)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final d in days)
                    Expanded(
                      child: _WeekColumn(
                        day: d,
                        hours: hours,
                        startHour: startHour,
                        endHour: endHour,
                        items: timed.where((o) => isSameDay(o.start, d)).toList(),
                        now: now,
                        onLongPressSlot: onLongPressSlot,
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.day,
    required this.hours,
    required this.startHour,
    required this.endHour,
    required this.items,
    required this.now,
    required this.onLongPressSlot,
  });
  final DateTime day;
  final List<int> hours;
  final int startHour;
  final int endHour;
  final List<Occurrence> items;
  final DateTime now;
  final ValueChanged<DateTime> onLongPressSlot;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Container(
        height: hours.length * _hourHeight,
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.gridLine))),
        child: Stack(children: [
          Column(children: [
            for (final h in hours)
              Semantics(
                label: 'Slot ${h.toString().padLeft(2, '0')}.00, tekan lama untuk tambah',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => onLongPressSlot(DateTime(day.year, day.month, day.day, h)),
                  child: Container(
                    height: _hourHeight,
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.gridLine, width: 0.5))),
                  ),
                ),
              ),
          ]),
          for (final (o, col, cols) in layoutColumns(items))
            Positioned(
              top: ((o.start.hour * 60 + o.start.minute) / 60 - startHour) * _hourHeight,
              height: math.max(o.end.difference(o.start).inMinutes / 60 * _hourHeight, 22),
              left: w * col / cols,
              width: w / cols,
              child: Semantics(
                button: true,
                label: '${o.schedule.title}, ${formatTime(o.start)}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => openDetail(context, o.schedule.id, o.dateKey),
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: c.cat(o.schedule.category).soft,
                        borderRadius: BorderRadius.circular(5),
                        border: Border(left: BorderSide(color: c.cat(o.schedule.category).solid, width: 3)),
                      ),
                      child: Text(o.schedule.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: KText.caption.copyWith(fontSize: 10, height: 1.2, color: c.cat(o.schedule.category).ink)),
                    ),
                  ),
                ),
              ),
            ),
          if (isSameDay(day, now) && now.hour >= startHour && now.hour < endHour)
            Positioned(
              left: 0,
              right: 0,
              top: ((now.hour * 60 + now.minute) / 60 - startHour) * _hourHeight,
              child: IgnorePointer(child: Container(height: 2, color: c.danger)),
            ),
        ]),
      );
    });
  }
}

/// Acara yang bentrok tampil berdampingan: (kejadian, kolom, jumlah kolom).
List<(Occurrence, int, int)> layoutColumns(List<Occurrence> items) {
  final out = <(Occurrence, int, int)>[];
  var group = <(Occurrence, int)>[];
  DateTime? groupEnd;
  void flush() {
    final cols = group.fold<int>(1, (m, g) => math.max(m, g.$2 + 1));
    for (final g in group) {
      out.add((g.$1, g.$2, cols));
    }
    group = [];
  }

  final sorted = [...items]..sort((a, b) => a.start.compareTo(b.start));
  for (final o in sorted) {
    if (group.isNotEmpty && groupEnd != null && !o.start.isBefore(groupEnd)) flush();
    final used = group.where((g) => g.$1.end.isAfter(o.start)).map((g) => g.$2).toSet();
    var col = 0;
    while (used.contains(col)) {
      col++;
    }
    group.add((o, col));
    groupEnd = groupEnd == null || o.end.isAfter(groupEnd) ? o.end : groupEnd;
  }
  if (group.isNotEmpty) flush();
  return out;
}

// ---------------------------------------------------------------------------
// Hari

class _DayView extends StatelessWidget {
  const _DayView({required this.schedules, required this.selected, required this.onSelect});
  final List<Schedule> schedules;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final strip = [for (var i = -3; i <= 3; i++) addDays(selected, i)];
    final occ = occurrencesOnDay(schedules, selected);
    final allDay = occ.where((o) => o.schedule.allDay || o.schedule.isDeadline).toList();
    final timed = occ.where((o) => !o.schedule.allDay && !o.schedule.isDeadline).toList();
    final kuliah = timed.where((o) => o.schedule.category == CategoryId.kuliah).length;
    final lain = timed.length - kuliah;
    final deadline = allDay.where((o) => o.schedule.isDeadline).length;
    final summary = [if (kuliah > 0) '$kuliah kuliah', if (lain > 0) '$lain acara lain', if (deadline > 0) '$deadline deadline'];
    final org = c.cat(CategoryId.organisasi);

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final d in strip)
          Semantics(
            button: true,
            selected: isSameDay(d, selected),
            label: formatLongDate(d),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelect(d),
              child: Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSameDay(d, selected) ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSameDay(d, selected) ? c.line : Colors.transparent, width: 1.5),
                ),
                child: Column(children: [
                  Text(dayShort(d), style: KText.caption.copyWith(color: isSameDay(d, selected) ? Colors.white : c.inkMuted)),
                  Text('${d.day}', style: KText.subtitle.copyWith(color: isSameDay(d, selected) ? Colors.white : c.ink)),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      KCard(
        color: org.soft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RINGKASAN HARI', style: KText.label.copyWith(color: org.ink, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            summary.isEmpty
                ? 'Nggak ada jadwal. Santai dulu.'
                : '${isSameDay(selected, DateTime.now()) ? 'Hari ini' : 'Hari itu'} ${summary.join(', ')}',
            style: KText.title.copyWith(color: c.ink),
          ),
        ]),
      ),
      if (allDay.isNotEmpty) ...[
        const SizedBox(height: 14),
        const SectionLabel('Seharian & deadline'),
        const SizedBox(height: 8),
        for (final o in allDay) Padding(padding: const EdgeInsets.only(bottom: 8), child: OccurrenceCard(occ: o, compact: true)),
      ],
      const SizedBox(height: 6),
      for (final o in timed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 46,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatTime(o.start), style: KText.label.copyWith(color: c.ink)),
                  Text(formatTime(o.end), style: KText.caption.copyWith(color: c.inkMuted)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OccurrenceCard(occ: o)),
          ]),
        ),
    ]);
  }
}
