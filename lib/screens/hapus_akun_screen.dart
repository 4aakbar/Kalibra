import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'profil_screen.dart';

const _reasons = ['Nggak kepake lagi', 'Pindah ke app lain', 'Chat-nya kurang paham', 'Masalah privasi', 'Lainnya'];

/// Hapus akun di dalam app (wajib App Store 5.1.1(v) dan Google Play).
/// Versi ini local-first, jadi semua data di perangkat langsung dihapus. Setelah
/// backend ada, alurnya menjadi soft-delete 30 hari sesuai spesifikasi.
class HapusAkunScreen extends StatefulWidget {
  const HapusAkunScreen({super.key});
  @override
  State<HapusAkunScreen> createState() => _HapusAkunScreenState();
}

class _HapusAkunScreenState extends State<HapusAkunScreen> {
  String? reason;
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final count = context.select<AppState, int>((a) => a.schedules.length);
    final ok = _confirm.text.trim().toUpperCase() == 'HAPUS';
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const StackHeader(title: 'Hapus akun'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              KCard(
                color: c.dangerSoft,
                borderColor: c.danger,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 22, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Ini tidak bisa dibatalkan', style: KText.title.copyWith(color: c.danger))),
                  ]),
                  const SizedBox(height: 10),
                  Text('Yang akan dihapus dari perangkat ini:', style: KText.body.copyWith(color: c.ink)),
                  const SizedBox(height: 4),
                  Text(
                    '• $count jadwal dan deadline\n• Semua riwayat chat\n• Preferensi dan jawaban kuesioner\n• Semua pengingat terjadwal',
                    style: KText.body.copyWith(color: c.ink),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text('Kenapa mau pergi? (opsional)', style: KText.label.copyWith(color: c.ink)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in _reasons)
                  KChip(label: r, selected: reason == r, onTap: () => setState(() => reason = reason == r ? null : r)),
              ]),
              const SizedBox(height: 18),
              KField(
                label: 'Ketik "HAPUS" untuk konfirmasi',
                controller: _confirm,
                hint: 'HAPUS',
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              KButton(
                label: 'Hapus akun permanen',
                kind: KButtonKind.danger,
                icon: Icons.delete_forever_outlined,
                onPressed: ok ? () => signOutAndWipe(context) : null,
              ),
              const SizedBox(height: 8),
              KButton(label: 'Batal', kind: KButtonKind.ghost, onPressed: () => Navigator.maybePop(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}
