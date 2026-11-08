/**
 * Alur Chat → draf → konfirmasi → simpan (FR-06 s/d FR-10).
 * Tidak ada yang tersimpan tanpa user menekan Simpan.
 */
import { create } from 'zustand';

import type { Draft } from './parser/parse';
import { applyClarification, clarificationQuestion, draftTimes, parseMessage } from './parser/parse';
import type { ChatMessage, DraftItem, ScheduleInput } from './store';
import { fromStoredDraft, newId, toStoredDraft, useApp } from './store';
import type { Preferences } from './types';

const nowIso = () => new Date().toISOString();

function bot(text: string, extra: Partial<Extract<ChatMessage, { role: 'bot' }>> = {}): ChatMessage {
  return { id: newId(), role: 'bot', text, createdAt: nowIso(), ...extra };
}

export function draftToInput(draft: Draft, prefs: Preferences): ScheduleInput | null {
  const times = draftTimes(draft);
  if (!times || !draft.title) return null;
  return {
    kind: draft.kind,
    title: draft.title,
    start: times.start.toISOString(),
    end: times.end?.toISOString(),
    allDay: draft.allDay,
    category: draft.category,
    priority: draft.priority,
    recurrence: draft.recurrence,
    reminders: [draft.kind === 'deadline' ? prefs.deadlineReminder : prefs.eventReminder],
    location: draft.location,
    source: 'chat',
  };
}

/** Status "Kalibra sedang mengetik" (tidak disimpan). */
export const useTyping = create<{ typing: boolean; set: (v: boolean) => void }>((set) => ({
  typing: false,
  set: (typing) => set({ typing }),
}));

const GREETING = /^(halo|hai|hi|hello|hey|pagi|siang|sore|malam|assalamualaikum|p)\b[\s!.]*$/i;
const THANKS = /^(makasih|makasi|thanks|thank you|thx|terima kasih|mksh|oke+|ok|sip+|mantap)\b/i;

function askNext(messageId: string, index: number, draft: Draft) {
  const q = clarificationQuestion(draft);
  const app = useApp.getState();
  if (!q) {
    app.setAwaiting(undefined);
    return;
  }
  app.setAwaiting({ messageId, index });
  app.pushChat(bot(q.text, { chips: q.chips }));
}

/** Cari draf berikutnya yang masih kurang info, untuk ditanyakan. */
function askFirstMissing(messageId: string, items: DraftItem[]) {
  const idx = items.findIndex((it) => it.status === 'pending' && it.draft.missing.length > 0);
  if (idx >= 0) askNext(messageId, idx, fromStoredDraft(items[idx].draft));
  else useApp.getState().setAwaiting(undefined);
}

function respond(text: string) {
  const app = useApp.getState();
  const now = new Date();

  // 1. Sedang menunggu jawaban klarifikasi
  if (app.awaiting) {
    const msg = app.chat.find((m) => m.id === app.awaiting!.messageId);
    if (msg && msg.role === 'drafts') {
      const item = msg.items[app.awaiting.index];
      const updated = item && applyClarification(fromStoredDraft(item.draft), text, now);
      if (updated) {
        app.updateDraftItem(msg.id, app.awaiting.index, { draft: toStoredDraft(updated) });
        if (updated.missing.length) {
          askNext(msg.id, app.awaiting.index, updated);
        } else {
          const fresh = useApp.getState().chat.find((m) => m.id === msg.id);
          if (fresh && fresh.role === 'drafts') {
            const rest = fresh.items.findIndex((it, i) => i !== app.awaiting!.index && it.status === 'pending' && it.draft.missing.length);
            if (rest >= 0) askNext(msg.id, rest, fromStoredDraft(fresh.items[rest].draft));
            else {
              app.setAwaiting(undefined);
              app.pushChat(bot('Sip, udah lengkap. Cek kartunya di atas, lalu tekan Simpan.'));
            }
          }
        }
        return;
      }
    }
    // Bukan jawaban: mungkin user menulis jadwal baru.
    const maybeNew = parseMessage(text, now);
    if (maybeNew.failed) {
      app.pushChat(bot('Maaf, aku belum nangkep. Coba tulis jam atau tanggalnya, misal "jam 4 sore" atau "Kamis".', { chips: ['Hari ini', 'Besok', 'Batal'] }));
      return;
    }
    app.setAwaiting(undefined);
  }

  // 2. Basa-basi
  if (GREETING.test(text.trim())) {
    app.pushChat(bot(`Halo${app.prefs.nickname ? ` ${app.prefs.nickname}` : ''}! Mau nyatet apa hari ini?`, { chips: ['Kuis besok jam 10', 'Deadline TK Jumat 23.59'] }));
    return;
  }
  if (THANKS.test(text.trim())) {
    app.pushChat(bot('Sama-sama! Kabarin aja kalau ada jadwal baru.'));
    return;
  }

  // 3. Jadwal baru
  const result = parseMessage(text, now);
  if (result.failed) {
    app.pushChat(
      bot('Maaf, aku belum nangkep. Bisa tulis kegiatan, tanggal, dan jamnya? Misal: "Rapat BEM Jumat jam 4 sore".', {
        manualFallback: text,
      }),
    );
    return;
  }
  const items: DraftItem[] = result.drafts.map((d) => ({ draft: toStoredDraft(d), status: 'pending' }));
  const id = newId();
  app.pushChat({ id, role: 'drafts', items, createdAt: nowIso() });
  const anyMissing = items.some((it) => it.draft.missing.length);
  if (anyMissing) askFirstMissing(id, items);
  else
    app.pushChat(
      bot(items.length > 1 ? `Aku bikin ${items.length} draf. Cek dulu, baru simpan ya.` : 'Ini drafnya. Cek dulu, baru simpan ya.'),
    );
}

export function sendMessage(text: string) {
  const trimmed = text.trim();
  if (!trimmed) return;
  const app = useApp.getState();
  if (/^batal$/i.test(trimmed) && app.awaiting) {
    app.pushChat({ id: newId(), role: 'user', text: trimmed, createdAt: nowIso() });
    app.updateDraftItem(app.awaiting.messageId, app.awaiting.index, { status: 'cancelled' });
    app.setAwaiting(undefined);
    app.pushChat(bot('Oke, drafnya aku batalin.'));
    return;
  }
  app.pushChat({ id: newId(), role: 'user', text: trimmed, createdAt: nowIso() });
  useTyping.getState().set(true);
  // Jeda singkat supaya terasa seperti percakapan (target respons < 3 detik).
  setTimeout(() => {
    try {
      respond(trimmed);
    } finally {
      useTyping.getState().set(false);
    }
  }, 450);
}

export function saveDraft(messageId: string, index: number): string | null {
  const app = useApp.getState();
  const msg = app.chat.find((m) => m.id === messageId);
  if (!msg || msg.role !== 'drafts') return null;
  const item = msg.items[index];
  if (!item || item.status !== 'pending') return null;
  const input = draftToInput(fromStoredDraft(item.draft), app.prefs);
  if (!input) return null;
  const saved = app.addSchedule(input);
  app.updateDraftItem(messageId, index, { status: 'saved', scheduleId: saved.id });
  if (app.awaiting?.messageId === messageId && app.awaiting.index === index) app.setAwaiting(undefined);
  return saved.id;
}

export function cancelDraft(messageId: string, index: number) {
  const app = useApp.getState();
  app.updateDraftItem(messageId, index, { status: 'cancelled' });
  if (app.awaiting?.messageId === messageId && app.awaiting.index === index) {
    app.setAwaiting(undefined);
    const msg = useApp.getState().chat.find((m) => m.id === messageId);
    if (msg && msg.role === 'drafts') askFirstMissing(messageId, msg.items);
  }
}

export function updateDraft(messageId: string, index: number, patch: Partial<Draft>) {
  const app = useApp.getState();
  const msg = app.chat.find((m) => m.id === messageId);
  if (!msg || msg.role !== 'drafts') return;
  const current = fromStoredDraft(msg.items[index].draft);
  const next: Draft = { ...current, ...patch };
  for (const key of Object.keys(patch) as (keyof Draft)[]) {
    const field = key === 'category' ? 'kategori' : key === 'time' ? 'jam' : key === 'date' ? 'tanggal' : key === 'title' ? 'judul' : null;
    if (field) next.uncertain = next.uncertain.filter((f) => f !== field);
  }
  app.updateDraftItem(messageId, index, { draft: toStoredDraft(next) });
}
