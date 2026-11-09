import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../ui/schedule_items.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Pencarian di data lokal (jalan offline): judul, lokasi, catatan.
class CariScreen extends StatefulWidget {
  const CariScreen({super.key});
  @override
  State<CariScreen> createState() => _CariScreenState();
}

class _CariScreenState extends State<CariScreen> {
  final _q = TextEditingController();
  ScheduleKind? kind;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final schedules = context.watch<AppState>().schedules;
    final term = _q.text.trim().toLowerCase();
    final now = DateTime.now();
    final upcoming = <Occurrence>[];
    final past = <Occurrence>[];
    if (term.isNotEmpty) {
      for (final s in schedules) {
        if (kind != null && s.kind != kind) continue;
        if (![s.title, s.location, s.notes].any((f) => f?.toLowerCase().contains(term) ?? false)) continue;
        final o = Occurrence(s, dateKey(s.start), s.start, s.end ?? s.start);
        (o.end.isBefore(now) && s.recurrence == null ? past : upcoming).add(o);
      }
      upcoming.sort((a, b) => a.start.compareTo(b.start));
      past.sort((a, b) => b.start.compareTo(a.start));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const StackHeader(title: 'Cari'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              TextField(
                controller: _q,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                style: KText.body.copyWith(color: c.ink),
                decoration: InputDecoration(
                  hintText: 'Cari judul, lokasi, catatan',
                  hintStyle: KText.body.copyWith(color: c.inkMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: c.inkMuted),
                  filled: true,
                  fillColor: c.surface,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                KChip(label: 'Semua', selected: kind == null, onTap: () => setState(() => kind = null)),
                const SizedBox(width: 8),
                KChip(label: 'Acara', selected: kind == ScheduleKind.acara, onTap: () => setState(() => kind = ScheduleKind.acara)),
                const SizedBox(width: 8),
                KChip(
                    label: 'Deadline',
                    selected: kind == ScheduleKind.deadline,
                    onTap: () => setState(() => kind = ScheduleKind.deadline)),
              ]),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (term.isNotEmpty && upcoming.isEmpty && past.isEmpty)
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nggak ketemu',
                    body: 'Belum ada jadwal yang cocok dengan "${_q.text.trim()}".',
                  ),
                if (upcoming.isNotEmpty) ...[const SectionLabel('Mendatang'), const SizedBox(height: 10)],
                for (final o in upcoming) Padding(padding: const EdgeInsets.only(bottom: 10), child: OccurrenceCard(occ: o)),
                if (past.isNotEmpty) ...[const SizedBox(height: 8), const SectionLabel('Sudah lewat'), const SizedBox(height: 10)],
                for (final o in past) Padding(padding: const EdgeInsets.only(bottom: 10), child: OccurrenceCard(occ: o)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
