import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Syarat layanan dan kebijakan privasi versi pratinjau (local-first).
///
/// Isinya menjelaskan perilaku app versi ini apa adanya: semua data tersimpan
/// di HP, belum ada server. Wajib diperbarui (dan ditinjau) sebelum backend,
/// login, atau model AI di server diaktifkan.
class PrivasiScreen extends StatelessWidget {
  const PrivasiScreen({super.key});

  static const updated = '9 November 2026';

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const StackHeader(title: 'Privasi & syarat'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [
              KCard(
                color: c.primarySoft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Versi singkatnya', style: KText.title.copyWith(color: c.ink)),
                  const SizedBox(height: 8),
                  for (final line in const [
                    'Semua jadwal, chat, dan preferensi kamu disimpan di HP ini saja.',
                    'Chat diproses di HP untuk membuat draf jadwal. Belum ada yang dikirim ke server.',
                    'Nggak ada iklan, dan data kamu nggak dijual.',
                    'Kamu bisa hapus semuanya kapan aja dari Pengaturan > Hapus akun.',
                  ])
                    _Bullet(line),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Terakhir diperbarui $updated · versi pratinjau 0.1',
                  style: KText.caption.copyWith(color: c.inkMuted)),
              const _Section('1. Data yang disimpan', [
                'Nama panggilan dan email (opsional) yang kamu isi saat onboarding.',
                'Jawaban kuesioner: kategori kegiatan, kebiasaan mencatat, pengingat default, jam aktif, dan seberapa sering ada yang kelewat.',
                'Jadwal dan deadline: judul, waktu, kategori, prioritas, pengulangan, lokasi, link, catatan, dan status selesai.',
                'Riwayat chat dengan Kalibra dan kartu draf yang dibuat dari chat.',
                'Preferensi tampilan (tema, tampilan kalender) dan izin notifikasi.',
              ]),
              const _Section('2. Di mana data disimpan', [
                'Di versi ini semua data hanya ada di penyimpanan lokal HP kamu. Kalibra belum punya server, jadi data tidak dikirim ke mana pun dan tidak tersinkron ke perangkat lain.',
                'Kalau aplikasi dihapus atau kamu keluar, data ikut terhapus dan tidak bisa dipulihkan.',
              ]),
              const _Section('3. Cara chat diproses', [
                'Teks chat dibaca oleh parser di HP untuk mengenali judul, tanggal, jam, dan kategori, lalu ditampilkan sebagai kartu draf.',
                'Tidak ada jadwal yang tersimpan sebelum kamu menekan Simpan.',
                'Kalau nanti Kalibra memakai model AI di server, teks chat akan dikirim ke server untuk diproses. Sebelum itu aktif, kebijakan ini diperbarui dan kamu akan diminta persetujuan lagi.',
              ]),
              const _Section('4. Notifikasi', [
                'Pengingat dijadwalkan langsung di HP memakai notifikasi lokal, jadi tetap jalan walau offline.',
                'Izin notifikasi bisa dicabut kapan saja dari Pengaturan Kalibra atau pengaturan HP.',
              ]),
              const _Section('5. Analitik', [
                'Pilihan "Izinkan analitik anonim" ada di Pengaturan. Di versi pratinjau ini belum ada data analitik yang dikirim. Saat diaktifkan nanti, yang dikumpulkan hanya data agregat dan anonim (misal jumlah jadwal yang disimpan), tanpa isi jadwal atau chat.',
              ]),
              const _Section('6. Hak kamu (UU PDP No. 27/2022)', [
                'Melihat dan mengubah data: semua data bisa dilihat dan diedit langsung di app.',
                'Menghapus data: Pengaturan > Privasi & data > Hapus akun menghapus semua data di perangkat ini seketika.',
                'Menarik persetujuan: hapus akun atau hapus aplikasi kapan saja.',
              ]),
              const _Section('7. Syarat penggunaan', [
                'Kalibra adalah alat bantu pencatatan. Hasil parser bisa salah, jadi cek kartu draf sebelum menyimpan.',
                'Pengingat bergantung pada izin notifikasi dan pengaturan baterai HP. Kalibra tidak bertanggung jawab atas jadwal yang terlewat karena notifikasi diblokir sistem.',
                'Versi ini adalah pratinjau untuk pengujian dan masih bisa berubah.',
              ]),
              const _Section('8. Kontak', [
                'Pertanyaan atau permintaan soal data: Pengaturan > Bantuan & masukan > Laporkan masalah.',
                'Kalibra dikembangkan oleh Kelompok 11, Perencanaan Produk Digital, Fakultas Ilmu Komputer Universitas Indonesia.',
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.lines);
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: KText.subtitle.copyWith(color: context.k.ink))),
          const SizedBox(height: 8),
          for (final l in lines) _Bullet(l),
        ]),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: context.k.primary, shape: BoxShape.circle)),
          ),
          Expanded(child: Text(text, style: KText.body.copyWith(color: context.k.inkSoft))),
        ]),
      );
}
