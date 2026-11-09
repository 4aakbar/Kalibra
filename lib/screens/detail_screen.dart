import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../ui/schedule_items.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'form_screen.dart';

class DetailArgs {
  final String id;

  /// Tanggal kejadian yang dibuka (untuk jadwal berulang).
  final String? dateKey;
  const DetailArgs(this.id, {this.dateKey});
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.args});
  final DetailArgs args;

  Future<void> _remove(BuildContext context, Schedule s) async {
    final key = args.dateKey;
    if (s.recurrence != null && key != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Hapus jadwal berulang', style: KText.title)),
            ListRow(icon: Icons.event_busy_rounded, label: 'Hanya kejadian ini', onTap: () => Navigator.pop(sheet, 'one')),
            ListRow(icon: Icons.delete_sweep_outlined, label: 'Semua kejadian', danger: true, onTap: () => Navigator.pop(sheet, 'all')),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (!context.mounted || choice == null) return;
      final app = context.read<AppState>();
      if (choice == 'one') {
        final before = s.exdates;
        app.skipOccurrence(s.id, key);
        showToast(context, 'Kejadian ini dihapus', actionLabel: 'Urungkan', onAction: () {
          final cur = app.byId(s.id);
          if (cur != null) app.replaceSchedule(cur.copyWith(exdates: before));
        });
      } else {
        deleteWithUndo(context, s.id);
      }
      Navigator.pop(context);
      return;
    }
    deleteWithUndo(context, s.id);
    Navigator.pop(context);
  }

  void _duplicate(BuildContext context, Schedule s) {
    final app = context.read<AppState>();
    final copy = app.addSchedule(ScheduleInput(
      kind: s.kind,
      title: '${s.title} (salinan)',
      start: s.start,
      end: s.end,
      allDay: s.allDay,
      category: s.category,
      priority: s.priority,
      recurrence: s.recurrence,
      reminders: s.reminders,
      location: s.location,
      notes: s.notes,
      link: s.link,
    ));
    showToast(context, 'Jadwal diduplikat');
    Navigator.pushReplacementNamed(context, '/jadwal', arguments: DetailArgs(copy.id));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final s = context.select<AppState, Schedule?>((a) => a.byId(args.id));
    if (s == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const StackHeader(title: 'Detail'),
            EmptyState(
              icon: Icons.block_rounded,
              title: 'Jadwal nggak ditemukan',
              body: 'Mungkin sudah dihapus.',
              actionLabel: 'Kembali',
              onAction: () => Navigator.maybePop(context),
            ),
          ]),
        ),
      );
    }

    var start = s.start;
    if (args.dateKey != null && s.recurrence != null) {
      final d = fromDateKey(args.dateKey!);
      start = DateTime(d.year, d.month, d.day, s.start.hour, s.start.minute);
    }
    final end = s.end == null ? null : start.add(s.end!.difference(s.start));
    final col = c.cat(s.category);
    final when = s.allDay
        ? '${formatLongDate(start)} · Seharian'
        : s.isDeadline
            ? '${formatLongDate(start)} · tenggat ${formatTime(start)}'
            : '${formatLongDate(start)} · ${formatTime(start)}–${formatTime(end ?? start)}';

    String? repeat;
    if (s.recurrence != null) {
      final r = s.recurrence!;
      repeat = '${freqLabel[r.freq]}'
          '${r.until != null ? ' sampai ${formatShortDate(fromDateKey(r.until!))}' : ''}'
          '${s.exdates.isNotEmpty ? ' · ${s.exdates.length} dilewati' : ''}';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          StackHeader(title: s.isDeadline ? 'Detail deadline' : 'Detail jadwal'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              KCard(
                color: col.soft,
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    CategoryChip(id: s.category, small: true),
                    if (s.priority != Priority.sedang)
                      _Tag(
                        icon: Icons.flag_rounded,
                        text: 'Prioritas ${priorityLabel[s.priority]!.toLowerCase()}',
                        color: s.priority == Priority.tinggi ? c.danger : c.inkMuted,
                      ),
                    if (s.done) _Tag(icon: Icons.check_circle_rounded, text: 'Selesai', color: c.success),
                  ]),
                  const SizedBox(height: 10),
                  Text(s.title,
                      style: KText.display.copyWith(color: c.ink, decoration: s.done ? TextDecoration.lineThrough : null)),
                ]),
              ),
              const SizedBox(height: 16),
              KCard(
                child: Column(children: [
                  _Info(icon: Icons.calendar_today_rounded, label: 'Waktu', value: when),
                  if (repeat != null) _Info(icon: Icons.repeat_rounded, label: 'Pengulangan', value: repeat),
                  if (s.location != null) _Info(icon: Icons.place_outlined, label: 'Lokasi', value: s.location!),
                  if (s.link != null)
                    _Info(
                      icon: Icons.link_rounded,
                      label: 'Link',
                      value: s.link!,
                      onTap: () => launchUrl(Uri.parse(s.link!.startsWith('http') ? s.link! : 'https://${s.link}'),
                          mode: LaunchMode.externalApplication),
                    ),
                  if (s.notes != null) _Info(icon: Icons.notes_rounded, label: 'Catatan', value: s.notes!),
                  _Info(
                    icon: Icons.notifications_none_rounded,
                    label: 'Pengingat',
                    value: s.reminders.isEmpty ? 'Tidak ada' : s.reminders.map(reminderLabel).join(', '),
                  ),
                  _Info(
                    icon: s.source == 'chat' ? Icons.chat_bubble_outline_rounded : Icons.edit_outlined,
                    label: 'Sumber',
                    value:
                        'Dibuat lewat ${s.source == 'chat' ? 'chat' : 'form'}, ${formatShortDate(s.createdAt)} ${formatTime(s.createdAt)}',
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (s.isDeadline) ...[
                KButton(
                  label: s.done ? 'Batalkan selesai' : 'Tandai selesai',
                  icon: s.done ? Icons.undo_rounded : Icons.check_rounded,
                  onPressed: () => toggleDoneWithUndo(context, s.id),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(spacing: 10, runSpacing: 10, children: [
                KButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  kind: KButtonKind.secondary,
                  small: true,
                  expand: false,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/form', arguments: FormArgs(editId: s.id, dateKey: args.dateKey)),
                ),
                KButton(
                  label: 'Duplikat',
                  icon: Icons.copy_rounded,
                  kind: KButtonKind.secondary,
                  small: true,
                  expand: false,
                  onPressed: () => _duplicate(context, s),
                ),
                KButton(
                  label: 'Hapus',
                  icon: Icons.delete_outline_rounded,
                  kind: KButtonKind.danger,
                  small: true,
                  expand: false,
                  onPressed: () => _remove(context, s),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: KText.caption.copyWith(color: color)),
      ]);
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value, this.onTap, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: c.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: KText.caption.copyWith(color: c.inkMuted)),
            GestureDetector(
              onTap: onTap,
              child: Text(value,
                  style: KText.body.copyWith(
                    color: onTap != null ? c.primary : c.ink,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  )),
            ),
          ]),
        ),
      ]),
    );
  }
}
