import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { TabHeader } from '@/components/Header';
import { OccurrenceCard } from '@/components/ScheduleItems';
import { Card, CategoryChip, Chip, EmptyState, Screen, Segmented, Txt } from '@/components/ui';
import { CATEGORIES } from '@/lib/categories';
import {
  addDays,
  addMonths,
  BULAN,
  dateKey,
  endOfDay,
  formatLongDate,
  formatTime,
  HARI_SINGKAT,
  hhmmToMinutes,
  isSameDay,
  monthGrid,
  monthTitle,
  startOfDay,
  startOfWeek,
} from '@/lib/date';
import { useFormPrefill } from '@/lib/formPrefill';
import { occurrencesInRange } from '@/lib/occurrences';
import { useApp } from '@/lib/store';
import type { CalendarView, CategoryId, Occurrence } from '@/lib/types';
import { radius, useTheme } from '@/theme';

const HOUR_HEIGHT = 52;

export default function KalenderScreen() {
  const c = useTheme();
  const schedules = useApp((s) => s.schedules);
  const view = useApp((s) => s.prefs.calendarView);
  const setPrefs = useApp((s) => s.setPrefs);
  const [selected, setSelected] = useState(() => startOfDay(new Date()));
  const [filter, setFilter] = useState<CategoryId[]>([]);
  const today = startOfDay(new Date());

  const visible = useMemo(
    () => (filter.length ? schedules.filter((s) => filter.includes(s.category)) : schedules),
    [schedules, filter],
  );

  const shift = (dir: 1 | -1) => {
    if (view === 'bulan') setSelected(startOfDay(addMonths(selected, dir)));
    else if (view === 'minggu') setSelected(addDays(selected, 7 * dir));
    else setSelected(addDays(selected, dir));
  };

  const toggleFilter = (id: CategoryId) =>
    setFilter((f) => (f.includes(id) ? f.filter((x) => x !== id) : [...f, id]));

  const openForm = (start?: Date) => {
    const d = start ?? new Date(selected.getFullYear(), selected.getMonth(), selected.getDate(), new Date().getHours() + 1);
    useFormPrefill.getState().set({ input: { start: d.toISOString(), source: 'manual' } });
    router.push('/jadwal/form');
  };

  return (
    <Screen>
      <TabHeader title="Kalender" />
      <View style={{ paddingHorizontal: 20, gap: 12 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Pressable onPress={() => shift(-1)} accessibilityLabel="Sebelumnya" hitSlop={10} style={{ padding: 6 }}>
            <Feather name="chevron-left" size={22} color={c.ink} />
          </Pressable>
          <Txt variant="title" style={{ flex: 1, textAlign: 'center' }}>
            {view === 'hari' ? formatLongDate(selected) : monthTitle(selected)}
          </Txt>
          <Pressable onPress={() => shift(1)} accessibilityLabel="Berikutnya" hitSlop={10} style={{ padding: 6 }}>
            <Feather name="chevron-right" size={22} color={c.ink} />
          </Pressable>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <View style={{ flex: 1 }}>
            <Segmented<CalendarView>
              value={view}
              onChange={(v) => setPrefs({ calendarView: v })}
              options={[
                { value: 'bulan', label: 'Bulan' },
                { value: 'minggu', label: 'Minggu' },
                { value: 'hari', label: 'Hari' },
              ]}
            />
          </View>
          {!isSameDay(selected, today) && <Chip label="Hari ini" onPress={() => setSelected(today)} />}
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          <Chip label="Semua" selected={!filter.length} onPress={() => setFilter([])} />
          {CATEGORIES.map((cat) => (
            <CategoryChip key={cat.id} id={cat.id} selected={filter.includes(cat.id)} onPress={() => toggleFilter(cat.id)} />
          ))}
        </ScrollView>
      </View>

      {schedules.length === 0 ? (
        <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center' }}>
          <EmptyState
            icon="calendar"
            title="Belum ada jadwal"
            body={`Coba ketik di Chat: "Kuliah BasDat tiap Senin jam 8"`}
            action={{ label: 'Buka Chat', onPress: () => router.push({ pathname: '/chat', params: { isi: 'Kuliah BasDat tiap Senin jam 8' } }) }}
          />
        </ScrollView>
      ) : view === 'bulan' ? (
        <MonthView schedules={visible} selected={selected} onSelect={setSelected} />
      ) : view === 'minggu' ? (
        <WeekView schedules={visible} selected={selected} onSelect={setSelected} onLongPressSlot={openForm} />
      ) : (
        <DayView schedules={visible} selected={selected} onSelect={setSelected} />
      )}

      <Fab onPress={() => openForm()} />
    </Screen>
  );
}

function Fab({ onPress }: { onPress: () => void }) {
  const c = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel="Tambah jadwal manual"
      style={{ position: 'absolute', right: 20, bottom: 20 }}
    >
      <View style={{ position: 'absolute', left: 3, top: 3, width: 56, height: 56, borderRadius: 18, backgroundColor: c.scheme === 'dark' ? '#000' : c.shadow, opacity: c.scheme === 'dark' ? 0.5 : 1 }} />
      <View
        style={{
          width: 56,
          height: 56,
          borderRadius: 18,
          backgroundColor: c.category.organisasi.solid,
          borderWidth: 1.5,
          borderColor: c.line,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Feather name="plus" size={26} color="#1F1B16" />
      </View>
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Bulan

function MonthView({ schedules, selected, onSelect }: { schedules: ReturnType<typeof useApp.getState>['schedules']; selected: Date; onSelect: (d: Date) => void }) {
  const c = useTheme();
  const grid = useMemo(() => monthGrid(selected), [selected]);
  const occ = useMemo(() => occurrencesInRange(schedules, grid[0], endOfDay(grid[41])), [schedules, grid]);
  const byDay = useMemo(() => {
    const m = new Map<string, Occurrence[]>();
    for (const o of occ) {
      // Acara multi-hari muncul di setiap tanggal yang dilewati.
      let d = startOfDay(o.start);
      while (d.getTime() <= o.end.getTime()) {
        const k = dateKey(d);
        m.set(k, [...(m.get(k) ?? []), o]);
        d = addDays(d, 1);
        if (o.schedule.kind === 'deadline') break;
      }
    }
    return m;
  }, [occ]);
  const today = new Date();
  const dayItems = byDay.get(dateKey(selected)) ?? [];

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 100, gap: 16 }}>
      <Card style={{ padding: 10 }}>
        <View style={{ flexDirection: 'row' }}>
          {[1, 2, 3, 4, 5, 6, 0].map((d) => (
            <Txt key={d} variant="caption" muted style={{ flex: 1, textAlign: 'center', paddingVertical: 6 }}>
              {HARI_SINGKAT[d]}
            </Txt>
          ))}
        </View>
        {[0, 1, 2, 3, 4, 5].map((row) => (
          <View key={row} style={{ flexDirection: 'row' }}>
            {grid.slice(row * 7, row * 7 + 7).map((d) => {
              const items = byDay.get(dateKey(d)) ?? [];
              const inMonth = d.getMonth() === selected.getMonth();
              const isSel = isSameDay(d, selected);
              const isToday = isSameDay(d, today);
              const late = items.some((o) => o.schedule.kind === 'deadline' && !o.schedule.done && o.start < today);
              return (
                <Pressable
                  key={d.toISOString()}
                  onPress={() => onSelect(startOfDay(d))}
                  accessibilityRole="button"
                  accessibilityLabel={`${d.getDate()} ${BULAN[d.getMonth()]}, ${items.length ? `${items.length} kegiatan` : 'kosong'}`}
                  style={{ flex: 1, alignItems: 'center', paddingVertical: 4, minHeight: 54, opacity: inMonth ? 1 : 0.35 }}
                >
                  <View
                    style={{
                      width: 34,
                      height: 34,
                      borderRadius: 17,
                      alignItems: 'center',
                      justifyContent: 'center',
                      backgroundColor: isSel ? c.primary : 'transparent',
                      borderWidth: isToday && !isSel ? 2 : 0,
                      borderColor: c.primary,
                    }}
                  >
                    <Txt variant="label" color={isSel ? '#FFF' : c.ink}>
                      {d.getDate()}
                    </Txt>
                  </View>
                  <DayMarkers items={items} late={late} />
                </Pressable>
              );
            })}
          </View>
        ))}
      </Card>

      <Txt variant="title">{formatLongDate(selected)}</Txt>
      {dayItems.length === 0 ? (
        <Txt muted>Kosong. Hari santai.</Txt>
      ) : (
        <View style={{ gap: 10 }}>
          {dayItems.map((o) => (
            <OccurrenceCard key={`${o.schedule.id}-${o.dateKey}`} occ={o} />
          ))}
        </View>
      )}
    </ScrollView>
  );
}

/** 1–3 kegiatan = titik per kegiatan; 4+ = bar warna + angka. Deadline = titik bercincin. */
function DayMarkers({ items, late }: { items: Occurrence[]; late: boolean }) {
  const c = useTheme();
  if (!items.length) return <View style={{ height: 8 }} />;
  if (items.length <= 3) {
    return (
      <View style={{ flexDirection: 'row', gap: 3, height: 8, marginTop: 3 }}>
        {items.map((o, i) => {
          const col = c.category[o.schedule.category].solid;
          const isDl = o.schedule.kind === 'deadline';
          return (
            <View
              key={i}
              style={{
                width: 7,
                height: 7,
                borderRadius: 4,
                backgroundColor: isDl ? 'transparent' : col,
                borderWidth: isDl ? 2 : 0,
                borderColor: late && isDl && !o.schedule.done ? c.danger : col,
              }}
            />
          );
        })}
      </View>
    );
  }
  const cats = [...new Set(items.map((o) => o.schedule.category))].slice(0, 3);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2, marginTop: 3, height: 8 }}>
      {cats.map((k) => (
        <View key={k} style={{ width: 6, height: 4, borderRadius: 2, backgroundColor: c.category[k].solid }} />
      ))}
      <Txt variant="caption" style={{ fontSize: 9, lineHeight: 10 }} muted>
        +{items.length - cats.length}
      </Txt>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Minggu

function WeekView({
  schedules,
  selected,
  onSelect,
  onLongPressSlot,
}: {
  schedules: ReturnType<typeof useApp.getState>['schedules'];
  selected: Date;
  onSelect: (d: Date) => void;
  onLongPressSlot: (d: Date) => void;
}) {
  const c = useTheme();
  const prefs = useApp((s) => s.prefs);
  const monday = startOfWeek(selected);
  const days = Array.from({ length: 7 }, (_, i) => addDays(monday, i));
  const occ = useMemo(() => occurrencesInRange(schedules, monday, endOfDay(days[6])), [schedules, monday.getTime()]);
  const startHour = Math.max(0, Math.floor(hhmmToMinutes(prefs.dayStart) / 60) - 1);
  const endMinutes = hhmmToMinutes(prefs.dayEnd);
  const endHour = endMinutes <= hhmmToMinutes(prefs.dayStart) ? 24 : Math.min(24, Math.ceil(endMinutes / 60) + 1);
  const hours = Array.from({ length: endHour - startHour }, (_, i) => startHour + i);
  const now = new Date();

  const timed = occ.filter((o) => !o.schedule.allDay && o.schedule.kind === 'acara');
  const allDay = occ.filter((o) => o.schedule.allDay || o.schedule.kind === 'deadline');

  return (
    <View style={{ flex: 1, marginTop: 12 }}>
      <View style={{ flexDirection: 'row', paddingLeft: 44, paddingRight: 8 }}>
        {days.map((d) => {
          const isSel = isSameDay(d, selected);
          const isToday = isSameDay(d, now);
          return (
            <Pressable key={d.toISOString()} onPress={() => onSelect(d)} style={{ flex: 1, alignItems: 'center', gap: 2 }} accessibilityLabel={formatLongDate(d)}>
              <Txt variant="caption" muted>
                {HARI_SINGKAT[d.getDay()]}
              </Txt>
              <View
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: isSel ? c.primary : 'transparent',
                  borderWidth: isToday && !isSel ? 2 : 0,
                  borderColor: c.primary,
                }}
              >
                <Txt variant="label" color={isSel ? '#FFF' : c.ink}>
                  {d.getDate()}
                </Txt>
              </View>
            </Pressable>
          );
        })}
      </View>

      {allDay.length > 0 && (
        <View style={{ flexDirection: 'row', paddingLeft: 44, paddingRight: 8, marginTop: 6 }}>
          {days.map((d) => {
            const items = allDay.filter((o) => isSameDay(o.start, d));
            return (
              <View key={d.toISOString()} style={{ flex: 1, gap: 2, paddingHorizontal: 1 }}>
                {items.slice(0, 2).map((o) => (
                  <Pressable
                    key={o.schedule.id + o.dateKey}
                    onPress={() => router.push({ pathname: '/jadwal/[id]', params: { id: o.schedule.id, tanggal: o.dateKey } })}
                    accessibilityLabel={o.schedule.title}
                    style={{
                      borderRadius: 4,
                      paddingHorizontal: 3,
                      paddingVertical: 2,
                      backgroundColor: c.category[o.schedule.category].soft,
                      borderLeftWidth: 3,
                      borderLeftColor: c.category[o.schedule.category].solid,
                      opacity: o.schedule.done ? 0.5 : 1,
                    }}
                  >
                    <Txt variant="caption" numberOfLines={1} style={{ fontSize: 10, lineHeight: 13 }}>
                      {o.schedule.title}
                    </Txt>
                  </Pressable>
                ))}
                {items.length > 2 && (
                  <Txt variant="caption" muted style={{ fontSize: 10 }}>
                    +{items.length - 2}
                  </Txt>
                )}
              </View>
            );
          })}
        </View>
      )}

      <ScrollView contentContainerStyle={{ paddingBottom: 100, paddingTop: 8 }} style={{ marginTop: 6, borderTopWidth: 1, borderTopColor: c.line }}>
        <View style={{ flexDirection: 'row' }}>
          <View style={{ width: 44 }}>
            {hours.map((h) => (
              <View key={h} style={{ height: HOUR_HEIGHT }}>
                <Txt variant="caption" muted style={{ fontSize: 10, textAlign: 'right', paddingRight: 6, marginTop: -6 }}>
                  {String(h % 24).padStart(2, '0')}.00
                </Txt>
              </View>
            ))}
          </View>
          <View style={{ flex: 1, flexDirection: 'row', marginRight: 8 }}>
            {days.map((d) => {
              const items = timed.filter((o) => isSameDay(o.start, d));
              return (
                <View key={d.toISOString()} style={{ flex: 1, borderLeftWidth: 1, borderLeftColor: c.scheme === 'dark' ? '#3A342E' : '#EADFCF' }}>
                  {hours.map((h) => (
                    <Pressable
                      key={h}
                      onLongPress={() => onLongPressSlot(new Date(d.getFullYear(), d.getMonth(), d.getDate(), h))}
                      accessibilityLabel={`Slot ${h}.00, tekan lama untuk tambah`}
                      style={{ height: HOUR_HEIGHT, borderTopWidth: 0.5, borderTopColor: c.scheme === 'dark' ? '#3A342E' : '#EADFCF' }}
                    />
                  ))}
                  {layoutColumns(items).map(({ o, col, cols }) => {
                    const top = ((o.start.getHours() * 60 + o.start.getMinutes()) / 60 - startHour) * HOUR_HEIGHT;
                    const height = Math.max(((o.end.getTime() - o.start.getTime()) / 3_600_000) * HOUR_HEIGHT, 22);
                    const k = c.category[o.schedule.category];
                    return (
                      <Pressable
                        key={o.schedule.id + o.dateKey}
                        onPress={() => router.push({ pathname: '/jadwal/[id]', params: { id: o.schedule.id, tanggal: o.dateKey } })}
                        accessibilityLabel={`${o.schedule.title}, ${formatTime(o.start)}`}
                        style={{
                          position: 'absolute',
                          top,
                          height,
                          left: `${(col / cols) * 100}%`,
                          width: `${100 / cols}%`,
                          padding: 1,
                        }}
                      >
                        <View style={{ flex: 1, borderRadius: 5, backgroundColor: k.soft, borderLeftWidth: 3, borderLeftColor: k.solid, padding: 3, overflow: 'hidden' }}>
                          <Txt variant="caption" style={{ fontSize: 10, lineHeight: 12 }} numberOfLines={3} color={k.ink}>
                            {o.schedule.title}
                          </Txt>
                        </View>
                      </Pressable>
                    );
                  })}
                  {isSameDay(d, now) && now.getHours() >= startHour && now.getHours() < endHour && (
                    <View
                      pointerEvents="none"
                      style={{
                        position: 'absolute',
                        left: 0,
                        right: 0,
                        top: ((now.getHours() * 60 + now.getMinutes()) / 60 - startHour) * HOUR_HEIGHT,
                        height: 2,
                        backgroundColor: c.danger,
                      }}
                    />
                  )}
                </View>
              );
            })}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

/** Acara yang bentrok tampil berdampingan. */
function layoutColumns(items: Occurrence[]) {
  const out: { o: Occurrence; col: number; cols: number }[] = [];
  let group: { o: Occurrence; col: number }[] = [];
  let groupEnd = 0;
  const flush = () => {
    const cols = Math.max(1, ...group.map((g) => g.col + 1));
    group.forEach((g) => out.push({ ...g, cols }));
    group = [];
  };
  for (const o of [...items].sort((a, b) => a.start.getTime() - b.start.getTime())) {
    if (group.length && o.start.getTime() >= groupEnd) flush();
    const used = new Set(group.filter((g) => g.o.end.getTime() > o.start.getTime()).map((g) => g.col));
    let col = 0;
    while (used.has(col)) col++;
    group.push({ o, col });
    groupEnd = Math.max(groupEnd, o.end.getTime());
  }
  if (group.length) flush();
  return out;
}

// ---------------------------------------------------------------------------
// Hari

function DayView({ schedules, selected, onSelect }: { schedules: ReturnType<typeof useApp.getState>['schedules']; selected: Date; onSelect: (d: Date) => void }) {
  const c = useTheme();
  const strip = Array.from({ length: 7 }, (_, i) => addDays(selected, i - 3));
  const occ = useMemo(() => occurrencesInRange(schedules, startOfDay(selected), endOfDay(selected)), [schedules, selected]);
  const allDay = occ.filter((o) => o.schedule.allDay || o.schedule.kind === 'deadline');
  const timed = occ.filter((o) => !o.schedule.allDay && o.schedule.kind === 'acara');
  const counts = {
    kuliah: timed.filter((o) => o.schedule.category === 'kuliah').length,
    lain: timed.filter((o) => o.schedule.category !== 'kuliah').length,
    deadline: allDay.filter((o) => o.schedule.kind === 'deadline').length,
  };
  const summary = [
    counts.kuliah ? `${counts.kuliah} kuliah` : '',
    counts.lain ? `${counts.lain} acara lain` : '',
    counts.deadline ? `${counts.deadline} deadline` : '',
  ].filter(Boolean);

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 100, gap: 14 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        {strip.map((d) => {
          const isSel = isSameDay(d, selected);
          return (
            <Pressable
              key={d.toISOString()}
              onPress={() => onSelect(startOfDay(d))}
              accessibilityLabel={formatLongDate(d)}
              style={{
                alignItems: 'center',
                width: 42,
                paddingVertical: 8,
                borderRadius: radius.md,
                borderWidth: 1.5,
                borderColor: isSel ? c.line : 'transparent',
                backgroundColor: isSel ? c.primary : 'transparent',
              }}
            >
              <Txt variant="caption" color={isSel ? '#FFF' : c.inkMuted}>
                {HARI_SINGKAT[d.getDay()]}
              </Txt>
              <Txt variant="subtitle" color={isSel ? '#FFF' : c.ink}>
                {d.getDate()}
              </Txt>
            </Pressable>
          );
        })}
      </View>

      <Card color={c.category.organisasi.soft} style={{ gap: 4 }}>
        <Txt variant="label" color={c.category.organisasi.ink}>
          RINGKASAN HARI
        </Txt>
        <Txt variant="title">{summary.length ? `${isSameDay(selected, new Date()) ? 'Hari ini' : 'Hari itu'} ${summary.join(', ')}` : 'Nggak ada jadwal. Santai dulu.'}</Txt>
      </Card>

      {allDay.length > 0 && (
        <View style={{ gap: 8 }}>
          <Txt variant="label" muted>
            SEHARIAN & DEADLINE
          </Txt>
          {allDay.map((o) => (
            <OccurrenceCard key={o.schedule.id + o.dateKey} occ={o} compact />
          ))}
        </View>
      )}

      {timed.map((o) => (
        <View key={o.schedule.id + o.dateKey} style={{ flexDirection: 'row', gap: 10 }}>
          <View style={{ width: 46, paddingTop: 12 }}>
            <Txt variant="label">{formatTime(o.start)}</Txt>
            <Txt variant="caption" muted>
              {formatTime(o.end)}
            </Txt>
          </View>
          <View style={{ flex: 1 }}>
            <OccurrenceCard occ={o} />
          </View>
        </View>
      ))}
    </ScrollView>
  );
}
