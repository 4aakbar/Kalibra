import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Keluar / hapus akun: batalkan pengingat, hapus data lokal, kembali ke onboarding.
Future<void> signOutAndWipe(BuildContext context) async {
  final reminders = context.read<Reminders>();
  final app = context.read<AppState>();
  final nav = Navigator.of(context);
  await reminders.cancelAll();
  await app.resetAll();
  nav.pushNamedAndRemoveUntil('/onboarding', (_) => false);
}

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Keluar dari Kalibra?'),
        content: const Text('Di versi ini data hanya ada di HP, jadi keluar akan menghapus semua jadwal di perangkat ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Keluar', style: TextStyle(color: context.k.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await signOutAndWipe(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final prefs = app.prefs;
    final monday = startOfWeek(DateTime.now());
    final nextMonday = addDays(monday, 7);
    bool inWeek(DateTime t) => !t.isBefore(monday) && t.isBefore(nextMonday);
    final savedThisWeek = app.schedules.where((s) => inWeek(s.createdAt)).length;
    final viaChat = app.schedules.where((s) => inWeek(s.createdAt) && s.source == 'chat').length;
    final onTime = app.schedules
        .where((s) => s.isDeadline && s.done && s.doneAt != null && inWeek(s.doneAt!) && !s.doneAt!.isAfter(s.start))
        .length;
    final isUI = RegExp(r'@([a-z]+\.)?ui\.ac\.id$', caseSensitive: false).hasMatch(prefs.email);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const StackHeader(title: 'Profil'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              KCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const Avatar(size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(prefs.nickname.isEmpty ? 'Teman Kalibra' : prefs.nickname, style: KText.title.copyWith(color: c.ink)),
                      if (prefs.email.isNotEmpty) Text(prefs.email, style: KText.body.copyWith(color: c.inkMuted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _Badge(label: 'Gratis', color: c.surfaceAlt),
                        if (isUI) _Badge(label: 'Mahasiswa UI', color: c.cat(CategoryId.organisasi).soft),
                      ]),
                    ]),
                  ),
                ]),
              ),
              if (!prefs.notificationsEnabled) ...[
                const SizedBox(height: 18),
                KCard(
                  color: c.warningSoft,
                  borderColor: c.warning,
                  offset: 0,
                  child: Text('Pengingat masih mati. Nyalakan di Pengaturan biar deadline nggak kelewat.',
                      style: KText.body.copyWith(color: c.ink)),
                ),
              ],
              const SizedBox(height: 18),
              const SectionLabel('Minggu ini'),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Stat(value: savedThisWeek, label: 'jadwal disimpan', color: c.cat(CategoryId.kuliah).soft)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: onTime, label: 'deadline tepat waktu', color: c.cat(CategoryId.magang).soft)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: viaChat, label: 'dibuat lewat chat', color: c.cat(CategoryId.pribadi).soft)),
                ]),
              ),
              const SizedBox(height: 18),
              KCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(children: [
                      ListRow(icon: Icons.settings_outlined, label: 'Pengaturan', onTap: () => Navigator.pushNamed(context, '/pengaturan')),
                      ListRow(
                          icon: Icons.help_outline_rounded,
                          label: 'Bantuan & masukan',
                          onTap: () => Navigator.pushNamed(context, '/pengaturan')),
                      const ListRow(icon: Icons.info_outline_rounded, label: 'Tentang Kalibra', value: 'v0.1.0'),
                      ListRow(icon: Icons.logout_rounded, label: 'Keluar', danger: true, onTap: () => _logout(context)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.k.line),
        ),
        child: Text(label, style: KText.caption.copyWith(color: context.k.ink)),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => KCard(
        color: color,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: KText.display.copyWith(color: context.k.ink)),
          Text(label, style: KText.caption.copyWith(color: context.k.ink)),
        ]),
      );
}
