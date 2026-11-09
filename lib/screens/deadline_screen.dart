import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/occurrences.dart';
import '../ui/schedule_items.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'form_screen.dart';
import 'home_shell.dart';

/// Filter: null = semua, 'tinggi' = prioritas tinggi, atau satu kategori.
class _Filter {
  final bool high;
  final CategoryId? category;
  const _Filter({this.high = false, this.category});
  bool get all => !high && category == null;
  bool matches(Schedule s) => all || (high ? s.priority == Priority.tinggi : s.category == category);
  @override
  bool operator ==(Object o) => o is _Filter && o.high == high && o.category == category;
  @override
  int get hashCode => Object.hash(high, category);
}

Future<void> enableNotifications(BuildContext context) async {
  final ok = await context.read<Reminders>().requestPermission();
  if (!context.mounted) return;
  context.read<AppState>().setPrefs((p) => p.copyWith(notificationsEnabled: ok));
  if (!ok) {
    showToast(context, Reminders.supported ? 'Izin notifikasi ditolak. Nyalakan dari pengaturan HP.' : 'Pengingat hanya jalan di aplikasi HP.');
  }
}

void openNewForm(BuildContext context, ScheduleKind kind, {DateTime? start}) {
  final prefs = context.read<AppState>().prefs;
  final s = start ?? DateTime.now().add(const Duration(hours: 1));
  Navigator.pushNamed(context, '/form',
      arguments: FormArgs(
        prefill: kind == ScheduleKind.deadline
            ? ScheduleInput(
                kind: kind,
                title: '',
                start: DateTime(s.year, s.month, s.day, 23, 59),
                category: CategoryId.tugas,
                reminders: [prefs.deadlineReminder],
              )
            : ScheduleInput(
                kind: kind,
                title: '',
                start: DateTime(s.year, s.month, s.day, s.hour),
                end: DateTime(s.year, s.month, s.day, s.hour).add(const Duration(hours: 1)),
                category: prefs.categories.isEmpty ? CategoryId.kuliah : prefs.categories.first,
                reminders: [prefs.eventReminder],
              ),
      ));
}

class DeadlineScreen extends StatefulWidget {
  const DeadlineScreen({super.key});
  @override
  State<DeadlineScreen> createState() => _DeadlineScreenState();
}

class _DeadlineScreenState extends State<DeadlineScreen> {
  _Filter filter = const _Filter();
  final collapsed = <DeadlineSection>{DeadlineSection.selesai};

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final deadlines = app.schedules.where((s) => s.isDeadline).toList();
    final groups = groupDeadlines(deadlines.where(filter.matches).toList(), now);

    // Ringkasan: deadline 7 hari ke depan, progres di jendela 7 hari ke belakang s/d 7 hari ke depan.
    final weekAhead = addDays(now, 7);
    final windowStart = addDays(now, -7);
    final inWindow = deadlines.where((s) => !s.start.isBefore(windowStart) && s.start.isBefore(weekAhead)).toList();
    final doneInWindow = inWindow.where((s) => s.done).length;
    final lateCount = groups[DeadlineSection.terlambat]!.length;
    final openAhead = deadlines.where((s) => !s.done && !s.start.isBefore(now) && s.start.isBefore(weekAhead)).length;
    final allClear = inWindow.isNotEmpty && openAhead == 0 && lateCount == 0 && doneInWindow == inWindow.length && filter.all;

    return Stack(children: [
      Column(children: [
        const TabHeader(title: 'Deadline'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
            if (!app.prefs.notificationsEnabled) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: c.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.warning, width: 1.5),
                ),
                child: Row(children: [
                  Icon(Icons.notifications_off_outlined, size: 18, color: c.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Pengingat mati. Nyalakan biar nggak kelewat.', style: KText.body.copyWith(color: c.ink))),
                  KButton(
                    label: 'Nyalakan',
                    small: true,
                    expand: false,
                    kind: KButtonKind.secondary,
                    onPressed: () => enableNotifications(context),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            if (deadlines.isNotEmpty) ...[
              KCard(
                color: c.primary,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$openAhead deadline 7 hari ke depan${lateCount > 0 ? ' · $lateCount terlambat' : ''}',
                      style: KText.title.copyWith(color: Colors.white)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: inWindow.isEmpty ? 0 : doneInWindow / inWindow.length,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      color: c.cat(CategoryId.organisasi).solid,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('$doneInWindow dari ${inWindow.length} selesai (2 minggu ini)', style: KText.label.copyWith(color: Colors.white)),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                KChip(label: 'Semua', selected: filter.all, onTap: () => setState(() => filter = const _Filter())),
                const SizedBox(width: 8),
                KChip(
                  label: 'Prioritas tinggi',
                  icon: Icons.error_outline_rounded,
                  selected: filter.high,
                  onTap: () => setState(() => filter = const _Filter(high: true)),
                ),
                for (final id in CategoryId.values) ...[
                  const SizedBox(width: 8),
                  CategoryChip(
                    id: id,
                    selected: filter.category == id,
                    onTap: () => setState(() => filter = filter.category == id ? const _Filter() : _Filter(category: id)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            if (deadlines.isEmpty)
              EmptyState(
                icon: Icons.check_box_outlined,
                title: 'Nggak ada deadline',
                body: 'Santai dulu, atau ketik di Chat: "TK SDA dikumpul Jumat 23.59"',
                actionLabel: 'Buka Chat',
                onAction: () => openChatWith('TK SDA dikumpul Jumat 23.59'),
              )
            else if (allClear)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: KCard(
                  color: c.successSoft,
                  child: Center(
                    child: Column(children: [
                      Text('Semua beres!', style: KText.title.copyWith(color: c.ink)),
                      const SizedBox(height: 6),
                      Text('Mantap. Deadline berikutnya ada di bagian Nanti.', style: KText.body.copyWith(color: c.inkMuted)),
                    ]),
                  ),
                ),
              ),
            for (final entry in groups.entries)
              if (entry.value.isNotEmpty) ...[
                Semantics(
                  button: true,
                  expanded: !collapsed.contains(entry.key),
                  child: InkWell(
                    onTap: () => setState(() => collapsed.contains(entry.key) ? collapsed.remove(entry.key) : collapsed.add(entry.key)),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 8),
                      child: Row(children: [
                        Text(sectionLabel[entry.key]!,
                            style: KText.title.copyWith(color: entry.key == DeadlineSection.terlambat ? c.danger : c.ink)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(999)),
                          child: Text('${entry.value.length}', style: KText.caption.copyWith(color: c.ink)),
                        ),
                        const Spacer(),
                        Icon(collapsed.contains(entry.key) ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                            color: c.inkMuted),
                      ]),
                    ),
                  ),
                ),
                if (!collapsed.contains(entry.key))
                  for (final s in entry.value)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: DeadlineTile(key: ValueKey(s.id), s: s, now: now)),
              ],
          ]),
        ),
      ]),
      Positioned(
        right: 20,
        bottom: 20,
        child: KFab(
          label: 'Tambah deadline manual',
          color: c.cat(CategoryId.tugas).solid,
          onPressed: () => openNewForm(context, ScheduleKind.deadline),
        ),
      ),
    ]);
  }
}
