import { Feather } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, Switch, View } from 'react-native';

import { StackHeader } from '@/components/Header';
import { Button, CategoryChip, Chip, Field, Screen, Segmented, Txt } from '@/components/ui';
import { CATEGORIES, REMINDER_OPTIONS } from '@/lib/categories';
import { addDays, dateKey, formatLongDate, formatTime, fromDateKey, startOfDay } from '@/lib/date';
import { useFormPrefill } from '@/lib/formPrefill';
import type { ScheduleInput } from '@/lib/store';
import { useApp, useToast } from '@/lib/store';
import type { CategoryId, Priority, RecurrenceFreq, ScheduleKind } from '@/lib/types';
import { radius, useTheme } from '@/theme';

const FREQS: { value: RecurrenceFreq | 'none'; label: string }[] = [
  { value: 'none', label: 'Tidak berulang' },
  { value: 'harian', label: 'Setiap hari' },
  { value: 'mingguan', label: 'Setiap minggu' },
  { value: 'dua-mingguan', label: 'Setiap 2 minggu' },
  { value: 'bulanan', label: 'Setiap bulan' },
];

function parseClock(s: string): { h: number; m: number } | null {
  const m = s.trim().match(/^(\d{1,2})(?:[.:](\d{2}))?$/);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2] ?? 0);
  if (h > 23 || min > 59) return null;
  return { h, m: min };
}

/** Akhir semester terdekat: semester gasal ~20 Desember, genap ~30 Juni. */
function endOfSemester(from: Date): Date {
  const y = from.getFullYear();
  const m = from.getMonth();
  if (m >= 7) return new Date(y, 11, 20);
  if (m <= 0) return new Date(y, 0, 31);
  return new Date(y, 5, 30);
}

export default function FormJadwal() {
  const c = useTheme();
  const { id, tanggal } = useLocalSearchParams<{ id?: string; tanggal?: string }>();
  const existing = useApp((s) => (id ? s.schedules.find((x) => x.id === id) : undefined));
  const prefs = useApp((s) => s.prefs);
  const prefill = useMemo(() => useFormPrefill.getState(), []);
  useEffect(() => () => useFormPrefill.getState().clear(), []);

  const src: Partial<ScheduleInput> = existing ?? prefill.input ?? {};
  const initialStart = (() => {
    const base = src.start ? new Date(src.start) : new Date(Date.now() + 3_600_000);
    if (existing?.recurrence && tanggal) {
      const d = fromDateKey(tanggal);
      d.setHours(base.getHours(), base.getMinutes());
      return d;
    }
    if (!src.start) base.setMinutes(0, 0, 0);
    return base;
  })();
  const initialKind: ScheduleKind = src.kind ?? 'acara';
  const initialEnd = src.end
    ? new Date(initialStart.getTime() + (new Date(src.end).getTime() - new Date(src.start!).getTime()))
    : new Date(initialStart.getTime() + 3_600_000);

  const [kind, setKind] = useState<ScheduleKind>(initialKind);
  const [title, setTitle] = useState(src.title ?? '');
  const [day, setDay] = useState(startOfDay(initialStart));
  const [allDay, setAllDay] = useState(src.allDay ?? false);
  const [startText, setStartText] = useState(src.start || existing ? formatTime(initialStart) : initialKind === 'deadline' ? '23.59' : formatTime(initialStart));
  const [endText, setEndText] = useState(formatTime(initialEnd));
  const [category, setCategory] = useState<CategoryId>(src.category ?? (initialKind === 'deadline' ? 'tugas' : prefs.categories[0] ?? 'kuliah'));
  const [priority, setPriority] = useState<Priority>(src.priority ?? 'sedang');
  const [freq, setFreq] = useState<RecurrenceFreq | 'none'>(src.recurrence?.freq ?? 'none');
  const [until, setUntil] = useState<string | undefined>(src.recurrence?.until);
  const [reminders, setReminders] = useState<number[]>(
    src.reminders ?? [initialKind === 'deadline' ? prefs.deadlineReminder : prefs.eventReminder],
  );
  const [location, setLocation] = useState(src.location ?? '');
  const [link, setLink] = useState(src.link ?? '');
  const [notes, setNotes] = useState(src.notes ?? '');
  const [showMore, setShowMore] = useState(!!(src.location || src.link || src.notes));

  const startClock = parseClock(startText);
  const endClock = parseClock(endText);
  const timeError = !allDay && !startClock ? 'Format jam: 15.00' : undefined;
  const endError = kind === 'acara' && !allDay && !endClock ? 'Format jam: 16.00' : undefined;
  const valid = title.trim().length > 0 && !timeError && !endError;

  const build = (): ScheduleInput | null => {
    if (!valid) return null;
    const start = new Date(day);
    let end: Date | undefined;
    if (allDay && kind === 'acara') {
      start.setHours(0, 0, 0, 0);
      end = new Date(day);
      end.setHours(23, 59, 0, 0);
    } else {
      start.setHours(startClock!.h, startClock!.m, 0, 0);
      if (kind === 'acara') {
        end = new Date(day);
        end.setHours(endClock!.h, endClock!.m, 0, 0);
        if (end <= start) end = new Date(end.getTime() + 86_400_000);
      }
    }
    return {
      kind,
      title: title.trim().slice(0, 80),
      start: start.toISOString(),
      end: end?.toISOString(),
      allDay: kind === 'acara' ? allDay : false,
      category,
      priority,
      recurrence: kind === 'acara' && freq !== 'none' ? { freq, until } : undefined,
      reminders,
      location: location.trim() || undefined,
      link: link.trim() || undefined,
      notes: notes.trim() || undefined,
      source: existing?.source ?? prefill.input?.source ?? 'manual',
    };
  };

  const finish = (scheduleId: string, message: string) => {
    const ref = prefill.draftRef;
    if (ref) useApp.getState().updateDraftItem(ref.messageId, ref.index, { status: 'saved', scheduleId });
    useToast.getState().show(message);
    router.back();
  };

  const save = () => {
    const input = build();
    if (!input) return;
    const app = useApp.getState();
    if (!existing) {
      const s = app.addSchedule(input);
      finish(s.id, 'Tersimpan ke Kalender');
      return;
    }
    if (existing.recurrence && tanggal) {
      const onlyThis = () => {
        app.skipOccurrence(existing.id, tanggal);
        const s = app.addSchedule({ ...input, recurrence: undefined });
        finish(s.id, 'Kejadian ini diubah');
      };
      const thisAndNext = () => {
        app.endRecurrenceBefore(existing.id, tanggal);
        const s = app.addSchedule(input);
        finish(s.id, 'Kejadian ini dan berikutnya diubah');
      };
      const all = () => {
        // Pertahankan tanggal mulai seri, ubah jam dan detailnya saja.
        const first = new Date(existing.start);
        const start = new Date(input.start);
        first.setHours(start.getHours(), start.getMinutes());
        const dur = input.end ? new Date(input.end).getTime() - start.getTime() : 0;
        app.updateSchedule(existing.id, { ...input, start: first.toISOString(), end: input.end ? new Date(first.getTime() + dur).toISOString() : undefined });
        finish(existing.id, 'Semua kejadian diubah');
      };
      if (Platform.OS === 'web') return all();
      Alert.alert('Ubah jadwal berulang', 'Mau ubah yang mana?', [
        { text: 'Hanya kejadian ini', onPress: onlyThis },
        { text: 'Kejadian ini dan berikutnya', onPress: thisAndNext },
        { text: 'Semua kejadian', onPress: all },
        { text: 'Batal', style: 'cancel' },
      ]);
      return;
    }
    app.updateSchedule(existing.id, input);
    finish(existing.id, 'Perubahan disimpan');
  };

  const today = startOfDay(new Date());

  return (
    <Screen edges={['top', 'bottom']}>
      <StackHeader
        title={existing ? 'Edit jadwal' : 'Jadwal baru'}
        right={<Button label="Simpan" small onPress={save} disabled={!valid} style={{ marginRight: 8 }} />}
      />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={{ padding: 20, gap: 18, paddingBottom: 60 }} keyboardShouldPersistTaps="handled">
          <Segmented<ScheduleKind>
            value={kind}
            onChange={(k) => {
              setKind(k);
              if (k === 'deadline' && startText === formatTime(initialStart) && !existing) setStartText('23.59');
              setReminders([k === 'deadline' ? prefs.deadlineReminder : prefs.eventReminder]);
            }}
            options={[
              { value: 'acara', label: 'Acara' },
              { value: 'deadline', label: 'Deadline' },
            ]}
          />

          <Field label="Judul" value={title} onChangeText={setTitle} placeholder={kind === 'deadline' ? 'Misal: TK SDA' : 'Misal: Kuliah BasDat'} maxLength={80} autoFocus={!existing && !title} />

          <View style={{ gap: 8 }}>
            <Txt variant="label">Tanggal</Txt>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, borderWidth: 1.5, borderColor: c.line, borderRadius: radius.md, backgroundColor: c.surface, paddingHorizontal: 6, minHeight: 50 }}>
              <Pressable onPress={() => setDay(addDays(day, -1))} accessibilityLabel="Hari sebelumnya" hitSlop={8} style={{ padding: 8 }}>
                <Feather name="chevron-left" size={20} color={c.ink} />
              </Pressable>
              <Txt variant="subtitle" style={{ flex: 1, textAlign: 'center' }}>
                {formatLongDate(day)}
              </Txt>
              <Pressable onPress={() => setDay(addDays(day, 1))} accessibilityLabel="Hari berikutnya" hitSlop={8} style={{ padding: 8 }}>
                <Feather name="chevron-right" size={20} color={c.ink} />
              </Pressable>
            </View>
            <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
              <Chip label="Hari ini" selected={dateKey(day) === dateKey(today)} onPress={() => setDay(today)} />
              <Chip label="Besok" selected={dateKey(day) === dateKey(addDays(today, 1))} onPress={() => setDay(addDays(today, 1))} />
              <Chip label="+1 minggu" onPress={() => setDay(addDays(day, 7))} />
            </View>
          </View>

          {kind === 'acara' && (
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
              <Txt variant="label">Seharian</Txt>
              <Switch value={allDay} onValueChange={setAllDay} trackColor={{ true: c.primary }} accessibilityLabel="Seharian" />
            </View>
          )}

          {!(kind === 'acara' && allDay) && (
            <View style={{ flexDirection: 'row', gap: 12 }}>
              <Field
                style={{ flex: 1 }}
                label={kind === 'deadline' ? 'Jam tenggat' : 'Mulai'}
                value={startText}
                onChangeText={setStartText}
                placeholder="15.00"
                keyboardType="numbers-and-punctuation"
                error={timeError}
                maxLength={5}
              />
              {kind === 'acara' && (
                <Field style={{ flex: 1 }} label="Selesai" value={endText} onChangeText={setEndText} placeholder="16.00" keyboardType="numbers-and-punctuation" error={endError} maxLength={5} />
              )}
            </View>
          )}

          <View style={{ gap: 8 }}>
            <Txt variant="label">Kategori</Txt>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
              {CATEGORIES.map((cat) => (
                <CategoryChip key={cat.id} id={cat.id} selected={category === cat.id} onPress={() => setCategory(cat.id)} />
              ))}
            </View>
          </View>

          {kind === 'acara' && (
            <View style={{ gap: 8 }}>
              <Txt variant="label">Pengulangan</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {FREQS.map((f) => (
                  <Chip key={f.value} label={f.label} selected={freq === f.value} onPress={() => setFreq(f.value)} />
                ))}
              </View>
              {freq !== 'none' && (
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
                  <Txt variant="caption" muted>
                    Berakhir:
                  </Txt>
                  <Chip label="Tidak pernah" selected={!until} onPress={() => setUntil(undefined)} />
                  <Chip
                    label={`Akhir semester (${formatLongDate(endOfSemester(day)).split(', ')[1]})`}
                    selected={until === dateKey(endOfSemester(day))}
                    onPress={() => setUntil(dateKey(endOfSemester(day)))}
                  />
                </View>
              )}
            </View>
          )}

          <View style={{ gap: 8 }}>
            <Txt variant="label">Pengingat</Txt>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
              {REMINDER_OPTIONS.map((r) => {
                const on = reminders.includes(r.minutes);
                return (
                  <Chip
                    key={r.minutes}
                    label={r.label}
                    selected={on}
                    onPress={() => setReminders(on ? reminders.filter((x) => x !== r.minutes) : [...reminders, r.minutes].sort((a, b) => a - b))}
                  />
                );
              })}
            </View>
          </View>

          <View style={{ gap: 8 }}>
            <Txt variant="label">Prioritas</Txt>
            <Segmented<Priority>
              value={priority}
              onChange={setPriority}
              options={[
                { value: 'rendah', label: 'Rendah' },
                { value: 'sedang', label: 'Sedang' },
                { value: 'tinggi', label: 'Tinggi' },
              ]}
            />
          </View>

          {showMore ? (
            <>
              <Field label="Lokasi" value={location} onChangeText={setLocation} placeholder="Misal: Gedung A 2.2302" />
              <Field label="Link" value={link} onChangeText={setLink} placeholder="Zoom, SCeLe, dll." autoCapitalize="none" keyboardType="url" />
              <Field label="Catatan" value={notes} onChangeText={setNotes} placeholder="Catatan tambahan" multiline style={{ minHeight: 90 }} />
            </>
          ) : (
            <Button label="Tambah lokasi, link, catatan" icon="plus" kind="ghost" small onPress={() => setShowMore(true)} style={{ alignSelf: 'flex-start' }} />
          )}
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}
