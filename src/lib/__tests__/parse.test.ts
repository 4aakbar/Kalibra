import { formatTime, dateKey } from '../date';
import { applyClarification, draftTimes, parseMessage, splitActivities } from '../parser/parse';

// "Hari ini" = Rabu, 4 November 2026 pukul 10.00 WIB (sama dengan data demo di Figma).
const NOW = new Date(2026, 10, 4, 10, 0);

const one = (text: string) => {
  const r = parseMessage(text, NOW);
  expect(r.failed).toBe(false);
  expect(r.drafts).toHaveLength(1);
  return r.drafts[0];
};

const startOf = (text: string) => {
  const d = one(text);
  const t = draftTimes(d);
  return { d, start: t?.start, end: t?.end };
};

describe('parseMessage: contoh utama dari PRD', () => {
  it('memecah dua kegiatan dalam satu pesan', () => {
    const r = parseMessage('kuis alin kamis jam 10 sama deadline laprak fisdas jumat', NOW);
    expect(r.drafts).toHaveLength(2);
    const [kuis, laprak] = r.drafts;

    expect(kuis.kind).toBe('acara');
    expect(kuis.title).toBe('Kuis Alin');
    expect(kuis.category).toBe('kuliah');
    expect(dateKey(kuis.date!)).toBe('2026-11-05');
    expect(kuis.time).toEqual({ h: 10, m: 0 });
    expect(kuis.missing).toEqual([]);

    expect(laprak.kind).toBe('deadline');
    expect(laprak.title).toBe('Laprak Fisdas');
    expect(laprak.category).toBe('tugas');
    expect(dateKey(laprak.date!)).toBe('2026-11-06');
    expect(laprak.time).toEqual({ h: 23, m: 59 });
  });

  it('rapat BEM besok jam 4 sore', () => {
    const { d, start, end } = startOf('Rapat BEM besok jam 4 sore');
    expect(d.title).toBe('Rapat BEM');
    expect(d.category).toBe('organisasi');
    expect(dateKey(start!)).toBe('2026-11-05');
    expect(formatTime(start!)).toBe('16.00');
    expect(formatTime(end!)).toBe('17.00');
    expect(d.uncertain).not.toContain('jam');
  });
});

describe('ungkapan waktu', () => {
  it.each([
    ['futsal lusa jam 7 malam', '2026-11-06', '19.00'],
    ['nonton nanti malam', '2026-11-04', '19.00'],
    ['kelas basdat setengah 8 besok', '2026-11-05', '07.30'],
    ['asistensi ddp jumat 13.30', '2026-11-06', '13.30'],
    ['interview magang 12 nov jam 9 pagi', '2026-11-12', '09.00'],
    ['makan sama keluarga 20/11 jam 18', '2026-11-20', '18.00'],
    ['kuliah sda kamis depan jam 8', '2026-11-12', '08.00'],
    ['responsi rabu jam 15', '2026-11-04', '15.00'],
  ])('%s', (text, date, time) => {
    const { start } = startOf(text);
    expect(dateKey(start!)).toBe(date);
    expect(formatTime(start!)).toBe(time);
  });

  it('"jam 3" tanpa keterangan dianggap 15.00 tapi ditandai untuk dicek', () => {
    const { d, start } = startOf('kerja kelompok besok jam 3');
    expect(formatTime(start!)).toBe('15.00');
    expect(d.uncertain).toContain('jam');
  });

  it('rentang jam', () => {
    const { start, end } = startOf('praktikum jarkom kamis jam 10-12');
    expect(formatTime(start!)).toBe('10.00');
    expect(formatTime(end!)).toBe('12.00');
  });

  it('rentang dengan menit', () => {
    const { start, end } = startOf('kuliah ppd senin 08.00-09.40');
    expect(dateKey(start!)).toBe('2026-11-09');
    expect(formatTime(start!)).toBe('08.00');
    expect(formatTime(end!)).toBe('09.40');
  });

  it('zona WITA dikonversi ke zona perangkat (WIB)', () => {
    const { start } = startOf('webinar besok jam 10 wita');
    expect(formatTime(start!)).toBe('09.00');
  });
});

describe('deadline', () => {
  it('TK dikumpul dengan jam tenggat', () => {
    const { d, start } = startOf('TK SDA dikumpul Jumat 23.59');
    expect(d.kind).toBe('deadline');
    expect(d.title).toBe('TK SDA');
    expect(dateKey(start!)).toBe('2026-11-06');
    expect(formatTime(start!)).toBe('23.59');
  });

  it('akhir bulan', () => {
    const d = one('deadline proposal magang akhir bulan');
    expect(d.kind).toBe('deadline');
    expect(dateKey(d.date!)).toBe('2026-11-30');
  });

  it('prioritas tinggi dari kata "penting"', () => {
    const d = one('penting! deadline makalah mpkt besok');
    expect(d.priority).toBe('tinggi');
    expect(d.title).toBe('Makalah MPKT');
  });
});

describe('pengulangan', () => {
  it('tiap Senin jam 8', () => {
    const { d, start } = startOf('Kuliah BasDat tiap Senin jam 8');
    expect(d.recurrence).toEqual({ freq: 'mingguan' });
    expect(d.title).toBe('Kuliah BasDat');
    expect(dateKey(start!)).toBe('2026-11-09');
  });

  it('gym tiap hari jam 6 pagi', () => {
    const d = one('gym tiap hari jam 6 pagi');
    expect(d.recurrence).toEqual({ freq: 'harian' });
    expect(d.time).toEqual({ h: 6, m: 0 });
  });
});

describe('info kurang dan klarifikasi (FR-08)', () => {
  it('acara tanpa jam ditanya jamnya', () => {
    const d = one('rapat himpunan jumat');
    expect(d.missing).toEqual(['jam']);
    const filled = applyClarification(d, 'jam 4 sore', NOW)!;
    expect(filled.missing).toEqual([]);
    expect(formatTime(draftTimes(filled)!.start)).toBe('16.00');
  });

  it('acara tanpa tanggal ditanya tanggalnya', () => {
    const d = one('kuis statprob jam 9');
    expect(d.missing).toEqual(['tanggal']);
    const filled = applyClarification(d, 'besok', NOW)!;
    expect(dateKey(filled.date!)).toBe('2026-11-05');
    expect(filled.missing).toEqual([]);
  });

  it('jawaban yang tidak dipahami mengembalikan null', () => {
    const d = one('rapat himpunan jumat');
    expect(applyClarification(d, 'hmm', NOW)).toBeNull();
  });

  it('tanggal yang disebut sekali berlaku untuk kegiatan berikutnya', () => {
    const r = parseMessage('besok kuis alin jam 10 sama rapat bem jam 4 sore', NOW);
    expect(r.drafts).toHaveLength(2);
    expect(dateKey(r.drafts[1].date!)).toBe('2026-11-05');
    expect(r.drafts[1].uncertain).toContain('tanggal');
  });
});

describe('gagal paham (FR-10)', () => {
  it.each(['halo', 'wkwk', '   '])('"%s" tidak menghasilkan draf', (text) => {
    const r = parseMessage(text, NOW);
    expect(r.failed).toBe(true);
    expect(r.drafts).toHaveLength(0);
  });
});

describe('lokasi dan pemisahan', () => {
  it('mengambil lokasi setelah "di"', () => {
    const d = one('rapat bem jumat jam 4 sore di pusgiwa');
    expect(d.location).toBe('Pusgiwa');
    expect(d.title).toBe('Rapat BEM');
  });

  it('potongan tanpa petunjuk digabung', () => {
    expect(splitActivities('rapat bem dan hima jumat jam 4')).toHaveLength(1);
  });
});

describe('pemisah asli dipertahankan saat digabung', () => {
  it('"zoom sama dosen" tetap utuh', () => {
    const d = one('zoom sama dosen pembimbing besok jam 1 siang');
    expect(d.title).toBe('Zoom sama dosen pembimbing');
  });
});
