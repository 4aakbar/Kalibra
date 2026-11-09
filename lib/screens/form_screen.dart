import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class FormArgs {
  final String? editId;

  /// Tanggal kejadian yang diedit (jadwal berulang).
  final String? dateKey;

  /// Isian awal (dari draf chat atau "Isi manual").
  final ScheduleInput? prefill;

  /// Draf chat asal, ditandai tersimpan setelah form disimpan.
  final ({String messageId, int index})? draftRef;

  const FormArgs({this.editId, this.dateKey, this.prefill, this.draftRef});
}

({int h, int m})? parseClock(String s) {
  final m = RegExp(r'^(\d{1,2})(?:[.:](\d{2}))?$').firstMatch(s.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2) ?? '0');
  if (h > 23 || min > 59) return null;
  return (h: h, m: min);
}

/// Akhir semester terdekat: semester gasal ~20 Desember, genap ~30 Juni.
DateTime endOfSemester(DateTime from) {
  if (from.month >= 8) return DateTime(from.year, 12, 20);
  if (from.month == 1) return DateTime(from.year, 1, 31);
  return DateTime(from.year, 6, 30);
}

enum _EditScope { one, following, all }

class FormScreen extends StatefulWidget {
  const FormScreen({super.key, required this.args});
  final FormArgs args;
  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  Schedule? existing;
  late ScheduleKind kind;
  late DateTime day;
  late bool allDay;
  late CategoryId category;
  late Priority priority;
  RecurrenceFreq? freq;
  String? until;
  late List<int> reminders;
  late bool showMore;
  late String _initialStartText;
  final title = TextEditingController();
  final startText = TextEditingController();
  final endText = TextEditingController();
  final location = TextEditingController();
  final link = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final prefs = app.prefs;
    existing = widget.args.editId == null ? null : app.byId(widget.args.editId!);
    final e = existing;
    final p = widget.args.prefill;

    final srcStart = e?.start ?? p?.start;
    final srcEnd = e?.end ?? p?.end;
    var start = srcStart ?? DateTime.now().add(const Duration(hours: 1));
    if (e?.recurrence != null && widget.args.dateKey != null) {
      final d = fromDateKey(widget.args.dateKey!);
      start = DateTime(d.year, d.month, d.day, start.hour, start.minute);
    } else if (srcStart == null) {
      start = DateTime(start.year, start.month, start.day, start.hour);
    }
    final end = srcEnd != null && srcStart != null ? start.add(srcEnd.difference(srcStart)) : start.add(const Duration(hours: 1));

    kind = e?.kind ?? p?.kind ?? ScheduleKind.acara;
    title.text = e?.title ?? p?.title ?? '';
    day = startOfDay(start);
    allDay = e?.allDay ?? p?.allDay ?? false;
    _initialStartText = formatTime(start);
    startText.text = srcStart == null && kind == ScheduleKind.deadline ? '23.59' : formatTime(start);
    endText.text = formatTime(end);
    category = e?.category ??
        p?.category ??
        (kind == ScheduleKind.deadline ? CategoryId.tugas : (prefs.categories.isEmpty ? CategoryId.kuliah : prefs.categories.first));
    priority = e?.priority ?? p?.priority ?? Priority.sedang;
    final rec = e?.recurrence ?? p?.recurrence;
    freq = rec?.freq;
    until = rec?.until;
    reminders = [...(e?.reminders ?? p?.reminders ?? [kind == ScheduleKind.deadline ? prefs.deadlineReminder : prefs.eventReminder])];
    location.text = e?.location ?? p?.location ?? '';
    link.text = e?.link ?? p?.link ?? '';
    notes.text = e?.notes ?? p?.notes ?? '';
    showMore = location.text.isNotEmpty || link.text.isNotEmpty || notes.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in [title, startText, endText, location, link, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEvent => kind == ScheduleKind.acara;
  String? get _timeError => !(_isEvent && allDay) && parseClock(startText.text) == null ? 'Format jam: 15.00' : null;
  String? get _endError => _isEvent && !allDay && parseClock(endText.text) == null ? 'Format jam: 16.00' : null;
  bool get _valid => title.text.trim().isNotEmpty && _timeError == null && _endError == null;

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  ScheduleInput? _build() {
    if (!_valid) return null;
    late DateTime start;
    DateTime? end;
    if (allDay && _isEvent) {
      start = day;
      end = DateTime(day.year, day.month, day.day, 23, 59);
    } else {
      final s = parseClock(startText.text)!;
      start = DateTime(day.year, day.month, day.day, s.h, s.m);
      if (_isEvent) {
        final en = parseClock(endText.text)!;
        end = DateTime(day.year, day.month, day.day, en.h, en.m);
        if (!end.isAfter(start)) end = addDays(end, 1);
      }
    }
    final t = title.text.trim();
    return ScheduleInput(
      kind: kind,
      title: t.length > 80 ? t.substring(0, 80) : t,
      start: start,
      end: end,
      allDay: _isEvent && allDay,
      category: category,
      priority: priority,
      recurrence: _isEvent && freq != null ? Recurrence(freq!, until: until) : null,
      reminders: reminders,
      location: _opt(location),
      link: _opt(link),
      notes: _opt(notes),
      source: existing?.source ?? widget.args.prefill?.source ?? 'manual',
    );
  }

  void _finish(String scheduleId, String message) {
    final ref = widget.args.draftRef;
    if (ref != null) context.read<AppState>().markDraftSaved(ref.messageId, ref.index, scheduleId);
    showToast(context, message);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final input = _build();
    if (input == null) return;
    final app = context.read<AppState>();
    final e = existing;
    if (e == null) {
      final s = app.addSchedule(input);
      _finish(s.id, 'Tersimpan ke Kalender');
      return;
    }
    final key = widget.args.dateKey;
    if (e.recurrence != null && key != null) {
      final scope = await showModalBottomSheet<_EditScope>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Ubah jadwal berulang', style: KText.title)),
            ListRow(icon: Icons.event_rounded, label: 'Hanya kejadian ini', onTap: () => Navigator.pop(sheet, _EditScope.one)),
            ListRow(
                icon: Icons.east_rounded, label: 'Kejadian ini dan berikutnya', onTap: () => Navigator.pop(sheet, _EditScope.following)),
            ListRow(icon: Icons.repeat_rounded, label: 'Semua kejadian', onTap: () => Navigator.pop(sheet, _EditScope.all)),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (!mounted || scope == null) return;
      switch (scope) {
        case _EditScope.one:
          app.skipOccurrence(e.id, key);
          input.recurrence = null;
          _finish(app.addSchedule(input).id, 'Kejadian ini diubah');
        case _EditScope.following:
          app.endRecurrenceBefore(e.id, key);
          _finish(app.addSchedule(input).id, 'Kejadian ini dan berikutnya diubah');
        case _EditScope.all:
          // Pertahankan tanggal mulai seri, ubah jam dan detailnya saja.
          final first = DateTime(e.start.year, e.start.month, e.start.day, input.start.hour, input.start.minute);
          final dur = input.end?.difference(input.start);
          input
            ..start = first
            ..end = dur == null ? null : first.add(dur);
          app.updateFromInput(e.id, input);
          _finish(e.id, 'Semua kejadian diubah');
      }
      return;
    }
    app.updateFromInput(e.id, input);
    _finish(e.id, 'Perubahan disimpan');
  }

  Widget _group(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: KText.label.copyWith(color: context.k.ink)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) setState(() => day = startOfDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final prefs = context.read<AppState>().prefs;
    final today = startOfDay(DateTime.now());
    final sem = endOfSemester(day);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          StackHeader(
            title: existing != null ? 'Edit jadwal' : 'Jadwal baru',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: KButton(label: 'Simpan', small: true, expand: false, onPressed: _valid ? _save : null),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Segmented<ScheduleKind>(
                  value: kind,
                  options: const [(ScheduleKind.acara, 'Acara'), (ScheduleKind.deadline, 'Deadline')],
                  onChanged: (k) => setState(() {
                    kind = k;
                    if (k == ScheduleKind.deadline && startText.text == _initialStartText && existing == null) {
                      startText.text = '23.59';
                    }
                    reminders = [k == ScheduleKind.deadline ? prefs.deadlineReminder : prefs.eventReminder];
                  }),
                ),
                const SizedBox(height: 18),
                KField(
                  label: 'Judul',
                  controller: title,
                  hint: kind == ScheduleKind.deadline ? 'Misal: TK SDA' : 'Misal: Kuliah BasDat',
                  maxLength: 80,
                  autofocus: existing == null && title.text.isEmpty,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                _group(
                  'Tanggal',
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.line, width: 1.5),
                      ),
                      child: Row(children: [
                        IconButton(
                          tooltip: 'Hari sebelumnya',
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => setState(() => day = addDays(day, -1)),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: Text(formatLongDate(day), textAlign: TextAlign.center, style: KText.subtitle.copyWith(color: c.ink)),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hari berikutnya',
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => setState(() => day = addDays(day, 1)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      KChip(label: 'Hari ini', selected: isSameDay(day, today), onTap: () => setState(() => day = today)),
                      KChip(
                          label: 'Besok',
                          selected: isSameDay(day, addDays(today, 1)),
                          onTap: () => setState(() => day = addDays(today, 1))),
                      KChip(label: '+1 minggu', onTap: () => setState(() => day = addDays(day, 7))),
                      KChip(label: 'Pilih tanggal', icon: Icons.calendar_month_rounded, onTap: _pickDate),
                    ]),
                  ]),
                ),
                if (_isEvent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(child: Text('Seharian', style: KText.label.copyWith(color: c.ink))),
                      Switch(value: allDay, onChanged: (v) => setState(() => allDay = v)),
                    ]),
                  ),
                if (!(_isEvent && allDay))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: KField(
                          label: _isEvent ? 'Mulai' : 'Jam tenggat',
                          controller: startText,
                          hint: '15.00',
                          maxLength: 5,
                          error: _timeError,
                          keyboardType: TextInputType.datetime,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_isEvent) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: KField(
                            label: 'Selesai',
                            controller: endText,
                            hint: '16.00',
                            maxLength: 5,
                            error: _endError,
                            keyboardType: TextInputType.datetime,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ]),
                  ),
                _group(
                  'Kategori',
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final id in CategoryId.values)
                      CategoryChip(id: id, selected: category == id, onTap: () => setState(() => category = id)),
                  ]),
                ),
                if (_isEvent)
                  _group(
                    'Pengulangan',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        KChip(label: 'Tidak berulang', selected: freq == null, onTap: () => setState(() => freq = null)),
                        for (final f in RecurrenceFreq.values)
                          KChip(label: freqLabel[f]!, selected: freq == f, onTap: () => setState(() => freq = f)),
                      ]),
                      if (freq != null) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text('Berakhir:', style: KText.caption.copyWith(color: c.inkMuted)),
                          KChip(label: 'Tidak pernah', selected: until == null, onTap: () => setState(() => until = null)),
                          KChip(
                            label: 'Akhir semester (${sem.day} ${bulan[sem.month - 1]})',
                            selected: until == dateKey(sem),
                            onTap: () => setState(() => until = dateKey(sem)),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                _group(
                  'Pengingat',
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (m, label) in reminderOptions)
                      KChip(
                        label: label,
                        selected: reminders.contains(m),
                        onTap: () => setState(() {
                          reminders.contains(m) ? reminders.remove(m) : reminders.add(m);
                          reminders.sort();
                        }),
                      ),
                  ]),
                ),
                _group(
                  'Prioritas',
                  Segmented<Priority>(
                    value: priority,
                    options: [for (final p in Priority.values) (p, priorityLabel[p]!)],
                    onChanged: (p) => setState(() => priority = p),
                  ),
                ),
                if (showMore) ...[
                  KField(label: 'Lokasi', controller: location, hint: 'Misal: Gedung A 2.2302'),
                  const SizedBox(height: 18),
                  KField(
                    label: 'Link',
                    controller: link,
                    hint: 'Zoom, SCeLe, dll.',
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 18),
                  KField(label: 'Catatan', controller: notes, hint: 'Catatan tambahan', maxLines: 5),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KButton(
                      label: 'Tambah lokasi, link, catatan',
                      icon: Icons.add_rounded,
                      kind: KButtonKind.ghost,
                      small: true,
                      expand: false,
                      onPressed: () => setState(() => showMore = true),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
