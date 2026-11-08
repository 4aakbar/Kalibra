/**
 * Pengingat lokal (jalur utama, tetap jalan offline). Setiap kali jadwal berubah,
 * semua notifikasi dijadwalkan ulang dari state, jadi tidak ada pengingat "yatim"
 * setelah edit atau hapus (NFR-06). Push server sebagai cadangan menyusul bersama backend.
 */
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import { Platform } from 'react-native';

import { addDays, addMinutes, formatTime, hhmmToMinutes, formatRelativeDay } from './date';
import { occurrencesInRange } from './occurrences';
import { useApp } from './store';
import type { Preferences, Schedule } from './types';

const supported = Platform.OS === 'ios' || Platform.OS === 'android';

/** iOS membatasi 64 notifikasi terjadwal; sisakan ruang untuk ringkasan pagi. */
const MAX_SCHEDULED = 56;
const HORIZON_DAYS = 21;

export const CATEGORY_DEADLINE = 'deadline';
export const CATEGORY_EVENT = 'acara';

let configured = false;

export async function configureNotifications() {
  if (!supported || configured) return;
  configured = true;
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('pengingat', {
      name: 'Pengingat jadwal',
      importance: Notifications.AndroidImportance.HIGH,
      lightColor: '#3B2BD0',
    });
  }
  await Notifications.setNotificationCategoryAsync(CATEGORY_DEADLINE, [
    { identifier: 'done', buttonTitle: 'Tandai selesai' },
    { identifier: 'snooze-60', buttonTitle: 'Tunda 1 jam' },
  ]);
  await Notifications.setNotificationCategoryAsync(CATEGORY_EVENT, [
    { identifier: 'ok', buttonTitle: 'Oke' },
    { identifier: 'snooze-10', buttonTitle: 'Tunda 10 menit' },
  ]);
}

export async function getPermissionStatus(): Promise<'granted' | 'denied' | 'undetermined' | 'unsupported'> {
  if (!supported) return 'unsupported';
  const { status } = await Notifications.getPermissionsAsync();
  return status as 'granted' | 'denied' | 'undetermined';
}

export async function requestPermission(): Promise<boolean> {
  if (!supported) return false;
  await configureNotifications();
  const { status } = await Notifications.requestPermissionsAsync();
  return status === 'granted';
}

interface Planned {
  at: Date;
  title: string;
  body: string;
  scheduleId?: string;
  category?: string;
}

/** Hitung pengingat yang perlu dijadwalkan (fungsi murni, bisa dites). */
export function planReminders(schedules: Schedule[], prefs: Preferences, now = new Date()): Planned[] {
  const out: Planned[] = [];
  const horizon = addDays(now, HORIZON_DAYS);
  const occurrences = occurrencesInRange(
    schedules.filter((s) => !(s.kind === 'deadline' && s.done)),
    now,
    addDays(horizon, 8),
  );
  for (const o of occurrences) {
    for (const minutes of o.schedule.reminders) {
      const at = addMinutes(o.start, -minutes);
      if (at <= now || at > horizon) continue;
      const when = o.schedule.allDay ? formatRelativeDay(o.start, at) : `${formatRelativeDay(o.start, at)} ${formatTime(o.start)}`;
      out.push({
        at,
        title: o.schedule.kind === 'deadline' ? `Deadline: ${o.schedule.title}` : o.schedule.title,
        body: o.schedule.kind === 'deadline' ? `Tenggat ${when}. Udah dikerjain?` : `${when}${o.schedule.location ? ` · ${o.schedule.location}` : ''}`,
        scheduleId: o.schedule.id,
        category: o.schedule.kind === 'deadline' ? CATEGORY_DEADLINE : CATEGORY_EVENT,
      });
    }
  }
  out.sort((a, b) => a.at.getTime() - b.at.getTime());

  if (prefs.morningSummary) {
    const [h, m] = [Math.floor(hhmmToMinutes(prefs.dayStart) / 60), hhmmToMinutes(prefs.dayStart) % 60];
    for (let i = 0; i < 7; i++) {
      const day = addDays(now, i);
      const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(), h, m);
      if (at <= now) continue;
      const items = occurrencesInRange(schedules, new Date(at.getFullYear(), at.getMonth(), at.getDate()), new Date(at.getFullYear(), at.getMonth(), at.getDate(), 23, 59));
      if (!items.length) continue;
      const acara = items.filter((x) => x.schedule.kind === 'acara').length;
      const deadline = items.filter((x) => x.schedule.kind === 'deadline' && !x.schedule.done).length;
      const parts = [acara ? `${acara} acara` : '', deadline ? `${deadline} deadline` : ''].filter(Boolean);
      if (!parts.length) continue;
      out.push({ at, title: 'Ringkasan hari ini', body: `Hari ini: ${parts.join(', ')}. Semangat!` });
    }
  }
  return out.sort((a, b) => a.at.getTime() - b.at.getTime()).slice(0, MAX_SCHEDULED);
}

export async function syncReminders() {
  if (!supported) return;
  const { schedules, prefs } = useApp.getState();
  const status = await getPermissionStatus();
  if (status !== 'granted') return;
  await configureNotifications();
  await Notifications.cancelAllScheduledNotificationsAsync();
  for (const p of planReminders(schedules, prefs)) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: p.title,
        body: p.body,
        data: { scheduleId: p.scheduleId ?? null },
        categoryIdentifier: p.category,
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: p.at,
        channelId: Platform.OS === 'android' ? 'pengingat' : undefined,
      },
    });
  }
}

let timer: ReturnType<typeof setTimeout> | undefined;
/** Jadwalkan ulang dengan jeda supaya edit beruntun tidak memicu banyak sinkron. */
export function scheduleSync() {
  if (!supported) return;
  if (timer) clearTimeout(timer);
  timer = setTimeout(() => {
    syncReminders().catch(() => undefined);
  }, 800);
}

/** Tangani tombol aksi notifikasi (Tandai selesai / Tunda) dan tap notifikasi. */
export function listenToResponses(): () => void {
  if (!supported) return () => undefined;
  const sub = Notifications.addNotificationResponseReceivedListener((response) => {
    const id = response.notification.request.content.data?.scheduleId as string | null | undefined;
    const action = response.actionIdentifier;
    const app = useApp.getState();
    if (action === 'done' && id) {
      if (!app.schedules.find((s) => s.id === id)?.done) app.toggleDone(id);
    } else if (action === 'snooze-60' || action === 'snooze-10') {
      // Tunda = ingatkan lagi nanti; jadwalnya sendiri tidak dipindah.
      const { title, body, data, categoryIdentifier } = response.notification.request.content;
      Notifications.scheduleNotificationAsync({
        content: { title: title ?? 'Pengingat', body: body ?? '', data: data ?? {}, categoryIdentifier: categoryIdentifier ?? undefined },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
          seconds: action === 'snooze-60' ? 3600 : 600,
          channelId: Platform.OS === 'android' ? 'pengingat' : undefined,
        },
      }).catch(() => undefined);
    } else if (action === Notifications.DEFAULT_ACTION_IDENTIFIER) {
      if (id) router.push(`/jadwal/${id}`);
      else router.push('/kalender');
    }
  });
  return () => sub.remove();
}

export async function cancelAllReminders() {
  if (!supported) return;
  await Notifications.cancelAllScheduledNotificationsAsync();
}
