import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Image, Platform, Pressable, ScrollView, View } from 'react-native';

import { Button, Card, CategoryChip, Chip, Field, Screen, Txt } from '@/components/ui';
import { CATEGORIES, REMINDER_OPTIONS } from '@/lib/categories';
import { requestPermission } from '@/lib/notifications';
import { useApp } from '@/lib/store';
import type { CategoryId } from '@/lib/types';
import { radius, useTheme } from '@/theme';

type Step = 'welcome' | 'q1' | 'q2' | 'q3' | 'q4' | 'q5' | 'ringkasan' | 'akun' | 'notifikasi';
const QUESTION_STEPS: Step[] = ['q1', 'q2', 'q3', 'q4', 'q5'];

const SLIDES = [
  { title: 'Ketik aja, Kalibra yang nyatet.', body: '"Kuis Alin Kamis jam 10" langsung jadi kartu jadwal. Kamu tinggal cek dan simpan.', icon: 'message-circle' as const },
  { title: 'Semua jadwal di satu tempat.', body: 'Kuliah, tugas, organisasi, magang, dan urusan pribadi di satu kalender berwarna.', icon: 'calendar' as const },
  { title: 'Diingetin sebelum telat.', body: 'Pengingat dengan tombol Selesai dan Tunda, langsung dari notifikasi.', icon: 'bell' as const },
];

const HABITS = ['Kepala aja', 'Notes HP', 'Google Calendar', 'Grup WhatsApp/Line', 'Kertas/planner'];
const DAY_STARTS = ['05:30', '06:30', '07:30', '08:30'];
const DAY_ENDS = ['22:00', '23:00', '00:00', '01:00'];
const MISSED = ['Hampir nggak pernah', 'Jarang', 'Kadang', 'Sering', 'Tiap minggu'];

export default function Onboarding() {
  const c = useTheme();
  const prefs = useApp((s) => s.prefs);
  const setPrefs = useApp((s) => s.setPrefs);
  const completeOnboarding = useApp((s) => s.completeOnboarding);
  const pushChat = useApp((s) => s.pushChat);

  const [step, setStep] = useState<Step>('welcome');
  const [slide, setSlide] = useState(0);
  const [nickname, setNickname] = useState(prefs.nickname);
  const [email, setEmail] = useState(prefs.email);
  const [consent, setConsent] = useState(false);
  const [touched, setTouched] = useState(false);

  const qIndex = QUESTION_STEPS.indexOf(step);
  const next = (s: Step) => setStep(s);
  const emailValid = !email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

  const finish = async (withNotif: boolean) => {
    let granted = false;
    if (withNotif) granted = await requestPermission();
    setPrefs({ notificationsEnabled: granted });
    const name = nickname.trim();
    pushChat({
      id: `welcome-${Date.now()}`,
      role: 'bot',
      createdAt: new Date().toISOString(),
      text: `Halo ${name}! Ketik aja jadwal atau deadline kamu, nanti Kalibra yang nyusun. Kamu bisa nulis beberapa sekaligus.\n\nChat kamu diproses untuk membuat jadwal dan disimpan di HP ini.`,
      chips: ['Kuliah BasDat tiap Senin jam 8', 'Deadline laprak Jumat', 'Rapat BEM besok jam 4 sore'],
    });
    completeOnboarding();
    router.replace('/chat');
  };

  // -------------------------------------------------------------------------
  if (step === 'welcome') {
    const s = SLIDES[slide];
    return (
      <Screen edges={['top', 'bottom']}>
        <View style={{ flex: 1, paddingHorizontal: 24, paddingTop: 12 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <Image source={require('../../../assets/logo.png')} style={{ width: 36, height: 36, borderRadius: 9 }} accessibilityLabel="Logo Kalibra" />
            <Txt variant="title">Kalibra</Txt>
          </View>

          <View style={{ flex: 1, justifyContent: 'center', gap: 28 }}>
            <WelcomeIllustration index={slide} />
            <View style={{ gap: 12 }}>
              <Txt variant="hero">{s.title}</Txt>
              <Txt variant="body" color={c.inkSoft} style={{ fontSize: 17, lineHeight: 25 }}>
                {s.body}
              </Txt>
            </View>
            <View style={{ flexDirection: 'row', gap: 8 }} accessibilityLabel={`Slide ${slide + 1} dari 3`}>
              {SLIDES.map((_, i) => (
                <Pressable key={i} onPress={() => setSlide(i)} accessibilityLabel={`Slide ${i + 1}`} hitSlop={8}>
                  <View
                    style={{
                      width: i === slide ? 28 : 10,
                      height: 10,
                      borderRadius: 5,
                      borderWidth: 1.5,
                      borderColor: c.line,
                      backgroundColor: i === slide ? c.primary : 'transparent',
                    }}
                  />
                </Pressable>
              ))}
            </View>
          </View>

          <View style={{ gap: 12, paddingBottom: 8 }}>
            <Button
              label={slide < 2 ? 'Lanjut' : 'Mulai'}
              onPress={() => (slide < 2 ? setSlide(slide + 1) : next('q1'))}
              icon="arrow-right"
            />
            <Txt variant="caption" muted style={{ textAlign: 'center' }}>
              Dengan lanjut, kamu setuju dengan Syarat & Kebijakan Privasi Kalibra.
            </Txt>
          </View>
        </View>
      </Screen>
    );
  }

  // -------------------------------------------------------------------------
  if (qIndex >= 0) {
    const skip = () => next(QUESTION_STEPS[qIndex + 1] ?? 'ringkasan');
    return (
      <Screen edges={['top', 'bottom']}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingTop: 8, gap: 12 }}>
          <Pressable onPress={() => next(qIndex === 0 ? 'welcome' : QUESTION_STEPS[qIndex - 1])} accessibilityLabel="Kembali" hitSlop={10}>
            <Feather name="arrow-left" size={22} color={c.ink} />
          </Pressable>
          <View style={{ flex: 1, height: 10, borderRadius: 5, borderWidth: 1.5, borderColor: c.line, overflow: 'hidden' }}>
            <View style={{ width: `${((qIndex + 1) / 5) * 100}%`, height: '100%', backgroundColor: c.primary }} />
          </View>
          <Pressable onPress={skip} accessibilityRole="button" hitSlop={10}>
            <Txt variant="label" color={c.primary}>
              Lewati
            </Txt>
          </Pressable>
        </View>
        <ScrollView contentContainerStyle={{ padding: 24, gap: 20, flexGrow: 1 }}>
          <Txt variant="label" muted>
            Pertanyaan {qIndex + 1} dari 5
          </Txt>

          {step === 'q1' && (
            <>
              <Txt variant="display">Kamu lagi sibuk apa aja?</Txt>
              <Txt muted>Pilih semua yang cocok. Ini jadi kategori di kalendermu.</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {CATEGORIES.map((cat) => {
                  const selected = prefs.categories.includes(cat.id);
                  return (
                    <CategoryChip
                      key={cat.id}
                      id={cat.id}
                      selected={selected}
                      onPress={() => {
                        const list: CategoryId[] = selected
                          ? prefs.categories.filter((x) => x !== cat.id)
                          : [...prefs.categories, cat.id];
                        setPrefs({ categories: list.length ? list : [cat.id] });
                      }}
                    />
                  );
                })}
              </View>
            </>
          )}

          {step === 'q2' && (
            <>
              <Txt variant="display">Biasanya kamu nyatet jadwal di mana?</Txt>
              <View style={{ gap: 10 }}>
                {HABITS.map((h) => (
                  <OptionRow key={h} label={h} selected={prefs.noteHabit === h} onPress={() => setPrefs({ noteHabit: h })} />
                ))}
              </View>
            </>
          )}

          {step === 'q3' && (
            <>
              <Txt variant="display">Mau diingetin berapa lama sebelumnya?</Txt>
              <Txt variant="subtitle">Untuk acara</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {REMINDER_OPTIONS.filter((r) => [10, 30, 60, 1440].includes(r.minutes)).map((r) => (
                  <Chip key={r.minutes} label={r.label} selected={prefs.eventReminder === r.minutes} onPress={() => setPrefs({ eventReminder: r.minutes })} />
                ))}
              </View>
              <Txt variant="subtitle">Untuk deadline</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {REMINDER_OPTIONS.filter((r) => [1440, 4320, 10080].includes(r.minutes)).map((r) => (
                  <Chip key={r.minutes} label={r.label} selected={prefs.deadlineReminder === r.minutes} onPress={() => setPrefs({ deadlineReminder: r.minutes })} />
                ))}
              </View>
            </>
          )}

          {step === 'q4' && (
            <>
              <Txt variant="display">Jam berapa kamu biasanya mulai dan selesai hari?</Txt>
              <Txt muted>Dipakai untuk ringkasan pagi dan jam tenang notifikasi.</Txt>
              <Txt variant="subtitle">Mulai</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {DAY_STARTS.map((t) => (
                  <Chip key={t} label={t.replace(':', '.')} selected={prefs.dayStart === t} onPress={() => setPrefs({ dayStart: t })} />
                ))}
              </View>
              <Txt variant="subtitle">Selesai</Txt>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {DAY_ENDS.map((t) => (
                  <Chip key={t} label={t.replace(':', '.')} selected={prefs.dayEnd === t} onPress={() => setPrefs({ dayEnd: t })} />
                ))}
              </View>
            </>
          )}

          {step === 'q5' && (
            <>
              <Txt variant="display">Seberapa sering kamu ngerasa ada yang kelewat?</Txt>
              <View style={{ gap: 10 }}>
                {MISSED.map((label, i) => (
                  <OptionRow
                    key={label}
                    label={`${i + 1} · ${label}`}
                    selected={prefs.missedFrequency === i + 1}
                    onPress={() => setPrefs({ missedFrequency: i + 1 })}
                  />
                ))}
              </View>
            </>
          )}
        </ScrollView>
        <View style={{ padding: 24, paddingTop: 0 }}>
          <Button label="Lanjut" icon="arrow-right" onPress={skip} />
        </View>
      </Screen>
    );
  }

  // -------------------------------------------------------------------------
  if (step === 'ringkasan') {
    const ev = REMINDER_OPTIONS.find((r) => r.minutes === prefs.eventReminder)?.label ?? '';
    const dl = REMINDER_OPTIONS.find((r) => r.minutes === prefs.deadlineReminder)?.label ?? '';
    return (
      <Screen edges={['top', 'bottom']}>
        <ScrollView contentContainerStyle={{ padding: 24, gap: 20, flexGrow: 1, justifyContent: 'center' }}>
          <Txt variant="hero">Oke, Kalibra udah disesuaikan buat kamu.</Txt>
          <Card style={{ gap: 14 }} color={c.surfaceAlt}>
            <SummaryRow icon="grid" label="Kategori" value={prefs.categories.map((x) => CATEGORIES.find((k) => k.id === x)?.label).join(', ')} />
            <SummaryRow icon="bell" label="Pengingat" value={`Acara ${ev} · Deadline ${dl} sebelum`} />
            <SummaryRow icon="sunrise" label="Ringkasan pagi" value={`Jam ${prefs.dayStart.replace(':', '.')}`} />
          </Card>
          <Txt muted>Semua bisa diubah lagi di Pengaturan.</Txt>
        </ScrollView>
        <View style={{ padding: 24, paddingTop: 0 }}>
          <Button label="Buat profil" icon="arrow-right" onPress={() => next('akun')} />
        </View>
      </Screen>
    );
  }

  // -------------------------------------------------------------------------
  if (step === 'akun') {
    const canContinue = nickname.trim().length > 0 && consent && emailValid;
    return (
      <Screen edges={['top', 'bottom']}>
        <ScrollView contentContainerStyle={{ padding: 24, gap: 18 }} keyboardShouldPersistTaps="handled">
          <Pressable onPress={() => next('ringkasan')} accessibilityLabel="Kembali" hitSlop={10}>
            <Feather name="arrow-left" size={22} color={c.ink} />
          </Pressable>
          <Txt variant="display">Kenalan dulu</Txt>
          <Txt muted>
            Untuk versi awal ini, data kamu disimpan di HP ini saja. Login Google, Apple, dan email akan aktif begitu server Kalibra siap.
          </Txt>

          <View style={{ gap: 10, opacity: 0.5 }}>
            <Button label="Lanjut dengan Google (segera)" kind="secondary" icon="log-in" disabled />
            {Platform.OS === 'ios' && <Button label="Lanjut dengan Apple (segera)" kind="secondary" icon="log-in" disabled />}
          </View>

          <Field label="Nama panggilan" value={nickname} onChangeText={setNickname} placeholder="Misal: Akbar" autoCapitalize="words" maxLength={30} />
          <Field
            label="Email (opsional)"
            value={email}
            onChangeText={setEmail}
            onBlur={() => setTouched(true)}
            placeholder="nama@ui.ac.id"
            keyboardType="email-address"
            autoCapitalize="none"
            error={touched && !emailValid ? 'Format email belum benar' : undefined}
          />

          <Pressable
            onPress={() => setConsent(!consent)}
            accessibilityRole="checkbox"
            accessibilityState={{ checked: consent }}
            style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-start' }}
          >
            <View
              style={{
                width: 24,
                height: 24,
                borderRadius: 6,
                borderWidth: 1.5,
                borderColor: c.line,
                backgroundColor: consent ? c.primary : c.surface,
                alignItems: 'center',
                justifyContent: 'center',
                marginTop: 1,
              }}
            >
              {consent && <Feather name="check" size={16} color="#FFF" />}
            </View>
            <Txt style={{ flex: 1 }} color={c.inkSoft}>
              Saya setuju dengan Syarat dan Kebijakan Privasi, termasuk bahwa teks chat diproses untuk membuat jadwal (UU PDP No. 27/2022).
            </Txt>
          </Pressable>
        </ScrollView>
        <View style={{ padding: 24, paddingTop: 0 }}>
          <Button
            label="Lanjut"
            icon="arrow-right"
            disabled={!canContinue}
            onPress={() => {
              setPrefs({ nickname: nickname.trim(), email: email.trim() });
              next('notifikasi');
            }}
          />
        </View>
      </Screen>
    );
  }

  // -------------------------------------------------------------------------
  return (
    <Screen edges={['top', 'bottom']}>
      <View style={{ flex: 1, padding: 24, justifyContent: 'center', gap: 24 }}>
        <Card style={{ gap: 6, transform: [{ rotate: '-2deg' }] }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            <Image source={require('../../../assets/logo.png')} style={{ width: 20, height: 20, borderRadius: 5 }} />
            <Txt variant="caption" muted>
              KALIBRA · sekarang
            </Txt>
          </View>
          <Txt variant="subtitle">Kuis Alin 30 menit lagi</Txt>
          <Txt variant="caption" muted>
            Kam, 10.00 · Gedung A
          </Txt>
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 6 }}>
            <Chip label="Selesai" />
            <Chip label="Tunda" />
          </View>
        </Card>
        <Txt variant="hero">Biar deadline nggak kelewat</Txt>
        <Txt color={c.inkSoft} style={{ fontSize: 17, lineHeight: 25 }}>
          Kalibra butuh izin notifikasi untuk mengingatkan kamu sebelum kuliah, rapat, dan tenggat tugas. Pengingat dijadwalkan di HP, jadi tetap jalan walau offline.
        </Txt>
      </View>
      <View style={{ padding: 24, paddingTop: 0, gap: 8 }}>
        <Button label="Nyalakan pengingat" icon="bell" onPress={() => finish(true)} />
        <Button label="Nanti aja" kind="ghost" onPress={() => finish(false)} />
      </View>
    </Screen>
  );
}

function OptionRow({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const c = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        minHeight: 54,
        paddingHorizontal: 16,
        borderRadius: radius.md,
        borderWidth: 1.5,
        borderColor: c.line,
        backgroundColor: selected ? c.primarySoft : c.surface,
      }}
    >
      <View
        style={{
          width: 20,
          height: 20,
          borderRadius: 10,
          borderWidth: 1.5,
          borderColor: c.line,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {selected && <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: c.primary }} />}
      </View>
      <Txt variant="subtitle" style={{ flex: 1, fontSize: 15 }}>
        {label}
      </Txt>
    </Pressable>
  );
}

function SummaryRow({ icon, label, value }: { icon: 'grid' | 'bell' | 'sunrise'; label: string; value: string }) {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-start' }}>
      <Feather name={icon} size={18} color={c.primary} style={{ marginTop: 2 }} />
      <View style={{ flex: 1 }}>
        <Txt variant="label" muted>
          {label}
        </Txt>
        <Txt variant="subtitle">{value}</Txt>
      </View>
    </View>
  );
}

/** Ilustrasi sederhana per slide, dibangun dari komponen asli (bukan gambar stok). */
function WelcomeIllustration({ index }: { index: number }) {
  const c = useTheme();
  if (index === 0) {
    return (
      <View style={{ gap: 12 }}>
        <View style={{ alignSelf: 'flex-end', backgroundColor: c.primary, borderRadius: 18, borderBottomRightRadius: 4, paddingHorizontal: 16, paddingVertical: 10, borderWidth: 1.5, borderColor: c.line }}>
          <Txt variant="subtitle" color="#FFF">
            Kuis Alin Kamis jam 10
          </Txt>
        </View>
        <Card style={{ gap: 6, transform: [{ rotate: '-2deg' }] }} color={c.category.kuliah.soft}>
          <CategoryChip id="kuliah" small />
          <Txt variant="title">Kuis Alin</Txt>
          <Txt variant="caption" color={c.inkSoft}>
            Kamis · 10.00–11.00 · Pengingat 30 menit
          </Txt>
        </Card>
      </View>
    );
  }
  if (index === 1) {
    const cats: CategoryId[] = ['kuliah', 'tugas', 'organisasi', 'magang', 'pribadi'];
    return (
      <Card style={{ gap: 10 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          {['S', 'S', 'R', 'K', 'J', 'S', 'M'].map((d, i) => (
            <View key={i} style={{ alignItems: 'center', gap: 6, flex: 1 }}>
              <Txt variant="caption" muted>
                {d}
              </Txt>
              <View
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 17,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: i === 2 ? c.primary : 'transparent',
                }}
              >
                <Txt variant="label" color={i === 2 ? '#FFF' : c.ink}>
                  {2 + i}
                </Txt>
              </View>
              <View style={{ flexDirection: 'row', gap: 3 }}>
                {cats.slice(0, (i % 3) + 1).map((k, j) => (
                  <View key={j} style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: c.category[cats[(i + j) % 5]].solid }} />
                ))}
              </View>
            </View>
          ))}
        </View>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}>
          {cats.map((k) => (
            <CategoryChip key={k} id={k} small />
          ))}
        </View>
      </Card>
    );
  }
  return (
    <Card style={{ gap: 6, transform: [{ rotate: '2deg' }] }}>
      <Txt variant="caption" muted>
        KALIBRA · 3 jam lagi
      </Txt>
      <Txt variant="subtitle">Deadline: Laprak Fisdas</Txt>
      <Txt variant="caption" muted>
        Tenggat hari ini 23.59. Udah dikerjain?
      </Txt>
      <View style={{ flexDirection: 'row', gap: 8, marginTop: 6 }}>
        <Chip label="Tandai selesai" icon="check" />
        <Chip label="Tunda 1 jam" icon="clock" />
      </View>
    </Card>
  );
}
