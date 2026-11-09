import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/occurrences.dart';
import '../screens/detail_screen.dart';
import '../screens/form_screen.dart';
import 'theme.dart';
import 'widgets.dart';

void openDetail(BuildContext context, String id, [String? dateKey]) =>
    Navigator.pushNamed(context, '/jadwal', arguments: DetailArgs(id, dateKey: dateKey));

/// Hapus dengan toast Urungkan 5 detik, bukan dialog konfirmasi (sesuai spesifikasi).
void deleteWithUndo(BuildContext context, String id) {
  final app = context.read<AppState>();
  final removed = app.deleteSchedule(id);
  if (removed == null) return;
  showToast(context, 'Jadwal dihapus', actionLabel: 'Urungkan', onAction: () => app.restoreSchedule(removed));
}

void toggleDoneWithUndo(BuildContext context, String id) {
  final app = context.read<AppState>();
  final before = app.byId(id);
  if (before == null) return;
  app.toggleDone(id);
  if (!before.done) showToast(context, 'Selesai', actionLabel: 'Urungkan', onAction: () => app.toggleDone(id));
}

/// Kartu acara di daftar agenda.
class OccurrenceCard extends StatelessWidget {
  const OccurrenceCard({super.key, required this.occ, this.compact = false});
  final Occurrence occ;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final s = occ.schedule;
    final col = c.cat(s.category);
    final time = s.allDay
        ? 'Seharian'
        : s.isDeadline
            ? 'Tenggat ${formatTime(occ.start)}'
            : '${formatTime(occ.start)}–${formatTime(occ.end)}';
    return Semantics(
      button: true,
      label: '${s.title}, $time${s.location != null ? ', ${s.location}' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => openDetail(context, s.id, occ.dateKey),
        child: Opacity(
          opacity: s.isDeadline && s.done ? 0.6 : 1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: col.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: col.solid),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (s.isDeadline) ...[
                          Icon(s.done ? Icons.check_circle_rounded : Icons.flag_rounded, size: 13, color: col.ink),
                          const SizedBox(width: 5),
                        ],
                        Text(time, style: KText.caption.copyWith(color: col.ink)),
                        if (s.recurrence != null) ...[const SizedBox(width: 6), Icon(Icons.repeat_rounded, size: 13, color: col.ink)],
                        if (s.priority == Priority.tinggi) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.error_outline_rounded, size: 13, color: c.danger),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        s.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: KText.subtitle.copyWith(
                          color: c.ink,
                          decoration: s.isDeadline && s.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (!compact && s.location != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.place_outlined, size: 13, color: c.inkSoft),
                          const SizedBox(width: 4),
                          Flexible(child: Text(s.location!, style: KText.caption.copyWith(color: c.inkSoft))),
                        ]),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item di tab Deadline: checkbox bulat, judul, kategori, tenggat, prioritas.
class DeadlineTile extends StatelessWidget {
  const DeadlineTile({super.key, required this.s, required this.now});
  final Schedule s;
  final DateTime now;

  void _options(BuildContext context) {
    final app = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(s.title, style: KText.title)),
          ListRow(
            icon: Icons.schedule_rounded,
            label: 'Tunda ke besok',
            onTap: () {
              Navigator.pop(sheet);
              app.postpone(s.id, const Duration(days: 1));
              showToast(context, 'Ditunda ke besok');
            },
          ),
          ListRow(
            icon: Icons.update_rounded,
            label: 'Tunda 3 hari',
            onTap: () {
              Navigator.pop(sheet);
              app.postpone(s.id, const Duration(days: 3));
              showToast(context, 'Ditunda 3 hari');
            },
          ),
          ListRow(
            icon: Icons.edit_outlined,
            label: 'Ubah',
            onTap: () {
              Navigator.pop(sheet);
              Navigator.pushNamed(context, '/form', arguments: FormArgs(editId: s.id));
            },
          ),
          ListRow(
            icon: Icons.delete_outline_rounded,
            label: 'Hapus',
            danger: true,
            onTap: () {
              Navigator.pop(sheet);
              deleteWithUndo(context, s.id);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final section = deadlineSection(s, now);
    final late = section == DeadlineSection.terlambat;
    final sub = switch (section) {
      DeadlineSection.terlambat => formatCountdown(s.start, now),
      DeadlineSection.hariIni => '${formatCountdown(s.start, now)} · ${formatTime(s.start)}',
      DeadlineSection.besok => 'Besok · ${formatTime(s.start)}',
      _ => '${formatShortDate(s.start)} · ${formatTime(s.start)}',
    };
    final subText = s.done && s.doneAt != null ? 'Selesai ${formatRelativeDay(s.doneAt!, now).toLowerCase()}' : sub;

    final tile = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: late ? c.dangerSoft : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: late ? c.danger : c.line, width: s.priority == Priority.tinggi ? 6 : 1.5),
          top: BorderSide(color: late ? c.danger : c.line, width: 1.5),
          right: BorderSide(color: late ? c.danger : c.line, width: 1.5),
          bottom: BorderSide(color: late ? c.danger : c.line, width: 1.5),
        ),
      ),
      child: Row(children: [
        Semantics(
          checked: s.done,
          label: s.done ? 'Batalkan selesai ${s.title}' : 'Tandai selesai ${s.title}',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => toggleDoneWithUndo(context, s.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.done ? c.success : Colors.transparent,
                  border: Border.all(color: s.done ? c.success : c.line, width: 2),
                ),
                child: s.done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openDetail(context, s.id),
            child: Semantics(
              button: true,
              label: '${s.title}, $subText',
              excludeSemantics: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KText.subtitle.copyWith(
                    color: s.done ? c.inkMuted : c.ink,
                    decoration: s.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  CategoryChip(id: s.category, small: true),
                  Text(subText, style: KText.caption.copyWith(color: late ? c.danger : c.inkSoft)),
                  if (s.reminders.isNotEmpty && !s.done) Icon(Icons.notifications_none_rounded, size: 14, color: c.inkMuted),
                ]),
              ]),
            ),
          ),
        ),
        if (!s.done)
          IconButton(
            tooltip: 'Opsi untuk ${s.title}',
            icon: Icon(Icons.more_vert_rounded, color: c.inkSoft),
            onPressed: () => _options(context),
          ),
      ]),
    );

    if (s.done) return tile;
    // Geser ke kanan = tandai selesai.
    return Dismissible(
      key: ValueKey('dl-${s.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        toggleDoneWithUndo(context, s.id);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(color: c.success, borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.check_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
      child: tile,
    );
  }
}
