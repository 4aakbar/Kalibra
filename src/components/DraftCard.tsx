import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, TextInput, View } from 'react-native';

import { CATEGORIES, PRIORITY_LABEL, reminderLabel } from '@/lib/categories';
import { cancelDraft, draftToInput, saveDraft, updateDraft } from '@/lib/chatEngine';
import { formatLongDate, formatTime } from '@/lib/date';
import { useFormPrefill } from '@/lib/formPrefill';
import type { Draft, DraftField } from '@/lib/parser/parse';
import { draftTimes } from '@/lib/parser/parse';
import type { DraftItem } from '@/lib/store';
import { fromStoredDraft, useApp, useToast } from '@/lib/store';
import { fonts, radius, useTheme } from '@/theme';

import { Button, Card, CategoryChip, Txt } from './ui';

const FREQ_LABEL = { harian: 'Setiap hari', mingguan: 'Setiap minggu', 'dua-mingguan': 'Setiap 2 minggu', bulanan: 'Setiap bulan' };

function whenText(d: Draft): string {
  const t = draftTimes(d);
  if (!d.date) return 'Tanggal belum ada';
  if (!t) return `${formatLongDate(d.date)} · jam belum ada`;
  if (d.allDay) return `${formatLongDate(t.start)} · Seharian`;
  if (d.kind === 'deadline') return `${formatLongDate(t.start)} · tenggat ${formatTime(t.start)}`;
  return `${formatLongDate(t.start)} · ${formatTime(t.start)}–${formatTime(t.end!)}`;
}

export function DraftCard({ messageId, index, item, total }: { messageId: string; index: number; item: DraftItem; total: number }) {
  const c = useTheme();
  const prefs = useApp((s) => s.prefs);
  const draft = fromStoredDraft(item.draft);
  const [editingCategory, setEditingCategory] = useState(false);
  const unsure = (f: DraftField) => draft.uncertain.includes(f);

  if (item.status !== 'pending') {
    const saved = item.status === 'saved';
    return (
      <Pressable
        disabled={!saved || !item.scheduleId}
        onPress={() => item.scheduleId && router.push({ pathname: '/jadwal/[id]', params: { id: item.scheduleId } })}
        accessibilityRole={saved ? 'button' : undefined}
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 10,
          padding: 12,
          borderRadius: radius.md,
          borderWidth: 1.5,
          borderColor: saved ? c.success : c.line,
          backgroundColor: saved ? c.successSoft : c.surfaceAlt,
          opacity: saved ? 1 : 0.6,
        }}
      >
        <Feather name={saved ? 'check-circle' : 'x-circle'} size={18} color={saved ? c.success : c.inkMuted} />
        <View style={{ flex: 1 }}>
          <Txt variant="subtitle" numberOfLines={1} style={{ textDecorationLine: saved ? 'none' : 'line-through' }}>
            {draft.title || 'Tanpa judul'}
          </Txt>
          <Txt variant="caption" muted>
            {saved ? 'Tersimpan' : 'Dibatalkan'} · {whenText(draft)}
          </Txt>
        </View>
        {saved && <Feather name="chevron-right" size={18} color={c.inkMuted} />}
      </Pressable>
    );
  }

  const input = draftToInput(draft, prefs);
  const canSave = !!input && draft.missing.length === 0;

  const onSave = () => {
    const id = saveDraft(messageId, index);
    if (id)
      useToast.getState().show('Tersimpan ke Kalender', {
        label: 'Lihat',
        onPress: () => router.push({ pathname: '/jadwal/[id]', params: { id } }),
      });
  };

  const onEdit = () => {
    useFormPrefill.getState().set({
      input: input ?? {
        kind: draft.kind,
        title: draft.title,
        category: draft.category,
        priority: draft.priority,
        start: draft.date?.toISOString(),
        location: draft.location,
        source: 'chat',
      },
      draftRef: { messageId, index },
    });
    router.push('/jadwal/form');
  };

  return (
    <Card style={{ gap: 10, padding: 16 }} accessibilityLabel={`Draf jadwal ${draft.title}`}>
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Txt variant="caption" muted style={{ letterSpacing: 1 }}>
            {draft.kind === 'deadline' ? 'DRAF DEADLINE' : 'DRAF ACARA'}
            {total > 1 ? ` ${index + 1}/${total}` : ''}
          </Txt>
        </View>
        <Pressable onPress={() => setEditingCategory(!editingCategory)} accessibilityRole="button" accessibilityLabel="Ubah kategori" hitSlop={8}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
            <CategoryChip id={draft.category} small />
            {unsure('kategori') && <Feather name="help-circle" size={14} color={c.warning} />}
          </View>
        </Pressable>
      </View>

      {editingCategory && (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}>
          {CATEGORIES.map((cat) => (
            <CategoryChip
              key={cat.id}
              id={cat.id}
              selected={cat.id === draft.category}
              onPress={() => {
                updateDraft(messageId, index, { category: cat.id });
                setEditingCategory(false);
              }}
            />
          ))}
        </View>
      )}

      <TextInput
        value={draft.title}
        onChangeText={(title) => updateDraft(messageId, index, { title, missing: title ? draft.missing.filter((f) => f !== 'judul') : draft.missing })}
        placeholder="Judul kegiatan"
        placeholderTextColor={c.inkMuted}
        accessibilityLabel="Judul"
        style={{ fontFamily: fonts.display, fontSize: 22, color: c.ink, padding: 0 }}
        maxLength={80}
      />

      <Row icon="calendar" uncertain={unsure('tanggal') || unsure('jam')} missing={draft.missing.includes('tanggal') || draft.missing.includes('jam')}>
        {whenText(draft)}
      </Row>
      {draft.recurrence && <Row icon="repeat">{FREQ_LABEL[draft.recurrence.freq]}</Row>}
      {draft.location && <Row icon="map-pin">{draft.location}</Row>}
      <Row icon="bell">{reminderLabel(draft.kind === 'deadline' ? prefs.deadlineReminder : prefs.eventReminder)}</Row>
      {draft.priority !== 'sedang' && <Row icon="flag">{`Prioritas ${PRIORITY_LABEL[draft.priority].toLowerCase()}`}</Row>}

      {draft.uncertain.length > 0 && draft.missing.length === 0 && (
        <Txt variant="caption" color={c.warning}>
          Yang bertanda ? hasil tebakan. Cek dulu ya.
        </Txt>
      )}

      <View style={{ flexDirection: 'row', gap: 8, marginTop: 4, flexWrap: 'wrap' }}>
        <Button label="Simpan" icon="check" small onPress={onSave} disabled={!canSave} />
        <Button label="Ubah" kind="secondary" small onPress={onEdit} />
        <Button label="Batal" kind="ghost" small onPress={() => cancelDraft(messageId, index)} />
      </View>
    </Card>
  );
}

function Row({ icon, children, uncertain, missing }: { icon: 'calendar' | 'repeat' | 'map-pin' | 'bell' | 'flag'; children: string; uncertain?: boolean; missing?: boolean }) {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
      <Feather name={icon} size={15} color={missing ? c.danger : c.inkSoft} />
      <Txt
        variant="body"
        color={missing ? c.danger : c.inkSoft}
        style={{
          flex: 1,
          fontSize: 14,
          textDecorationLine: uncertain ? 'underline' : 'none',
          textDecorationStyle: 'dashed',
        }}
      >
        {children}
      </Txt>
      {uncertain && <Feather name="help-circle" size={14} color={c.warning} accessibilityLabel="Perlu dicek" />}
    </View>
  );
}
