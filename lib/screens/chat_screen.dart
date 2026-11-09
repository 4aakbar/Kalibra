import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../parser/parser.dart';
import '../ui/schedule_items.dart';
import '../ui/theme.dart';
import '../ui/tour.dart';
import '../ui/widgets.dart';
import 'form_screen.dart';
import 'home_shell.dart';

const _defaultChips = ['Kuliah tiap Senin jam 8', 'Deadline laprak Jumat', 'Rapat BEM besok jam 4 sore'];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    chatPrefill.addListener(_applyPrefill);
    _applyPrefill();
  }

  /// Teks contoh dari status kosong Kalender/Deadline.
  void _applyPrefill() {
    final v = chatPrefill.value;
    if (v == null) return;
    _text.text = v;
    chatPrefill.value = null;
    setState(() {});
  }

  @override
  void dispose() {
    chatPrefill.removeListener(_applyPrefill);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? value]) {
    final v = value ?? _text.text;
    if (v.trim().isEmpty) return;
    context.read<AppState>().sendMessage(v);
    _text.clear();
    setState(() {});
  }

  /// Gulir ke pesan terbaru. Diulang sekali karena ListView baru tahu tinggi
  /// item terakhir setelah item itu dibangun.
  void _scrollToEnd() {
    void go() {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      go();
      Future.delayed(const Duration(milliseconds: 260), go);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final chat = app.chat;
    final count = chat.length + (app.typing ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      _scrollToEnd();
    }
    final last = chat.isEmpty ? null : chat.last;
    final empty = _text.text.isEmpty;
    final chips = !empty
        ? const <String>[]
        : last?.role == ChatRole.bot && last!.chips.isNotEmpty
            ? last.chips
            : _defaultChips;
    final canSend = _text.text.trim().isNotEmpty;

    return Column(children: [
      TabHeader(title: 'Chat', avatarKey: TourKeys.avatar, actions: [
        IconButton(
          tooltip: 'Percakapan baru',
          icon: const Icon(Icons.edit_square, size: 24),
          onPressed: () => context.read<AppState>().clearChat(),
        ),
      ]),
      Expanded(
        child: chat.isEmpty && !app.typing
            ? const _Intro()
            : ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => i >= chat.length ? const _TypingBubble() : _MessageView(m: chat[i]),
              ),
      ),
      if (chips.isNotEmpty)
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => KChip(
              label: chips[i],
              onTap: () {
                if (app.awaiting != null || chips[i] == 'Batal') {
                  _send(chips[i]);
                } else {
                  setState(() => _text.text = chips[i]);
                }
              },
            ),
          ),
        ),
      Padding(
        key: TourKeys.composer,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onChanged: (_) => setState(() {}),
              style: KText.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                hintText: 'Misal: kuis Alin Kamis jam 10',
                hintStyle: KText.body.copyWith(color: c.inkMuted),
                counterText: '',
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.line, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.primary, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: 'Kirim',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? _send : null,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: canSend ? c.primary : c.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line, width: 1.5),
                ),
                child: Icon(Icons.arrow_upward_rounded, color: canSend ? Colors.white : c.inkMuted),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final name = context.select<AppState, String>((a) => a.prefs.nickname);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      reverse: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(style: KText.hero.copyWith(color: c.ink), children: [
          TextSpan(text: 'Halo${name.isEmpty ? '' : ' $name'}!\n'),
          TextSpan(text: 'Mau nyatet apa?', style: TextStyle(color: c.primary)),
        ])),
        const SizedBox(height: 12),
        Text(
          'Ketik aja jadwal atau deadline kamu pakai bahasa sehari-hari. Bisa beberapa sekaligus, misal "kuis alin kamis jam 10 sama deadline laprak fisdas jumat".',
          style: KText.body.copyWith(color: c.inkSoft),
        ),
      ]),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset('assets/images/logo.png', width: 28, height: 28, semanticLabel: 'Kalibra'),
      );
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.m});
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    switch (m.role) {
      case ChatRole.user:
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(m.text, style: KText.body.copyWith(color: Colors.white)),
            ),
          ),
        );
      case ChatRole.drafts:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < m.items.length; i++) ...[
            DraftCard(messageId: m.id, index: i, item: m.items[i], total: m.items.length),
            const SizedBox(height: 10),
          ],
          _SaveAll(m: m),
        ]);
      case ChatRole.bot:
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const _BotAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line, width: 1.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Text(m.text, style: KText.body.copyWith(color: c.ink)),
                ),
                if (m.manualFallback != null) ...[
                  const SizedBox(height: 8),
                  KButton(
                    label: 'Isi manual',
                    icon: Icons.edit_outlined,
                    kind: KButtonKind.secondary,
                    small: true,
                    expand: false,
                    onPressed: () {
                      final t = m.manualFallback!;
                      Navigator.pushNamed(context, '/form',
                          arguments: FormArgs(
                            prefill: ScheduleInput(
                              kind: ScheduleKind.acara,
                              title: t.length > 80 ? t.substring(0, 80) : t,
                              start: DateTime.now().add(const Duration(hours: 1)),
                              category: CategoryId.kuliah,
                            ),
                          ));
                    },
                  ),
                ],
              ]),
            ),
          ),
        ]);
    }
  }
}

class _SaveAll extends StatelessWidget {
  const _SaveAll({required this.m});
  final ChatMessage m;
  @override
  Widget build(BuildContext context) {
    final ready = [
      for (var i = 0; i < m.items.length; i++)
        if (m.items[i].status == DraftStatus.pending && m.items[i].draft.missing.isEmpty && m.items[i].draft.title.isNotEmpty) i,
    ];
    if (ready.length < 2) return const SizedBox.shrink();
    return KButton(
      label: 'Simpan semua (${ready.length})',
      icon: Icons.check_circle_outline_rounded,
      onPressed: () {
        final app = context.read<AppState>();
        for (final i in ready) {
          app.saveDraft(m.id, i);
        }
        showToast(context, '${ready.length} jadwal tersimpan', aboveComposer: true);
      },
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Semantics(
      label: 'Kalibra sedang mengetik',
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const _BotAvatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                decoration: BoxDecoration(color: c.inkMuted.withValues(alpha: 0.4 + i * 0.25), shape: BoxShape.circle),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu draf hasil chat (FR-08): selalu dikonfirmasi user sebelum tersimpan.

String _whenText(Draft d) {
  final t = draftTimes(d);
  if (d.date == null) return 'Tanggal belum ada';
  if (t == null) return '${formatLongDate(d.date!)} · jam belum ada';
  if (d.allDay) return '${formatLongDate(t.start)} · Seharian';
  if (d.kind == ScheduleKind.deadline) return '${formatLongDate(t.start)} · tenggat ${formatTime(t.start)}';
  return '${formatLongDate(t.start)} · ${formatTime(t.start)}–${formatTime(t.end ?? t.start)}';
}

class DraftCard extends StatefulWidget {
  const DraftCard({super.key, required this.messageId, required this.index, required this.item, required this.total});
  final String messageId;
  final int index;
  final DraftItem item;
  final int total;
  @override
  State<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<DraftCard> {
  late final _title = TextEditingController(text: widget.item.draft.title);
  bool _editingCategory = false;

  @override
  void didUpdateWidget(covariant DraftCard old) {
    super.didUpdateWidget(old);
    if (widget.item.draft.title != _title.text) _title.text = widget.item.draft.title;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final item = widget.item;
    final draft = item.draft;
    bool unsure(DraftField f) => draft.uncertain.contains(f);

    if (item.status != DraftStatus.pending) {
      final saved = item.status == DraftStatus.saved;
      return Opacity(
        opacity: saved ? 1 : 0.6,
        child: GestureDetector(
          onTap: saved && item.scheduleId != null ? () => openDetail(context, item.scheduleId!) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: saved ? c.successSoft : c.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: saved ? c.success : c.line, width: 1.5),
            ),
            child: Row(children: [
              Icon(saved ? Icons.check_circle_rounded : Icons.cancel_outlined, size: 18, color: saved ? c.success : c.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(draft.title.isEmpty ? 'Tanpa judul' : draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.subtitle.copyWith(color: c.ink, decoration: saved ? null : TextDecoration.lineThrough)),
                  Text('${saved ? 'Tersimpan' : 'Dibatalkan'} · ${_whenText(draft)}',
                      style: KText.caption.copyWith(color: c.inkMuted)),
                ]),
              ),
              if (saved) Icon(Icons.chevron_right_rounded, color: c.inkMuted),
            ]),
          ),
        ),
      );
    }

    final input = draftToInput(draft, app.prefs);
    final canSave = input != null && draft.missing.isEmpty;
    final missingWhen = draft.missing.contains(DraftField.tanggal) || draft.missing.contains(DraftField.jam);

    void onSave() {
      final id = app.saveDraft(widget.messageId, widget.index);
      if (id != null) {
        showToast(context, 'Tersimpan ke Kalender',
            actionLabel: 'Lihat', onAction: () => openDetail(context, id), aboveComposer: true);
      }
    }

    void onEdit() {
      final prefill = input ??
          ScheduleInput(
            kind: draft.kind,
            title: draft.title,
            start: draft.date ?? DateTime.now().add(const Duration(hours: 1)),
            category: draft.category,
            priority: draft.priority,
            recurrence: draft.recurrence,
            location: draft.location,
            reminders: [draft.kind == ScheduleKind.deadline ? app.prefs.deadlineReminder : app.prefs.eventReminder],
            source: 'chat',
          );
      Navigator.pushNamed(context, '/form',
          arguments: FormArgs(
            prefill: prefill,
            draftRef: (messageId: widget.messageId, index: widget.index),
          ));
    }

    return Semantics(
      label: 'Draf jadwal ${draft.title}',
      container: true,
      child: KCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                '${draft.kind == ScheduleKind.deadline ? 'DRAF DEADLINE' : 'DRAF ACARA'}${widget.total > 1 ? ' ${widget.index + 1}/${widget.total}' : ''}',
                style: KText.caption.copyWith(color: c.inkMuted, letterSpacing: 1),
              ),
            ),
            Semantics(
              button: true,
              label: 'Ubah kategori',
              child: GestureDetector(
                onTap: () => setState(() => _editingCategory = !_editingCategory),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CategoryChip(id: draft.category, small: true),
                  if (unsure(DraftField.kategori)) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.help_outline_rounded, size: 14, color: c.warning),
                  ],
                ]),
              ),
            ),
          ]),
          if (_editingCategory) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in CategoryId.values)
                CategoryChip(
                  id: id,
                  selected: id == draft.category,
                  onTap: () {
                    app.updateDraft(widget.messageId, widget.index, (d) => d.category = id, confirmed: DraftField.kategori);
                    setState(() => _editingCategory = false);
                  },
                ),
            ]),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: 80,
            style: KText.title.copyWith(fontSize: 22, color: c.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: 'Judul kegiatan',
              hintStyle: KText.title.copyWith(fontSize: 22, color: c.inkMuted),
            ),
            onChanged: (t) => app.updateDraft(widget.messageId, widget.index, (d) {
              d.title = t;
              if (t.isNotEmpty) d.missing.remove(DraftField.judul);
            }),
          ),
          const SizedBox(height: 10),
          _DraftRow(
            icon: Icons.calendar_today_rounded,
            text: _whenText(draft),
            uncertain: unsure(DraftField.tanggal) || unsure(DraftField.jam),
            missing: missingWhen,
          ),
          if (draft.recurrence != null) _DraftRow(icon: Icons.repeat_rounded, text: freqLabel[draft.recurrence!.freq]!),
          if (draft.location != null) _DraftRow(icon: Icons.place_outlined, text: draft.location!),
          _DraftRow(
            icon: Icons.notifications_none_rounded,
            text: reminderLabel(draft.kind == ScheduleKind.deadline ? app.prefs.deadlineReminder : app.prefs.eventReminder),
          ),
          if (draft.priority != Priority.sedang)
            _DraftRow(icon: Icons.flag_outlined, text: 'Prioritas ${priorityLabel[draft.priority]!.toLowerCase()}'),
          if (draft.uncertain.isNotEmpty && draft.missing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Yang bertanda ? hasil tebakan. Cek dulu ya.', style: KText.caption.copyWith(color: c.warning)),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButton(label: 'Simpan', icon: Icons.check_rounded, small: true, expand: false, onPressed: canSave ? onSave : null),
            KButton(label: 'Ubah', kind: KButtonKind.secondary, small: true, expand: false, onPressed: onEdit),
            KButton(
              label: 'Batal',
              kind: KButtonKind.ghost,
              small: true,
              expand: false,
              onPressed: () => app.cancelDraft(widget.messageId, widget.index),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.icon, required this.text, this.uncertain = false, this.missing = false});
  final IconData icon;
  final String text;
  final bool uncertain;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final color = missing ? c.danger : c.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: KText.body.copyWith(
                fontSize: 14,
                color: color,
                decoration: uncertain ? TextDecoration.underline : null,
                decorationStyle: TextDecorationStyle.dashed,
              )),
        ),
        if (uncertain) Semantics(label: 'Perlu dicek', child: Icon(Icons.help_outline_rounded, size: 14, color: c.warning)),
      ]),
    );
  }
}
