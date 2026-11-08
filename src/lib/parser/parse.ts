/**
 * Parser jadwal Bahasa Indonesia sehari-hari (berbasis aturan, jalan offline).
 *
 * Ini implementasi lokal dari ekstraksi jadwal (FR-06 s/d FR-10). Nanti bisa
 * diganti atau dilengkapi model AI di server lewat antarmuka `ScheduleExtractor`
 * (lihat extractor.ts), tapi aturan intinya tetap sama: hasilnya selalu draf yang
 * harus dikonfirmasi user, dan field wajib yang kosong ditanyakan balik.
 */
import { addDays, startOfDay, startOfWeek } from '../date';
import type { CategoryId, Priority, Recurrence, ScheduleKind } from '../types';

export interface ClockTime {
  h: number;
  m: number;
}

export type DraftField = 'judul' | 'tanggal' | 'jam' | 'kategori';

export interface Draft {
  kind: ScheduleKind;
  title: string;
  /** Tanggal (jam 00.00). */
  date?: Date;
  time?: ClockTime;
  endTime?: ClockTime;
  allDay: boolean;
  category: CategoryId;
  priority: Priority;
  recurrence?: Recurrence;
  location?: string;
  /** Selisih jam zona yang disebut user terhadap zona perangkat (mis. user tulis WITA). */
  tzShiftHours: number;
  /** Field wajib yang belum ada, ditanyakan satu per satu. */
  missing: DraftField[];
  /** Field hasil tebakan dengan keyakinan rendah (ditandai di kartu draf). */
  uncertain: DraftField[];
  raw: string;
}

export interface ParseResult {
  drafts: Draft[];
  /** true kalau tidak ada yang bisa dipahami sama sekali (FR-10). */
  failed: boolean;
}

// ---------------------------------------------------------------------------
// Kamus

const WEEKDAYS: Record<string, number> = {
  minggu: 0, ahad: 0, senin: 1, selasa: 2, rabu: 3, kamis: 4, jumat: 5, "jum'at": 5, jumaat: 5, sabtu: 6,
};
const WEEKDAY_RE = "(senin|selasa|rabu|kamis|jum'?at|jumaat|sabtu|minggu|ahad)";

const MONTHS: [RegExp, number][] = [
  [/^jan/, 0], [/^feb/, 1], [/^mar/, 2], [/^apr/, 3], [/^mei/, 4], [/^jun/, 5],
  [/^jul/, 6], [/^(agu|agt|ags)/, 7], [/^sep/, 8], [/^okt/, 9], [/^nov/, 10], [/^des/, 11],
];
const MONTH_RE =
  '(jan(?:uari)?|feb(?:ruari)?|mar(?:et)?|apr(?:il)?|mei|jun(?:i)?|jul(?:i)?|agu(?:stus)?|agt|ags|sep(?:t(?:ember)?)?|okt(?:ober)?|nov(?:ember)?|des(?:ember)?)';

const DEADLINE_WORDS = /\b(deadline|dl|tenggat|due|submit|dikumpul(?:in|kan)?|kumpul(?:in)?|pengumpulan|ngumpulin)\b/;
const TASK_WORDS = /\b(tugas|laprak|tk|pr|makalah|esai|essay|paper|laporan|resume|review|jurnal|assignment)\b/;

const CATEGORY_WORDS: [CategoryId, RegExp][] = [
  ['tugas', TASK_WORDS],
  ['organisasi', /\b(rapat|rapim|bem|hima|himpunan|kepanitiaan|panitia|ukm|organisasi|osjur|pensi|divisi|sie|oprec|proker|evaluasi)\b/],
  ['magang', /\b(magang|intern|internship|kantor|kerja|shift|interview|wawancara|onboarding)\b/],
  ['kuliah', /\b(kuis|quiz|kuliah|kelas|uts|uas|ujian|praktikum|prak|asistensi|responsi|lab|dosen|matkul|alin|basdat|sda|ddp|ddak|pbp|fisdas|kalkulus|kalkul|matdis|sosi|ppd|jarkom|statprob|psd|sisop|os|mpkt|rpl|ppl|tba|dap)\b/],
  ['pribadi', /\b(futsal|gym|olahraga|lari|renang|nonton|makan|dokter|ulang tahun|ultah|nikahan|kondangan|pulang|mudik|belanja|date|nongkrong|main|keluarga)\b/],
];

/** Kapitalisasi singkatan kampus yang umum. */
const CASING: Record<string, string> = {
  alin: 'Alin', basdat: 'BasDat', sda: 'SDA', ddp: 'DDP', ddak: 'DDAK', pbp: 'PBP', fisdas: 'Fisdas', matdis: 'MatDis',
  sosi: 'SOSI', ppd: 'PPD', jarkom: 'Jarkom', statprob: 'StatProb', psd: 'PSD', sisop: 'SisOp', os: 'OS', mpkt: 'MPKT',
  rpl: 'RPL', ppl: 'PPL', tba: 'TBA', dap: 'DAP', tk: 'TK', pr: 'PR', uts: 'UTS', uas: 'UAS', bem: 'BEM', hima: 'HIMA',
  ukm: 'UKM', laprak: 'Laprak', kalkulus: 'Kalkulus', ui: 'UI', fasilkom: 'Fasilkom', scele: 'SCeLe', siak: 'SIAK',
  zoom: 'Zoom', gmeet: 'GMeet', ai: 'AI', ml: 'ML', it: 'IT', ppt: 'PPT', pusgiwa: 'Pusgiwa', mipa: 'MIPA',
};

const FILLER = new Set([
  'ada', 'aku', 'gw', 'gue', 'gua', 'saya', 'ku', 'tolong', 'dong', 'ya', 'yaa', 'yah', 'nih', 'sih', 'pada', 'tanggal',
  'tgl', 'jam', 'pukul', 'pkl', 'nanti', 'ntar', 'hari', 'mulai', 'dari', 'ingetin', 'ingatkan', 'ingatin', 'jangan',
  'lupa', 'catat', 'catet', 'masukin', 'tambahin', 'buat', 'bikin', 'ke', 'kalender', 'jadwal', 'ini', 'itu', 'yang',
  'aja', 'deh', 'kok', 'tuh', 'sampai', 'sampe', 'hingga', 'tiap', 'setiap', 'depan', 'sekali', 'ok', 'oke', 'eh',
]);

// ---------------------------------------------------------------------------
// Waktu

type Period = 'pagi' | 'siang' | 'sore' | 'malam' | undefined;

function normPeriod(p?: string): Period {
  if (!p) return undefined;
  if (p.startsWith('pagi')) return 'pagi';
  if (p.startsWith('siang')) return 'siang';
  if (p.startsWith('sore')) return 'sore';
  if (p.startsWith('mal')) return 'malam';
  return undefined;
}

/** Ubah jam 12-an jadi 24 jam sesuai keterangan waktu. uncertain=true kalau tebakan. */
function applyPeriod(h: number, period: Period): { h: number; uncertain: boolean } {
  switch (period) {
    case 'pagi':
      return { h: h === 12 ? 0 : h, uncertain: false };
    case 'siang':
      return { h: h >= 1 && h <= 5 ? h + 12 : h, uncertain: false };
    case 'sore':
      return { h: h < 12 ? h + 12 : h, uncertain: false };
    case 'malam':
      if (h === 12) return { h: 0, uncertain: false };
      return { h: h >= 6 && h < 12 ? h + 12 : h <= 4 ? h : h + 12, uncertain: false };
    default:
      // Tanpa keterangan: "jam 3" hampir pasti 15.00 buat mahasiswa, tapi tandai untuk dicek.
      if (h >= 1 && h <= 6) return { h: h + 12, uncertain: true };
      return { h, uncertain: false };
  }
}

interface TimeExtraction {
  time?: ClockTime;
  endTime?: ClockTime;
  uncertain: boolean;
  text: string;
}

const PERIOD_RE = '(?:\\s*(pagi|siang|sore|malam|malem))?';

export function extractTime(input: string): TimeExtraction {
  let text = ` ${input} `;
  let uncertain = false;
  const valid = (h: number, m: number) => h >= 0 && h <= 24 && m >= 0 && m < 60;

  // Rentang: "jam 10-12", "10.00-11.40", "jam 1 sampai 3 sore"
  const range = new RegExp(
    `(?:\\b(jam|pukul|pkl)\\s*)?\\b(\\d{1,2})(?:[.:](\\d{2}))?${PERIOD_RE}\\s*(?:-|–|sampai|sampe|s\\/d|hingga)\\s*(?:jam\\s*)?(\\d{1,2})(?:[.:](\\d{2}))?${PERIOD_RE}\\b`,
  );
  const r = text.match(range);
  if (r && (r[1] || (r[3] && r[6]))) {
    const p2 = normPeriod(r[8]);
    const p1 = normPeriod(r[4]) ?? p2;
    const sh = Number(r[2]);
    const sm = Number(r[3] ?? 0);
    const eh = Number(r[5]);
    const em = Number(r[6] ?? 0);
    if (valid(sh, sm) && valid(eh, em)) {
      let s = applyPeriod(sh, p1);
      let e = applyPeriod(eh, p2);
      // "jam 10-1" -> 10.00-13.00
      if (e.h < s.h && e.h + 12 <= 24 && !p2) e = { h: e.h + 12, uncertain: true };
      if (s.uncertain && e.h < s.h) s = { h: sh, uncertain: true };
      uncertain = s.uncertain || e.uncertain;
      text = text.replace(r[0], ' ');
      return { time: { h: s.h, m: sm }, endTime: { h: e.h % 24, m: em }, uncertain, text };
    }
  }

  // "setengah 8" -> 07.30
  const half = new RegExp(`(?:\\b(?:jam|pukul)\\s*)?\\bsetengah\\s+(\\d{1,2})${PERIOD_RE}\\b`);
  const hm = text.match(half);
  if (hm) {
    const base = Number(hm[1]) - 1;
    const res = applyPeriod(base === 0 ? 12 : base, normPeriod(hm[2]));
    text = text.replace(hm[0], ' ');
    return { time: { h: res.h, m: 30 }, uncertain: res.uncertain, text };
  }

  // "jam 10", "jam 3 sore", "pukul 15.30"
  const jam = new RegExp(`\\b(?:jam|pukul|pkl)\\s*(\\d{1,2})(?:[.:](\\d{2}))?${PERIOD_RE}\\b`);
  const jm = text.match(jam);
  if (jm) {
    const h = Number(jm[1]);
    const m = Number(jm[2] ?? 0);
    if (valid(h, m)) {
      const hasMinutesOr24 = jm[2] !== undefined || h > 12;
      const res = hasMinutesOr24 && !jm[3] ? { h, uncertain: h >= 1 && h <= 6 } : applyPeriod(h, normPeriod(jm[3]));
      text = text.replace(jm[0], ' ');
      return { time: { h: res.h === 24 ? 23 : res.h, m: res.h === 24 ? 59 : m }, uncertain: res.uncertain, text };
    }
  }

  // "15.00", "23:59", "7.30 pagi"
  const bare = new RegExp(`\\b(\\d{1,2})[.:](\\d{2})(?![.:/\\d])${PERIOD_RE}\\b`);
  const bm = text.match(bare);
  if (bm) {
    const h = Number(bm[1]);
    const m = Number(bm[2]);
    if (valid(h, m)) {
      const res = bm[3] ? applyPeriod(h, normPeriod(bm[3])) : { h, uncertain: false };
      text = text.replace(bm[0], ' ');
      return { time: { h: res.h === 24 ? 23 : res.h, m: res.h === 24 ? 59 : m }, uncertain: res.uncertain, text };
    }
  }

  // Ungkapan waktu tanpa angka
  if (/\b(abis|habis|setelah|ba'?da)\s+maghrib\b/.test(text)) {
    text = text.replace(/\b(abis|habis|setelah|ba'?da)\s+maghrib\b/, ' ');
    return { time: { h: 18, m: 30 }, uncertain: true, text };
  }
  if (/\btengah malam\b/.test(text)) {
    text = text.replace(/\btengah malam\b/, ' ');
    return { time: { h: 23, m: 59 }, uncertain: false, text };
  }

  return { uncertain: false, text };
}

// ---------------------------------------------------------------------------
// Tanggal

interface DateExtraction {
  date?: Date;
  /** Jam default dari ungkapan seperti "nanti malam". */
  impliedTime?: ClockTime;
  uncertain: boolean;
  text: string;
}

function nextWeekday(now: Date, dow: number, allowToday = true): Date {
  const today = startOfDay(now);
  let diff = (dow - today.getDay() + 7) % 7;
  if (diff === 0 && !allowToday) diff = 7;
  return addDays(today, diff);
}

function weekdayInNextWeek(now: Date, dow: number): Date {
  const monday = addDays(startOfWeek(now), 7);
  return addDays(monday, (dow + 6) % 7);
}

function monthIndex(token: string): number {
  return MONTHS.find(([re]) => re.test(token))?.[1] ?? 0;
}

/** Tahun yang masuk akal: kalau tanggal sudah lewat lebih dari seminggu, anggap tahun depan. */
function inferYear(now: Date, month: number, day: number): number {
  const candidate = new Date(now.getFullYear(), month, day);
  return candidate.getTime() < addDays(startOfDay(now), -7).getTime() ? now.getFullYear() + 1 : now.getFullYear();
}

export function extractDate(input: string, now: Date): DateExtraction {
  let text = ` ${input} `;
  const take = (m: RegExpMatchArray) => {
    text = text.replace(m[0], ' ');
  };
  const today = startOfDay(now);

  let m: RegExpMatchArray | null;

  if ((m = text.match(/\b(nanti|ntar)?\s*(malam|malem)\s+ini\b|\bnanti\s+(malam|malem)\b|\bntar\s+(malam|malem)\b/))) {
    take(m);
    return { date: today, impliedTime: { h: 19, m: 0 }, uncertain: false, text };
  }
  if ((m = text.match(/\b(hari ini|hr ini|today|sekarang)\b/))) {
    take(m);
    return { date: today, uncertain: false, text };
  }
  if ((m = text.match(/\b(besok|besuk|bsk|besoknya)\b/))) {
    take(m);
    return { date: addDays(today, 1), uncertain: false, text };
  }
  if ((m = text.match(/\b(lusa)\b/))) {
    take(m);
    return { date: addDays(today, 2), uncertain: false, text };
  }
  // "5 november", "5 nov 2026"
  if ((m = text.match(new RegExp(`\\b(?:tgl|tanggal)?\\s*(\\d{1,2})\\s+${MONTH_RE}\\b(?:\\s+(\\d{4}))?`)))) {
    const day = Number(m[1]);
    const month = monthIndex(m[2]);
    const year = m[3] ? Number(m[3]) : inferYear(now, month, day);
    take(m);
    return { date: new Date(year, month, day), uncertain: false, text };
  }
  // "5/11", "5/11/2026"
  if ((m = text.match(/\b(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\b/))) {
    const day = Number(m[1]);
    const month = Number(m[2]) - 1;
    if (month >= 0 && month < 12 && day >= 1 && day <= 31) {
      let year = m[3] ? Number(m[3]) : inferYear(now, month, day);
      if (year < 100) year += 2000;
      take(m);
      return { date: new Date(year, month, day), uncertain: false, text };
    }
  }
  // "tgl 12"
  if ((m = text.match(/\b(?:tgl|tanggal)\s*(\d{1,2})\b/))) {
    const day = Number(m[1]);
    let date = new Date(now.getFullYear(), now.getMonth(), day);
    if (date.getTime() < today.getTime()) date = new Date(now.getFullYear(), now.getMonth() + 1, day);
    take(m);
    return { date, uncertain: false, text };
  }
  // "kamis minggu depan"
  if ((m = text.match(new RegExp(`\\b(?:hari\\s+)?${WEEKDAY_RE}\\s+(?:minggu|pekan)\\s+depan\\b`)))) {
    const dow = WEEKDAYS[m[1].replace("'", '')] ?? WEEKDAYS[m[1]];
    take(m);
    return { date: weekdayInNextWeek(now, dow), uncertain: false, text };
  }
  // "minggu depan" saja -> Senin depan, tapi perlu dicek
  if ((m = text.match(/\b(minggu|pekan)\s+depan\b/))) {
    take(m);
    return { date: addDays(startOfWeek(now), 7), uncertain: true, text };
  }
  if ((m = text.match(/\b(akhir\s+bulan)\b/))) {
    take(m);
    return { date: new Date(now.getFullYear(), now.getMonth() + 1, 0), uncertain: false, text };
  }
  if ((m = text.match(/\b(akhir\s+(minggu|pekan)|minggu\s+ini|weekend)\b/))) {
    take(m);
    return { date: addDays(startOfWeek(now), 6), uncertain: m[1] === 'weekend', text };
  }
  // "kamis depan" -> kamis di minggu berikutnya; "kamis" -> kamis terdekat (termasuk hari ini)
  if ((m = text.match(new RegExp(`\\b(?:hari\\s+)?${WEEKDAY_RE}(\\s+depan)?\\b(?!\\s+(?:lalu|kemarin))`)))) {
    const key = m[1].replace("'", '');
    const dow = WEEKDAYS[key] ?? WEEKDAYS[m[1]];
    if (dow !== undefined) {
      take(m);
      const date = m[2] ? weekdayInNextWeek(now, dow) : nextWeekday(now, dow);
      return { date, uncertain: false, text };
    }
  }
  return { uncertain: false, text };
}

// ---------------------------------------------------------------------------
// Pengulangan

interface RecurrenceExtraction {
  recurrence?: Recurrence;
  weekday?: number;
  text: string;
}

export function extractRecurrence(input: string): RecurrenceExtraction {
  let text = ` ${input} `;
  let m: RegExpMatchArray | null;
  if ((m = text.match(/\b(?:tiap|setiap)\s+(?:2|dua)\s+minggu(?:\s+sekali)?\b|\b(?:2|dua)\s+minggu\s+sekali\b/))) {
    text = text.replace(m[0], ' ');
    return { recurrence: { freq: 'dua-mingguan' }, text };
  }
  if ((m = text.match(new RegExp(`\\b(?:tiap|setiap)\\s+(?:hari\\s+)?${WEEKDAY_RE}\\b`)))) {
    // "tiap minggu" lebih sering berarti "tiap pekan" daripada "tiap hari Minggu".
    if (m[1] === 'minggu' && !/hari\s+minggu/.test(m[0])) {
      text = text.replace(m[0], ' ');
      return { recurrence: { freq: 'mingguan' }, text };
    }
    text = text.replace(m[0], ' ');
    return { recurrence: { freq: 'mingguan' }, weekday: WEEKDAYS[m[1].replace("'", '')], text };
  }
  if ((m = text.match(/\b(?:tiap|setiap)\s+(?:hari|hr)\b|\btiap\s+hari\s+kerja\b|\bsetiap\s+hari\s+kerja\b/))) {
    text = text.replace(m[0], ' ');
    return { recurrence: { freq: 'harian' }, text };
  }
  if ((m = text.match(/\b(?:tiap|setiap)\s+(?:pekan)\b|\bseminggu\s+sekali\b/))) {
    text = text.replace(m[0], ' ');
    return { recurrence: { freq: 'mingguan' }, text };
  }
  if ((m = text.match(/\b(?:tiap|setiap)\s+bulan\b|\bsebulan\s+sekali\b/))) {
    text = text.replace(m[0], ' ');
    return { recurrence: { freq: 'bulanan' }, text };
  }
  return { text };
}

// ---------------------------------------------------------------------------
// Judul

function titleCase(words: string[]): string {
  const out = words.map((w, i) => {
    if (CASING[w]) return CASING[w];
    if (i === 0) return w.charAt(0).toUpperCase() + w.slice(1);
    return w;
  });
  return out.join(' ');
}

function cleanTitle(text: string): string {
  const words = text
    .replace(/[!?.,;:"()]+/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
  // Buang kata pengisi hanya di awal dan akhir, supaya "rapat sama dosen" tetap utuh di tengah.
  while (words.length && FILLER.has(words[0])) words.shift();
  while (words.length && FILLER.has(words[words.length - 1])) words.pop();
  return titleCase(words.filter((w, i, arr) => !(w === 'jam' || w === 'pukul') || i === arr.length));
}

// ---------------------------------------------------------------------------
// Satu kegiatan

function hasDateOrTimeCue(s: string): boolean {
  return (
    /\b(jam|pukul|setengah|besok|lusa|hari ini|nanti|tgl|tanggal|tiap|setiap|minggu depan|akhir bulan)\b/.test(s) ||
    new RegExp(`\\b${WEEKDAY_RE}\\b`).test(s) ||
    /\b\d{1,2}[.:/]\d{1,2}\b/.test(s) ||
    new RegExp(`\\b\\d{1,2}\\s+${MONTH_RE}\\b`).test(s)
  );
}

function parseOne(raw: string, now: Date): Draft {
  let s = ` ${raw.toLowerCase().replace(/\s+/g, ' ')} `;
  const uncertain = new Set<DraftField>();

  // Zona waktu
  let tzShiftHours = 0;
  const tz = s.match(/\b(wib|wita|wit)\b/);
  if (tz) {
    const stated = tz[1] === 'wib' ? 7 : tz[1] === 'wita' ? 8 : 9;
    const device = -now.getTimezoneOffset() / 60;
    tzShiftHours = device - stated;
    s = s.replace(tz[0], ' ');
  }

  // Prioritas
  let priority: Priority = 'sedang';
  if (/\b(penting|urgent|urgen|prioritas tinggi|wajib)\b|!!/.test(s)) {
    priority = 'tinggi';
    s = s.replace(/\b(penting banget|penting|urgent|urgen|prioritas tinggi)\b|!!+/g, ' ');
  } else if (/\b(santai|prioritas rendah|ga penting|nggak penting)\b/.test(s)) {
    priority = 'rendah';
    s = s.replace(/\b(santai|prioritas rendah|ga penting|nggak penting)\b/g, ' ');
  }

  // Seharian
  let allDay = false;
  if (/\b(seharian|full day|sehari penuh|all day)\b/.test(s)) {
    allDay = true;
    s = s.replace(/\b(seharian|full day|sehari penuh|all day)\b/g, ' ');
  }

  const rec = extractRecurrence(s);
  s = rec.text;
  const t = extractTime(s);
  s = t.text;
  if (t.uncertain) uncertain.add('jam');
  const d = extractDate(s, now);
  s = d.text;
  if (d.uncertain) uncertain.add('tanggal');

  let date = d.date;
  if (!date && rec.weekday !== undefined) date = nextWeekday(now, rec.weekday);
  if (!date && rec.recurrence?.freq === 'harian') date = startOfDay(now);
  const time = t.time ?? d.impliedTime;

  // Jenis
  const lower = raw.toLowerCase();
  const isDeadline = DEADLINE_WORDS.test(lower) || (TASK_WORDS.test(lower) && !t.endTime && !rec.recurrence);
  const kind: ScheduleKind = isDeadline ? 'deadline' : 'acara';
  s = s.replace(new RegExp(DEADLINE_WORDS.source, 'g'), ' ');

  // Kategori
  let category: CategoryId | undefined = CATEGORY_WORDS.find(([, re]) => re.test(lower))?.[0];
  if (!category) {
    category = kind === 'deadline' ? 'tugas' : 'pribadi';
    uncertain.add('kategori');
  }

  // Lokasi: "di <tempat>" atau "@tempat" di akhir kalimat
  let location: string | undefined;
  const loc = s.match(/\s(?:di|@)\s*([a-z0-9][\w\s.-]*?)\s*$/);
  if (loc && loc[1].trim().length > 1 && !/^(scele|siak|rumah aja)$/.test(loc[1].trim())) {
    location = titleCase(loc[1].trim().split(/\s+/)).replace(/^./, (c) => c.toUpperCase());
    s = s.replace(loc[0], ' ');
  }

  let title = cleanTitle(s);
  if (!title && kind === 'deadline') title = 'Deadline';

  const missing: DraftField[] = [];
  if (!title) missing.push('judul');
  if (!date) missing.push('tanggal');
  if (kind === 'acara' && !time && !allDay) missing.push('jam');

  return {
    kind,
    title,
    date,
    time: kind === 'deadline' && !time ? { h: 23, m: 59 } : time,
    endTime: t.endTime,
    allDay: kind === 'acara' ? allDay : false,
    category,
    priority,
    recurrence: kind === 'acara' ? rec.recurrence : undefined,
    location,
    tzShiftHours,
    missing,
    uncertain: [...uncertain],
    raw: raw.trim(),
  };
}

// ---------------------------------------------------------------------------
// Pesan utuh (bisa berisi beberapa kegiatan)

const SPLIT_RE = /(\s*(?:\n|;|,\s*(?:terus|trus|lalu|sama|dan|plus)?\s*|\s(?:sama|terus|trus|lalu|dan juga|dan|plus|terus juga)\s)\s*)/;

export function splitActivities(text: string): string[] {
  // split dengan grup tangkap: [bagian, pemisah, bagian, pemisah, ...]
  const pieces = text.split(SPLIT_RE);
  const parts: { text: string; sep: string }[] = [];
  for (let i = 0; i < pieces.length; i += 2) {
    const t = pieces[i]?.trim();
    if (t) parts.push({ text: t, sep: (pieces[i - 1] ?? ' ').trim() });
  }
  // Potongan dianggap kegiatan sendiri kalau punya petunjuk waktu atau kata tugas/deadline.
  // Sisanya (mis. "HIMA" di "rapat BEM dan HIMA Jumat jam 4", atau "dosen" di
  // "zoom sama dosen besok jam 1") digabung lagi ke tetangganya dengan pemisah aslinya.
  const out: string[] = [];
  let pending = '';
  const join = (a: string, sep: string, b: string) => (/^[,;]/.test(sep) || !sep ? `${a}${sep} ${b}` : `${a} ${sep} ${b}`);
  for (let i = 0; i < parts.length; i++) {
    const { text: part } = parts[i];
    const lower = part.toLowerCase();
    const standalone = hasDateOrTimeCue(lower) || DEADLINE_WORDS.test(lower) || TASK_WORDS.test(lower);
    if (pending) {
      pending = join(pending, parts[i].sep, part);
      if (standalone) {
        out.push(pending);
        pending = '';
      }
    } else if (standalone) {
      out.push(part);
    } else if (out.length) {
      out[out.length - 1] = join(out[out.length - 1], parts[i].sep, part);
    } else {
      pending = part;
    }
  }
  if (pending) out.push(pending);
  return out;
}

export function parseMessage(text: string, now: Date = new Date()): ParseResult {
  const trimmed = text.trim();
  if (!trimmed) return { drafts: [], failed: true };
  const drafts = splitActivities(trimmed).map((p) => parseOne(p, now));

  // Tanggal yang disebut sekali berlaku untuk kegiatan sesudahnya:
  // "besok kuis jam 10 sama rapat jam 4" -> rapat juga besok.
  for (let i = 1; i < drafts.length; i++) {
    const prev = drafts[i - 1];
    const cur = drafts[i];
    if (!cur.date && prev.date) {
      cur.date = prev.date;
      cur.missing = cur.missing.filter((f) => f !== 'tanggal');
      if (!cur.uncertain.includes('tanggal')) cur.uncertain.push('tanggal');
    }
  }
  // Kebalikannya juga: "kuis jam 10 sama rapat jam 4 besok".
  for (let i = drafts.length - 2; i >= 0; i--) {
    const next = drafts[i + 1];
    const cur = drafts[i];
    if (!cur.date && next.date) {
      cur.date = next.date;
      cur.missing = cur.missing.filter((f) => f !== 'tanggal');
      if (!cur.uncertain.includes('tanggal')) cur.uncertain.push('tanggal');
    }
  }

  const understood = drafts.filter((d) => d.date || d.time || d.recurrence || DEADLINE_WORDS.test(d.raw.toLowerCase()));
  if (!understood.length) return { drafts: [], failed: true };
  return { drafts: understood, failed: false };
}

/**
 * Pakai jawaban user atas pertanyaan klarifikasi ("jam 10", "besok", "Kamis jam 3 sore")
 * untuk melengkapi draf. Mengembalikan draf baru, atau null kalau jawabannya tidak dipahami.
 */
export function applyClarification(draft: Draft, answer: string, now: Date = new Date()): Draft | null {
  const lower = ` ${answer.toLowerCase()} `;
  const t = extractTime(lower);
  const d = extractDate(t.text, now);
  const next: Draft = { ...draft, missing: [...draft.missing], uncertain: [...draft.uncertain] };
  let changed = false;
  if (t.time) {
    next.time = t.time;
    if (t.endTime) next.endTime = t.endTime;
    next.uncertain = next.uncertain.filter((f) => f !== 'jam');
    if (t.uncertain) next.uncertain.push('jam');
    next.missing = next.missing.filter((f) => f !== 'jam');
    changed = true;
  } else if (/\b(seharian|full day|all day)\b/.test(lower) && draft.kind === 'acara') {
    next.allDay = true;
    next.missing = next.missing.filter((f) => f !== 'jam');
    changed = true;
  }
  if (d.date) {
    next.date = d.date;
    if (d.impliedTime && !next.time) next.time = d.impliedTime;
    next.missing = next.missing.filter((f) => f !== 'tanggal');
    next.uncertain = next.uncertain.filter((f) => f !== 'tanggal');
    changed = true;
  }
  if (draft.missing[0] === 'judul' && !changed) {
    const title = cleanTitle(lower);
    if (title) {
      next.title = title;
      next.missing = next.missing.filter((f) => f !== 'judul');
      changed = true;
    }
  }
  return changed ? next : null;
}

/** Hitung waktu mulai/selesai dari draf (dengan koreksi zona waktu). */
export function draftTimes(draft: Draft): { start: Date; end?: Date } | null {
  if (!draft.date) return null;
  const base = new Date(draft.date);
  if (draft.allDay || !draft.time) {
    if (draft.kind === 'acara' && !draft.allDay) return null;
    base.setHours(draft.kind === 'deadline' ? 23 : 0, draft.kind === 'deadline' ? 59 : 0, 0, 0);
    return { start: base, end: draft.kind === 'acara' ? new Date(base.getTime() + 86_399_000) : undefined };
  }
  const start = new Date(base);
  start.setHours(draft.time.h + draft.tzShiftHours, draft.time.m, 0, 0);
  if (draft.kind === 'deadline') return { start };
  let end: Date;
  if (draft.endTime) {
    end = new Date(base);
    end.setHours(draft.endTime.h + draft.tzShiftHours, draft.endTime.m, 0, 0);
    if (end.getTime() <= start.getTime()) end = new Date(end.getTime() + 86_400_000);
  } else {
    end = new Date(start.getTime() + 60 * 60_000);
  }
  return { start, end };
}

/** Pertanyaan klarifikasi untuk field pertama yang kosong (satu hal per pesan). */
export function clarificationQuestion(draft: Draft): { text: string; chips: string[] } | null {
  const field = draft.missing[0];
  const name = draft.title || 'kegiatan ini';
  switch (field) {
    case 'judul':
      return { text: 'Siap. Ini kegiatan apa? Tulis namanya ya.', chips: [] };
    case 'tanggal':
      return {
        text: draft.kind === 'deadline' ? `${name} dikumpul kapan?` : `${name} hari apa?`,
        chips: ['Hari ini', 'Besok', 'Lusa'],
      };
    case 'jam':
      return { text: `${name} jam berapa?`, chips: ['08.00', '13.00', '16.00', 'Seharian'] };
    default:
      return null;
  }
}
