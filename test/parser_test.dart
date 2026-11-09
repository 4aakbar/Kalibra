import 'package:flutter_test/flutter_test.dart';
import 'package:kalibra/core/dates.dart';
import 'package:kalibra/core/models.dart';
import 'package:kalibra/parser/parser.dart';

// "Hari ini" = Rabu, 4 November 2026 pukul 10.00 (sama dengan data demo di Figma).
final now = DateTime(2026, 11, 4, 10);

Draft one(String text) {
  final r = parseMessage(text, now);
  expect(r.failed, isFalse, reason: text);
  expect(r.drafts, hasLength(1), reason: text);
  return r.drafts.first;
}

({Draft d, DateTime? start, DateTime? end}) timesOf(String text) {
  final d = one(text);
  final t = draftTimes(d);
  return (d: d, start: t?.start, end: t?.end);
}

void main() {
  group('contoh utama dari PRD', () {
    test('memecah dua kegiatan dalam satu pesan', () {
      final r = parseMessage('kuis alin kamis jam 10 sama deadline laprak fisdas jumat', now);
      expect(r.drafts, hasLength(2));
      final kuis = r.drafts[0];
      final laprak = r.drafts[1];

      expect(kuis.kind, ScheduleKind.acara);
      expect(kuis.title, 'Kuis Alin');
      expect(kuis.category, CategoryId.kuliah);
      expect(dateKey(kuis.date!), '2026-11-05');
      expect(kuis.time, const ClockTime(10, 0));
      expect(kuis.missing, isEmpty);

      expect(laprak.kind, ScheduleKind.deadline);
      expect(laprak.title, 'Laprak Fisdas');
      expect(laprak.category, CategoryId.tugas);
      expect(dateKey(laprak.date!), '2026-11-06');
      expect(laprak.time, const ClockTime(23, 59));
    });

    test('rapat BEM besok jam 4 sore', () {
      final r = timesOf('Rapat BEM besok jam 4 sore');
      expect(r.d.title, 'Rapat BEM');
      expect(r.d.category, CategoryId.organisasi);
      expect(dateKey(r.start!), '2026-11-05');
      expect(formatTime(r.start!), '16.00');
      expect(formatTime(r.end!), '17.00');
      expect(r.d.uncertain, isNot(contains(DraftField.jam)));
    });
  });

  group('ungkapan waktu', () {
    const cases = [
      ('futsal lusa jam 7 malam', '2026-11-06', '19.00'),
      ('nonton nanti malam', '2026-11-04', '19.00'),
      ('kelas basdat setengah 8 besok', '2026-11-05', '07.30'),
      ('asistensi ddp jumat 13.30', '2026-11-06', '13.30'),
      ('interview magang 12 nov jam 9 pagi', '2026-11-12', '09.00'),
      ('makan sama keluarga 20/11 jam 18', '2026-11-20', '18.00'),
      ('kuliah sda kamis depan jam 8', '2026-11-12', '08.00'),
      ('responsi rabu jam 15', '2026-11-04', '15.00'),
    ];
    for (final (text, date, time) in cases) {
      test(text, () {
        final r = timesOf(text);
        expect(dateKey(r.start!), date);
        expect(formatTime(r.start!), time);
      });
    }

    test('"jam 3" tanpa keterangan dianggap 15.00 tapi ditandai untuk dicek', () {
      final r = timesOf('kerja kelompok besok jam 3');
      expect(formatTime(r.start!), '15.00');
      expect(r.d.uncertain, contains(DraftField.jam));
    });

    test('rentang jam', () {
      final r = timesOf('praktikum jarkom kamis jam 10-12');
      expect(formatTime(r.start!), '10.00');
      expect(formatTime(r.end!), '12.00');
    });

    test('rentang dengan keterangan waktu di akhir', () {
      final r = timesOf('rapat bem jumat jam 4 sampai 6 sore');
      expect(formatTime(r.start!), '16.00');
      expect(formatTime(r.end!), '18.00');
    });

    test('rentang dengan menit', () {
      final r = timesOf('kuliah ppd senin 08.00-09.40');
      expect(dateKey(r.start!), '2026-11-09');
      expect(formatTime(r.start!), '08.00');
      expect(formatTime(r.end!), '09.40');
    });

    test('zona WITA dikonversi ke zona perangkat', () {
      final r = timesOf('webinar besok jam 10 wita');
      // 10.00 WITA (UTC+8) dalam zona perangkat.
      final expected = DateTime.utc(2026, 11, 5, 2).toLocal();
      expect(r.start, DateTime(expected.year, expected.month, expected.day, expected.hour));
    });
  });

  group('deadline', () {
    test('TK dikumpul dengan jam tenggat', () {
      final r = timesOf('TK SDA dikumpul Jumat 23.59');
      expect(r.d.kind, ScheduleKind.deadline);
      expect(r.d.title, 'TK SDA');
      expect(dateKey(r.start!), '2026-11-06');
      expect(formatTime(r.start!), '23.59');
    });

    test('akhir bulan', () {
      final d = one('deadline proposal magang akhir bulan');
      expect(d.kind, ScheduleKind.deadline);
      expect(dateKey(d.date!), '2026-11-30');
    });

    test('prioritas tinggi dari kata "penting"', () {
      final d = one('penting! deadline makalah mpkt besok');
      expect(d.priority, Priority.tinggi);
      expect(d.title, 'Makalah MPKT');
    });
  });

  group('pengulangan', () {
    test('tiap Senin jam 8', () {
      final r = timesOf('Kuliah BasDat tiap Senin jam 8');
      expect(r.d.recurrence, const Recurrence(RecurrenceFreq.mingguan));
      expect(r.d.title, 'Kuliah BasDat');
      expect(dateKey(r.start!), '2026-11-09');
    });

    test('gym tiap hari jam 6 pagi', () {
      final d = one('gym tiap hari jam 6 pagi');
      expect(d.recurrence, const Recurrence(RecurrenceFreq.harian));
      expect(d.time, const ClockTime(6, 0));
    });
  });

  group('info kurang dan klarifikasi (FR-08)', () {
    test('acara tanpa jam ditanya jamnya', () {
      final d = one('rapat himpunan jumat');
      expect(d.missing, [DraftField.jam]);
      final filled = applyClarification(d, 'jam 4 sore', now)!;
      expect(filled.missing, isEmpty);
      expect(formatTime(draftTimes(filled)!.start), '16.00');
    });

    test('acara tanpa tanggal ditanya tanggalnya', () {
      final d = one('kuis statprob jam 9');
      expect(d.missing, [DraftField.tanggal]);
      final filled = applyClarification(d, 'besok', now)!;
      expect(dateKey(filled.date!), '2026-11-05');
      expect(filled.missing, isEmpty);
    });

    test('jawaban yang tidak dipahami mengembalikan null', () {
      expect(applyClarification(one('rapat himpunan jumat'), 'hmm', now), isNull);
    });

    test('tanggal yang disebut sekali berlaku untuk kegiatan berikutnya', () {
      final r = parseMessage('besok kuis alin jam 10 sama rapat bem jam 4 sore', now);
      expect(r.drafts, hasLength(2));
      expect(dateKey(r.drafts[1].date!), '2026-11-05');
      expect(r.drafts[1].uncertain, contains(DraftField.tanggal));
    });
  });

  group('gagal paham (FR-10)', () {
    for (final text in ['halo', 'wkwk', '   ']) {
      test('"$text" tidak menghasilkan draf', () {
        final r = parseMessage(text, now);
        expect(r.failed, isTrue);
        expect(r.drafts, isEmpty);
      });
    }
  });

  group('lokasi dan pemisahan', () {
    test('mengambil lokasi setelah "di"', () {
      final d = one('rapat bem jumat jam 4 sore di pusgiwa');
      expect(d.location, 'Pusgiwa');
      expect(d.title, 'Rapat BEM');
    });

    test('potongan tanpa petunjuk digabung', () {
      expect(splitActivities('rapat bem dan hima jumat jam 4'), hasLength(1));
    });

    test('"zoom sama dosen" tetap utuh', () {
      expect(one('zoom sama dosen pembimbing besok jam 1 siang').title, 'Zoom sama dosen pembimbing');
    });
  });

  test('draf bisa disimpan sebagai JSON dan dibaca lagi', () {
    final d = one('Kuliah BasDat tiap Senin 08.00-09.40 di gedung a');
    final back = Draft.fromJson(d.toJson());
    expect(back.title, d.title);
    expect(back.date, d.date);
    expect(back.endTime, d.endTime);
    expect(back.recurrence, d.recurrence);
    expect(back.location, 'Gedung a');
  });
}
