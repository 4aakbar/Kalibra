import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../ui/theme.dart';
import 'home_shell.dart';
import '../ui/widgets.dart';

class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  Future<void> _toggleNotif(BuildContext context, bool v) async {
    final app = context.read<AppState>();
    if (!v) {
      app.setPrefs((p) => p.copyWith(notificationsEnabled: false));
      await context.read<Reminders>().cancelAll();
      return;
    }
    final ok = await context.read<Reminders>().requestPermission();
    app.setPrefs((p) => p.copyWith(notificationsEnabled: ok));
    if (!ok && context.mounted) {
      showToast(context, Reminders.supported ? 'Izin ditolak. Nyalakan notifikasi Kalibra di pengaturan HP.' : 'Pengingat hanya jalan di aplikasi HP.');
    }
  }

  Future<void> _clearChat(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus semua riwayat chat?'),
        content: const Text('Jadwal yang sudah tersimpan tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Hapus', style: TextStyle(color: context.k.danger))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AppState>().clearChat();
      showToast(context, 'Riwayat chat dihapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final prefs = app.prefs;
    void set(Preferences Function(Preferences) f) => app.setPrefs(f);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const StackHeader(title: 'Pengaturan'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 60), children: [
              _Group(title: 'Pengingat & notifikasi', children: [
                ListRow(
                  icon: prefs.notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  label: 'Izin notifikasi',
                  trailing: Switch(value: prefs.notificationsEnabled, onChanged: (v) => _toggleNotif(context, v)),
                ),
                _Inner(label: 'Pengingat default acara', children: [
                  for (final (m, l) in reminderOptions.where((r) => r.$1 <= 1440))
                    KChip(label: l, selected: prefs.eventReminder == m, onTap: () => set((p) => p.copyWith(eventReminder: m))),
                ]),
                _Inner(label: 'Pengingat default deadline', children: [
                  for (final (m, l) in reminderOptions.where((r) => r.$1 >= 180))
                    KChip(label: l, selected: prefs.deadlineReminder == m, onTap: () => set((p) => p.copyWith(deadlineReminder: m))),
                ]),
                ListRow(
                  icon: Icons.wb_twilight_rounded,
                  label: 'Ringkasan pagi (${prefs.dayStart.replaceAll(':', '.')})',
                  trailing: Switch(value: prefs.morningSummary, onChanged: (v) => set((p) => p.copyWith(morningSummary: v))),
                ),
                if (android)
                  const ListRow(
                    icon: Icons.battery_saver_outlined,
                    label: 'Panduan optimasi baterai',
                    value: 'Matikan untuk Kalibra',
                  ),
              ]),
              _Group(title: 'Kalender', children: [
                _Inner(label: 'Tampilan default', children: [
                  SizedBox(
                    width: double.infinity,
                    child: Segmented<CalendarView>(
                      value: prefs.calendarView,
                      options: const [(CalendarView.bulan, 'Bulan'), (CalendarView.minggu, 'Minggu'), (CalendarView.hari, 'Hari')],
                      onChanged: (v) => set((p) => p.copyWith(calendarView: v)),
                    ),
                  ),
                ]),
                const ListRow(icon: Icons.schedule_rounded, label: 'Format jam', value: '24 jam'),
                const ListRow(icon: Icons.calendar_today_rounded, label: 'Awal minggu', value: 'Senin'),
              ]),
              _Group(title: 'Tampilan', children: [
                _Inner(label: 'Tema', children: [
                  SizedBox(
                    width: double.infinity,
                    child: Segmented<ThemePref>(
                      value: prefs.theme,
                      options: const [(ThemePref.terang, 'Terang'), (ThemePref.gelap, 'Gelap'), (ThemePref.sistem, 'Ikuti sistem')],
                      onChanged: (v) => set((p) => p.copyWith(theme: v)),
                    ),
                  ),
                ]),
              ]),
              _Group(title: 'Chat', children: [
                ListRow(icon: Icons.delete_outline_rounded, label: 'Hapus semua riwayat chat', onTap: () => _clearChat(context)),
              ]),
              _Group(title: 'Privasi & data', children: [
                ListRow(
                  icon: Icons.bar_chart_rounded,
                  label: 'Izinkan analitik anonim',
                  trailing: Switch(value: prefs.analytics, onChanged: (v) => set((p) => p.copyWith(analytics: v))),
                ),
                ListRow(icon: Icons.shield_outlined, label: 'Kebijakan privasi & syarat', onTap: () => Navigator.pushNamed(context, '/privasi')),
                ListRow(
                  icon: Icons.person_off_outlined,
                  label: 'Hapus akun',
                  danger: true,
                  onTap: () => Navigator.pushNamed(context, '/hapus-akun'),
                ),
              ]),
              _Group(title: 'Bantuan & masukan', children: [
                ListRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Laporkan masalah',
                  onTap: () => launchUrl(Uri.parse('mailto:?subject=Masukan%20Kalibra%20v0.1.0')),
                ),
                ListRow(
                  icon: Icons.slideshow_rounded,
                  label: 'Putar ulang tur fitur',
                  onTap: () {
                    homeTab.value = 1;
                    app.setTourDone(false);
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
                const ListRow(icon: Icons.info_outline_rounded, label: 'Versi', value: '0.1.0 (pratinjau)'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel(title),
          const SizedBox(height: 8),
          KCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(color: Colors.transparent, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
            ),
          ),
        ]),
      );
}

class _Inner extends StatelessWidget {
  const _Inner({required this.label, required this.children});
  final String label;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: KText.label.copyWith(color: context.k.ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ]),
      );
}
