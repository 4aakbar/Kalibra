import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart';

enum _Step { welcome, q1, q2, q3, q4, q5, ringkasan, akun, notifikasi }

const _questions = [_Step.q1, _Step.q2, _Step.q3, _Step.q4, _Step.q5];

const _slides = [
  ('Ketik aja, Kalibra yang nyatet.', '"Kuis Alin Kamis jam 10" langsung jadi kartu jadwal. Kamu tinggal cek dan simpan.'),
  ('Semua jadwal di satu tempat.', 'Kuliah, tugas, organisasi, magang, dan urusan pribadi di satu kalender berwarna.'),
  ('Diingetin sebelum telat.', 'Pengingat dengan tombol Selesai dan Tunda, langsung dari notifikasi.'),
];

const _habits = ['Kepala aja', 'Notes HP', 'Google Calendar', 'Grup WhatsApp/Line', 'Kertas/planner'];
const _dayStarts = ['05:30', '06:30', '07:30', '08:30'];
const _dayEnds = ['22:00', '23:00', '00:00', '01:00'];
const _missed = ['Hampir nggak pernah', 'Jarang', 'Kadang', 'Sering', 'Tiap minggu'];
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step step = _Step.welcome;
  int slide = 0;
  bool consent = false;
  bool emailTouched = false;
  late final TextEditingController nickname;
  late final TextEditingController email;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AppState>().prefs;
    nickname = TextEditingController(text: prefs.nickname);
    email = TextEditingController(text: prefs.email);
  }

  @override
  void dispose() {
    nickname.dispose();
    email.dispose();
    super.dispose();
  }

  void _go(_Step s) => setState(() => step = s);

  Future<void> _finish(bool withNotif) async {
    final app = context.read<AppState>();
    final reminders = context.read<Reminders>();
    var granted = false;
    if (withNotif) granted = await reminders.requestPermission();
    app.setPrefs((p) => p.copyWith(notificationsEnabled: granted));
    final name = nickname.text.trim();
    app.pushChat(ChatMessage(
      id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.bot,
      text:
          'Halo $name! Ketik aja jadwal atau deadline kamu, nanti Kalibra yang nyusun. Kamu bisa nulis beberapa sekaligus.\n\nChat kamu diproses untuk membuat jadwal dan disimpan di HP ini.',
      chips: const ['Kuliah BasDat tiap Senin jam 8', 'Deadline laprak Jumat', 'Rapat BEM besok jam 4 sore'],
    ));
    app.completeOnboarding();
    homeTab.value = 1;
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (step) {
          _Step.welcome => _welcome(context),
          _Step.ringkasan => _summary(context),
          _Step.akun => _account(context),
          _Step.notifikasi => _notif(context),
          _ => _question(context),
        },
      ),
    );
  }

  Widget _bottom(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: child);

  // ---- Welcome ------------------------------------------------------------

  Widget _welcome(BuildContext context) {
    final c = context.k;
    final (title, body) = _slides[slide];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/images/logo.png', width: 36, height: 36, semanticLabel: 'Logo Kalibra'),
          ),
          const SizedBox(width: 10),
          Text('Kalibra', style: KText.title.copyWith(color: c.ink)),
        ]),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200 && slide < 2) setState(() => slide++);
              if (v > 200 && slide > 0) setState(() => slide--);
            },
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 260),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _WelcomeIllustration(index: slide),
                  const SizedBox(height: 28),
                  Text(title, style: KText.hero.copyWith(color: c.ink)),
                  const SizedBox(height: 12),
                  Text(body, style: KText.body.copyWith(color: c.inkSoft, fontSize: 17, height: 1.5)),
                  const SizedBox(height: 28),
                  Semantics(
                    label: 'Slide ${slide + 1} dari 3',
                    child: Row(children: [
                      for (var i = 0; i < 3; i++)
                        GestureDetector(
                          onTap: () => setState(() => slide = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            width: i == slide ? 28 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: i == slide ? c.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: c.line, width: 1.5),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        KButton(
          label: slide < 2 ? 'Lanjut' : 'Mulai',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => slide < 2 ? setState(() => slide++) : _go(_Step.q1),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('Dengan lanjut, kamu setuju dengan Syarat & Kebijakan Privasi Kalibra.',
              textAlign: TextAlign.center, style: KText.caption.copyWith(color: c.inkMuted)),
        ),
      ]),
    );
  }

  // ---- Pertanyaan ---------------------------------------------------------

  Widget _question(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final prefs = app.prefs;
    final qi = _questions.indexOf(step);
    void skip() => _go(qi + 1 < _questions.length ? _questions[qi + 1] : _Step.ringkasan);
    void set(Preferences Function(Preferences) f) => app.setPrefs(f);

    Widget chips(List<Widget> children) => Wrap(spacing: 10, runSpacing: 10, children: children);
    Widget sub(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text(t, style: KText.subtitle.copyWith(color: c.ink)));

    final List<Widget> content = switch (step) {
      _Step.q1 => [
          Text('Kamu lagi sibuk apa aja?', style: KText.display.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Text('Pilih semua yang cocok. Ini jadi kategori di kalendermu.', style: KText.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: 20),
          chips([
            for (final id in CategoryId.values)
              CategoryChip(
                id: id,
                selected: prefs.categories.contains(id),
                onTap: () {
                  final list = prefs.categories.contains(id)
                      ? prefs.categories.where((x) => x != id).toList()
                      : [...prefs.categories, id];
                  set((p) => p.copyWith(categories: list.isEmpty ? [id] : list));
                },
              ),
          ]),
        ],
      _Step.q2 => [
          Text('Biasanya kamu nyatet jadwal di mana?', style: KText.display.copyWith(color: c.ink)),
          const SizedBox(height: 20),
          for (final h in _habits)
            _OptionRow(label: h, selected: prefs.noteHabit == h, onTap: () => set((p) => p.copyWith(noteHabit: h))),
        ],
      _Step.q3 => [
          Text('Mau diingetin berapa lama sebelumnya?', style: KText.display.copyWith(color: c.ink)),
          const SizedBox(height: 14),
          sub('Untuk acara'),
          chips([
            for (final (m, l) in reminderOptions.where((r) => [10, 30, 60, 1440].contains(r.$1)))
              KChip(label: l, selected: prefs.eventReminder == m, onTap: () => set((p) => p.copyWith(eventReminder: m))),
          ]),
          const SizedBox(height: 14),
          sub('Untuk deadline'),
          chips([
            for (final (m, l) in reminderOptions.where((r) => [1440, 4320, 10080].contains(r.$1)))
              KChip(label: l, selected: prefs.deadlineReminder == m, onTap: () => set((p) => p.copyWith(deadlineReminder: m))),
          ]),
        ],
      _Step.q4 => [
          Text('Jam berapa kamu biasanya mulai dan selesai hari?', style: KText.display.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Text('Dipakai untuk ringkasan pagi dan jam tenang notifikasi.', style: KText.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: 14),
          sub('Mulai'),
          chips([
            for (final t in _dayStarts)
              KChip(label: t.replaceAll(':', '.'), selected: prefs.dayStart == t, onTap: () => set((p) => p.copyWith(dayStart: t))),
          ]),
          const SizedBox(height: 14),
          sub('Selesai'),
          chips([
            for (final t in _dayEnds)
              KChip(label: t.replaceAll(':', '.'), selected: prefs.dayEnd == t, onTap: () => set((p) => p.copyWith(dayEnd: t))),
          ]),
        ],
      _ => [
          Text('Seberapa sering kamu ngerasa ada yang kelewat?', style: KText.display.copyWith(color: c.ink)),
          const SizedBox(height: 20),
          for (var i = 0; i < _missed.length; i++)
            _OptionRow(
              label: '${i + 1} · ${_missed[i]}',
              selected: prefs.missedFrequency == i + 1,
              onTap: () => set((p) => p.copyWith(missedFrequency: i + 1)),
            ),
        ],
    };

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
        child: Row(children: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _go(qi == 0 ? _Step.welcome : _questions[qi - 1]),
          ),
          Expanded(
            child: Container(
              height: 10,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: c.line, width: 1.5)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (qi + 1) / 5,
                child: Container(color: c.primary),
              ),
            ),
          ),
          TextButton(onPressed: skip, child: Text('Lewati', style: KText.label.copyWith(color: c.primary))),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Pertanyaan ${qi + 1} dari 5', style: KText.label.copyWith(color: c.inkMuted)),
          const SizedBox(height: 16),
          ...content,
        ]),
      ),
      _bottom(KButton(label: 'Lanjut', icon: Icons.arrow_forward_rounded, onPressed: skip)),
    ]);
  }

  // ---- Ringkasan ----------------------------------------------------------

  Widget _summary(BuildContext context) {
    final c = context.k;
    final prefs = context.watch<AppState>().prefs;
    return Column(children: [
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Oke, Kalibra udah disesuaikan buat kamu.', style: KText.hero.copyWith(color: c.ink)),
              const SizedBox(height: 20),
              KCard(
                color: c.surfaceAlt,
                child: Column(children: [
                  _SummaryRow(
                      icon: Icons.grid_view_rounded,
                      label: 'Kategori',
                      value: prefs.categories.map((x) => categoryLabel[x]).join(', ')),
                  _SummaryRow(
                    icon: Icons.notifications_none_rounded,
                    label: 'Pengingat',
                    value: 'Acara ${reminderShort(prefs.eventReminder)} · Deadline ${reminderShort(prefs.deadlineReminder)} sebelum',
                  ),
                  _SummaryRow(
                    icon: Icons.wb_twilight_rounded,
                    label: 'Ringkasan pagi',
                    value: 'Jam ${prefs.dayStart.replaceAll(':', '.')}',
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('Semua bisa diubah lagi di Pengaturan.', style: KText.body.copyWith(color: c.inkMuted)),
            ]),
          ),
        ),
      ),
      _bottom(KButton(label: 'Buat profil', icon: Icons.arrow_forward_rounded, onPressed: () => _go(_Step.akun))),
    ]);
  }

  // ---- Akun ---------------------------------------------------------------

  Widget _account(BuildContext context) {
    final c = context.k;
    final emailValid = email.text.isEmpty || _emailRe.hasMatch(email.text.trim());
    final canContinue = nickname.text.trim().isNotEmpty && consent && emailValid;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 24, 24), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _go(_Step.ringkasan)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kenalan dulu', style: KText.display.copyWith(color: c.ink)),
              const SizedBox(height: 10),
              Text(
                'Untuk versi awal ini, data kamu disimpan di HP ini saja. Login Google, Apple, dan email akan aktif begitu server Kalibra siap.',
                style: KText.body.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: 18),
              const KButton(label: 'Lanjut dengan Google (segera)', kind: KButtonKind.secondary, icon: Icons.login_rounded),
              if (isIOS) ...[
                const SizedBox(height: 10),
                const KButton(label: 'Lanjut dengan Apple (segera)', kind: KButtonKind.secondary, icon: Icons.login_rounded),
              ],
              const SizedBox(height: 18),
              KField(
                label: 'Nama panggilan',
                controller: nickname,
                hint: 'Misal: Akbar',
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Focus(
                onFocusChange: (f) => f ? null : setState(() => emailTouched = true),
                child: KField(
                  label: 'Email (opsional)',
                  controller: email,
                  hint: 'nama@ui.ac.id',
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  error: emailTouched && !emailValid ? 'Format email belum benar' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                checked: consent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => consent = !consent),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: consent ? c.primary : c.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.line, width: 1.5),
                      ),
                      child: consent ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Saya setuju dengan Syarat dan Kebijakan Privasi, termasuk bahwa teks chat diproses untuk membuat jadwal (UU PDP No. 27/2022).',
                        style: KText.body.copyWith(color: c.inkSoft),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
      _bottom(KButton(
        label: 'Lanjut',
        icon: Icons.arrow_forward_rounded,
        onPressed: canContinue
            ? () {
                context.read<AppState>().setPrefs((p) => p.copyWith(nickname: nickname.text.trim(), email: email.text.trim()));
                _go(_Step.notifikasi);
              }
            : null,
      )),
    ]);
  }

  // ---- Izin notifikasi ----------------------------------------------------

  Widget _notif(BuildContext context) {
    final c = context.k;
    return Column(children: [
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Transform.rotate(
                angle: -0.035,
                child: KCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset('assets/images/logo.png', width: 20, height: 20)),
                      const SizedBox(width: 8),
                      Text('KALIBRA · sekarang', style: KText.caption.copyWith(color: c.inkMuted)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Kuis Alin 30 menit lagi', style: KText.subtitle.copyWith(color: c.ink)),
                    Text('Kam, 10.00 · Gedung A', style: KText.caption.copyWith(color: c.inkMuted)),
                    const SizedBox(height: 10),
                    const Wrap(spacing: 8, children: [KChip(label: 'Selesai'), KChip(label: 'Tunda')]),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Text('Biar deadline nggak kelewat', style: KText.hero.copyWith(color: c.ink)),
              const SizedBox(height: 16),
              Text(
                'Kalibra butuh izin notifikasi untuk mengingatkan kamu sebelum kuliah, rapat, dan tenggat tugas. Pengingat dijadwalkan di HP, jadi tetap jalan walau offline.',
                style: KText.body.copyWith(color: c.inkSoft, fontSize: 17, height: 1.5),
              ),
            ]),
          ),
        ),
      ),
      _bottom(Column(children: [
        KButton(label: 'Nyalakan pengingat', icon: Icons.notifications_active_outlined, onPressed: () => _finish(true)),
        const SizedBox(height: 8),
        KButton(label: 'Nanti aja', kind: KButtonKind.ghost, onPressed: () => _finish(false)),
      ])),
    ]);
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.line, width: 1.5)),
                child: selected
                    ? Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: KText.subtitle.copyWith(color: c.ink, fontSize: 15))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label;
  final String value;
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
            Text(label, style: KText.label.copyWith(color: c.inkMuted)),
            Text(value, style: KText.subtitle.copyWith(color: c.ink)),
          ]),
        ),
      ]),
    );
  }
}

/// Ilustrasi per slide, dibangun dari komponen asli (bukan gambar stok).
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    if (index == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.primary,
            border: Border.all(color: c.line, width: 1.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text('Kuis Alin Kamis jam 10', style: KText.subtitle.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Transform.rotate(
          angle: -0.035,
          child: KCard(
            color: c.cat(CategoryId.kuliah).soft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CategoryChip(id: CategoryId.kuliah, small: true),
              const SizedBox(height: 6),
              Text('Kuis Alin', style: KText.title.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Text('Kamis · 10.00–11.00 · Pengingat 30 menit', style: KText.caption.copyWith(color: c.inkSoft)),
            ]),
          ),
        ),
      ]);
    }
    if (index == 1) {
      const cats = CategoryId.values;
      return KCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(children: [
                  Text(['S', 'S', 'R', 'K', 'J', 'S', 'M'][i], style: KText.caption.copyWith(color: c.inkMuted)),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == 2 ? c.primary : Colors.transparent),
                    child: Text('${2 + i}', style: KText.label.copyWith(color: i == 2 ? Colors.white : c.ink)),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var j = 0; j < i % 3 + 1; j++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(color: c.cat(cats[(i + j) % 5]).solid, shape: BoxShape.circle),
                      ),
                  ]),
                ]),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in cats) CategoryChip(id: k, small: true)]),
        ]),
      );
    }
    return Transform.rotate(
      angle: 0.035,
      child: KCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KALIBRA · 3 jam lagi', style: KText.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: 6),
          Text('Deadline: Laprak Fisdas', style: KText.subtitle.copyWith(color: c.ink)),
          Text('Tenggat hari ini 23.59. Udah dikerjain?', style: KText.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: 10),
          const Wrap(spacing: 8, runSpacing: 8, children: [
            KChip(label: 'Tandai selesai', icon: Icons.check_rounded),
            KChip(label: 'Tunda 1 jam', icon: Icons.schedule_rounded),
          ]),
        ]),
      ),
    );
  }
}
