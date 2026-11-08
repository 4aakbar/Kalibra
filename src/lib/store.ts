/**
 * State aplikasi (local-first). Semua jadwal disimpan di perangkat lewat AsyncStorage,
 * jadi Kalender, Deadline, dan Form tetap jalan offline. Sinkron ke server menyusul
 * setelah backend dipilih; struktur `Schedule` sudah punya id, createdAt, dan updatedAt
 * untuk keperluan itu.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { addMinutes, dateKey, fromDateKey } from './date';
import type { Draft } from './parser/parse';
import type { Preferences, Schedule } from './types';

export const DEFAULT_PREFS: Preferences = {
  nickname: '',
  email: '',
  categories: ['kuliah', 'tugas', 'organisasi', 'magang', 'pribadi'],
  eventReminder: 30,
  deadlineReminder: 1440,
  dayStart: '06:30',
  dayEnd: '23:00',
  theme: 'sistem',
  calendarView: 'minggu',
  morningSummary: true,
  notificationsEnabled: false,
  analytics: true,
};

// ---------------------------------------------------------------------------
// Chat

/** Draf yang bisa disimpan sebagai JSON (Date diganti string). */
export type StoredDraft = Omit<Draft, 'date'> & { date?: string };

export interface DraftItem {
  draft: StoredDraft;
  status: 'pending' | 'saved' | 'cancelled';
  scheduleId?: string;
}

export type ChatMessage =
  | { id: string; role: 'user'; text: string; createdAt: string }
  | {
      id: string;
      role: 'bot';
      text: string;
      createdAt: string;
      chips?: string[];
      /** Tombol "Isi manual" untuk input yang gagal dipahami (FR-10). */
      manualFallback?: string;
    }
  | { id: string; role: 'drafts'; items: DraftItem[]; createdAt: string };

export const toStoredDraft = (d: Draft): StoredDraft => ({ ...d, date: d.date ? dateKey(d.date) : undefined });
export const fromStoredDraft = (d: StoredDraft): Draft => ({ ...d, date: d.date ? fromDateKey(d.date) : undefined });

// ---------------------------------------------------------------------------

export const newId = () => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

export type ScheduleInput = Omit<Schedule, 'id' | 'createdAt' | 'updatedAt' | 'done' | 'exdates'> &
  Partial<Pick<Schedule, 'done' | 'exdates'>>;

interface AppState {
  hydrated: boolean;
  onboarded: boolean;
  tourDone: boolean;
  prefs: Preferences;
  schedules: Schedule[];
  chat: ChatMessage[];
  /** Draf yang sedang menunggu jawaban klarifikasi. */
  awaiting?: { messageId: string; index: number };

  setPrefs: (patch: Partial<Preferences>) => void;
  completeOnboarding: () => void;
  setTourDone: (v: boolean) => void;

  addSchedule: (input: ScheduleInput) => Schedule;
  updateSchedule: (id: string, patch: Partial<Schedule>) => void;
  deleteSchedule: (id: string) => Schedule | undefined;
  restoreSchedule: (s: Schedule) => void;
  toggleDone: (id: string) => void;
  snooze: (id: string, minutes: number) => void;
  /** "Hanya kejadian ini": lewati satu kejadian dari jadwal berulang. */
  skipOccurrence: (id: string, key: string) => void;
  /** "Kejadian ini dan berikutnya": akhiri pengulangan sebelum tanggal ini. */
  endRecurrenceBefore: (id: string, key: string) => void;

  pushChat: (m: ChatMessage) => void;
  updateDraftItem: (messageId: string, index: number, patch: Partial<DraftItem>) => void;
  setAwaiting: (a?: { messageId: string; index: number }) => void;
  clearChat: () => void;

  /** Keluar / hapus akun: hapus semua data lokal. */
  resetAll: () => void;
}

const initial = {
  onboarded: false,
  tourDone: false,
  prefs: DEFAULT_PREFS,
  schedules: [] as Schedule[],
  chat: [] as ChatMessage[],
  awaiting: undefined,
};

export const useApp = create<AppState>()(
  persist(
    (set, get) => ({
      hydrated: false,
      ...initial,

      setPrefs: (patch) => set((s) => ({ prefs: { ...s.prefs, ...patch } })),
      completeOnboarding: () => set({ onboarded: true }),
      setTourDone: (v) => set({ tourDone: v }),

      addSchedule: (input) => {
        const now = new Date().toISOString();
        const schedule: Schedule = { done: false, exdates: [], ...input, id: newId(), createdAt: now, updatedAt: now };
        set((s) => ({ schedules: [...s.schedules, schedule] }));
        return schedule;
      },
      updateSchedule: (id, patch) =>
        set((s) => ({
          schedules: s.schedules.map((x) => (x.id === id ? { ...x, ...patch, updatedAt: new Date().toISOString() } : x)),
        })),
      deleteSchedule: (id) => {
        const found = get().schedules.find((x) => x.id === id);
        set((s) => ({ schedules: s.schedules.filter((x) => x.id !== id) }));
        return found;
      },
      restoreSchedule: (schedule) =>
        set((s) => ({ schedules: [...s.schedules.filter((x) => x.id !== schedule.id), schedule] })),
      toggleDone: (id) =>
        set((s) => ({
          schedules: s.schedules.map((x) =>
            x.id === id
              ? { ...x, done: !x.done, doneAt: x.done ? undefined : new Date().toISOString(), updatedAt: new Date().toISOString() }
              : x,
          ),
        })),
      snooze: (id, minutes) =>
        set((s) => ({
          schedules: s.schedules.map((x) => {
            if (x.id !== id) return x;
            const base = Math.max(new Date(x.start).getTime(), Date.now());
            const start = addMinutes(new Date(base), minutes);
            const end = x.end ? new Date(start.getTime() + (new Date(x.end).getTime() - new Date(x.start).getTime())) : undefined;
            return { ...x, start: start.toISOString(), end: end?.toISOString(), updatedAt: new Date().toISOString() };
          }),
        })),
      skipOccurrence: (id, key) =>
        set((s) => ({
          schedules: s.schedules.map((x) =>
            x.id === id ? { ...x, exdates: [...new Set([...x.exdates, key])], updatedAt: new Date().toISOString() } : x,
          ),
        })),
      endRecurrenceBefore: (id, key) =>
        set((s) => ({
          schedules: s.schedules.flatMap((x) => {
            if (x.id !== id || !x.recurrence) return [x];
            const prev = new Date(fromDateKey(key).getTime() - 86_400_000);
            // Kalau kejadian pertama yang dipilih, hapus semuanya.
            if (fromDateKey(key).getTime() <= new Date(x.start).setHours(0, 0, 0, 0)) return [];
            return [{ ...x, recurrence: { ...x.recurrence, until: dateKey(prev) }, updatedAt: new Date().toISOString() }];
          }),
        })),

      pushChat: (m) => set((s) => ({ chat: [...s.chat, m] })),
      updateDraftItem: (messageId, index, patch) =>
        set((s) => ({
          chat: s.chat.map((m) =>
            m.id === messageId && m.role === 'drafts'
              ? { ...m, items: m.items.map((it, i) => (i === index ? { ...it, ...patch } : it)) }
              : m,
          ),
        })),
      setAwaiting: (a) => set({ awaiting: a }),
      clearChat: () => set({ chat: [], awaiting: undefined }),

      resetAll: () => set({ ...initial, prefs: { ...DEFAULT_PREFS } }),
    }),
    {
      name: 'kalibra-v1',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: ({ hydrated: _h, ...rest }) =>
        Object.fromEntries(Object.entries(rest).filter(([, v]) => typeof v !== 'function')) as Partial<AppState>,
      onRehydrateStorage: () => () => {
        useApp.setState({ hydrated: true });
      },
    },
  ),
);

// ---------------------------------------------------------------------------
// Toast global dengan Urungkan (tidak disimpan)

export interface ToastState {
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
  key: number;
  show: (message: string, action?: { label: string; onPress: () => void }) => void;
  hide: () => void;
}

export const useToast = create<ToastState>((set) => ({
  key: 0,
  show: (message, action) =>
    set((s) => ({ message, actionLabel: action?.label, onAction: action?.onPress, key: s.key + 1 })),
  hide: () => set({ message: undefined, actionLabel: undefined, onAction: undefined }),
}));

/** Hapus dengan toast Urungkan 5 detik, bukan dialog konfirmasi (sesuai spesifikasi). */
export function deleteWithUndo(id: string) {
  const removed = useApp.getState().deleteSchedule(id);
  if (!removed) return;
  useToast.getState().show('Jadwal dihapus', {
    label: 'Urungkan',
    onPress: () => useApp.getState().restoreSchedule(removed),
  });
}

export function toggleDoneWithUndo(id: string) {
  const before = useApp.getState().schedules.find((s) => s.id === id);
  if (!before) return;
  useApp.getState().toggleDone(id);
  if (!before.done) {
    useToast.getState().show('Selesai', { label: 'Urungkan', onPress: () => useApp.getState().toggleDone(id) });
  }
}
