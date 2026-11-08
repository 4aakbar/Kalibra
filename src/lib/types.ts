export type ScheduleKind = 'acara' | 'deadline';

export type CategoryId = 'kuliah' | 'tugas' | 'organisasi' | 'magang' | 'pribadi';

export type Priority = 'rendah' | 'sedang' | 'tinggi';

export type RecurrenceFreq = 'harian' | 'mingguan' | 'dua-mingguan' | 'bulanan';

export interface Recurrence {
  freq: RecurrenceFreq;
  /** Tanggal terakhir (YYYY-MM-DD, inklusif). Kosong = tidak berakhir. */
  until?: string;
}

export interface Schedule {
  id: string;
  kind: ScheduleKind;
  title: string;
  /** Acara: waktu mulai. Deadline: waktu tenggat. ISO string. */
  start: string;
  /** Hanya untuk acara. ISO string. */
  end?: string;
  allDay: boolean;
  category: CategoryId;
  priority: Priority;
  /** Hanya untuk acara (MVP). */
  recurrence?: Recurrence;
  /** Kejadian yang dilewati untuk jadwal berulang (YYYY-MM-DD). */
  exdates: string[];
  /** Menit sebelum mulai/tenggat. */
  reminders: number[];
  location?: string;
  notes?: string;
  link?: string;
  /** Hanya untuk deadline. */
  done: boolean;
  doneAt?: string;
  source: 'chat' | 'manual';
  createdAt: string;
  updatedAt: string;
}

/** Satu kejadian di kalender (jadwal berulang dipecah jadi banyak kejadian). */
export interface Occurrence {
  schedule: Schedule;
  /** YYYY-MM-DD dari kejadian ini. */
  dateKey: string;
  start: Date;
  end: Date;
}

export type ThemePreference = 'sistem' | 'terang' | 'gelap';
export type CalendarView = 'bulan' | 'minggu' | 'hari';

export interface Preferences {
  nickname: string;
  email: string;
  categories: CategoryId[];
  /** Menit sebelum acara. */
  eventReminder: number;
  /** Menit sebelum deadline. */
  deadlineReminder: number;
  dayStart: string; // "06:30"
  dayEnd: string; // "23:00"
  missedFrequency?: number; // 1-5, baseline kuesioner
  noteHabit?: string;
  theme: ThemePreference;
  calendarView: CalendarView;
  morningSummary: boolean;
  notificationsEnabled: boolean;
  analytics: boolean;
}
