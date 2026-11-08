import { Feather } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { FlatList, Image, KeyboardAvoidingView, Platform, Pressable, TextInput, View } from 'react-native';

import { DraftCard } from '@/components/DraftCard';
import { TabHeader } from '@/components/Header';
import { Button, Chip, IconButton, Screen, Txt } from '@/components/ui';
import { saveDraft, sendMessage, useTyping } from '@/lib/chatEngine';
import { useFormPrefill } from '@/lib/formPrefill';
import type { ChatMessage } from '@/lib/store';
import { useApp, useToast } from '@/lib/store';
import { fonts, radius, useTheme } from '@/theme';

const DEFAULT_CHIPS = ['Kuliah tiap Senin jam 8', 'Deadline laprak Jumat', 'Rapat BEM besok jam 4 sore'];

export default function ChatScreen() {
  const c = useTheme();
  const chat = useApp((s) => s.chat);
  const clearChat = useApp((s) => s.clearChat);
  const typing = useTyping((s) => s.typing);
  const params = useLocalSearchParams<{ isi?: string }>();
  const [text, setText] = useState('');
  const listRef = useRef<FlatList<ChatMessage>>(null);

  // Teks contoh dari status kosong Kalender/Deadline.
  useEffect(() => {
    if (params.isi) setText(params.isi);
  }, [params.isi]);

  useEffect(() => {
    const t = setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 80);
    return () => clearTimeout(t);
  }, [chat.length, typing]);

  const send = (value = text) => {
    if (!value.trim()) return;
    sendMessage(value);
    setText('');
  };

  const last = chat[chat.length - 1];
  const chips = !text && last?.role === 'bot' && last.chips?.length ? last.chips : !text ? DEFAULT_CHIPS : [];

  return (
    <Screen>
      <TabHeader
        title="Chat"
        extra={<IconButton icon="edit" label="Percakapan baru" onPress={() => clearChat()} />}
      />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={0}>
        <FlatList
          ref={listRef}
          data={chat}
          keyExtractor={(m) => m.id}
          contentContainerStyle={{ padding: 16, gap: 12, flexGrow: 1 }}
          ListEmptyComponent={<Intro />}
          renderItem={({ item }) => <MessageView m={item} />}
          ListFooterComponent={typing ? <TypingBubble /> : undefined}
          keyboardShouldPersistTaps="handled"
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
        />

        {chips.length > 0 && (
          <FlatList
            horizontal
            data={chips}
            keyExtractor={(x) => x}
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ paddingHorizontal: 16, gap: 8, paddingBottom: 8 }}
            style={{ flexGrow: 0 }}
            keyboardShouldPersistTaps="handled"
            renderItem={({ item }) => (
              <Chip label={item} onPress={() => (useApp.getState().awaiting || item === 'Batal' ? send(item) : setText(item))} />
            )}
          />
        )}

        <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 8, paddingHorizontal: 16, paddingBottom: 12, paddingTop: 4 }}>
          <View
            style={{
              flex: 1,
              borderWidth: 1.5,
              borderColor: c.line,
              borderRadius: radius.lg,
              backgroundColor: c.surface,
              paddingHorizontal: 14,
              minHeight: 50,
              justifyContent: 'center',
            }}
          >
            <TextInput
              value={text}
              onChangeText={setText}
              placeholder="Misal: kuis Alin Kamis jam 10"
              placeholderTextColor={c.inkMuted}
              multiline
              maxLength={500}
              onSubmitEditing={() => send()}
              submitBehavior="submit"
              returnKeyType="send"
              accessibilityLabel="Ketik jadwal"
              style={{ fontFamily: fonts.body, fontSize: 15, color: c.ink, maxHeight: 120, paddingVertical: 12 }}
            />
          </View>
          <Pressable
            onPress={() => send()}
            disabled={!text.trim()}
            accessibilityRole="button"
            accessibilityLabel="Kirim"
            style={{
              width: 50,
              height: 50,
              borderRadius: 25,
              backgroundColor: text.trim() ? c.primary : c.surfaceAlt,
              borderWidth: 1.5,
              borderColor: c.line,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Feather name="arrow-up" size={22} color={text.trim() ? '#FFF' : c.inkMuted} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </Screen>
  );
}

function Intro() {
  const name = useApp((s) => s.prefs.nickname);
  const c = useTheme();
  return (
    <View style={{ flex: 1, justifyContent: 'flex-end', gap: 12, paddingBottom: 8 }}>
      <Txt variant="hero">
        Halo{name ? ` ${name}` : ''}!{'\n'}
        <Txt variant="hero" color={c.primary}>
          Mau nyatet apa?
        </Txt>
      </Txt>
      <Txt color={c.inkSoft}>
        Ketik aja jadwal atau deadline kamu pakai bahasa sehari-hari. Bisa beberapa sekaligus, misal "kuis alin kamis jam 10 sama deadline laprak fisdas jumat".
      </Txt>
    </View>
  );
}

function BotAvatar() {
  return <Image source={require('../../../assets/logo.png')} style={{ width: 28, height: 28, borderRadius: 8 }} accessibilityLabel="Kalibra" />;
}

function MessageView({ m }: { m: ChatMessage }) {
  const c = useTheme();
  if (m.role === 'user') {
    return (
      <View
        style={{
          alignSelf: 'flex-end',
          maxWidth: '82%',
          backgroundColor: c.primary,
          borderRadius: 18,
          borderBottomRightRadius: 4,
          paddingHorizontal: 14,
          paddingVertical: 10,
        }}
      >
        <Txt color="#FFFFFF">{m.text}</Txt>
      </View>
    );
  }
  if (m.role === 'drafts') {
    return (
      <View style={{ gap: 10 }}>
        {m.items.map((item, i) => (
          <DraftCard key={i} messageId={m.id} index={i} item={item} total={m.items.length} />
        ))}
        <SaveAll messageId={m.id} />
      </View>
    );
  }
  return (
    <View style={{ flexDirection: 'row', gap: 8, alignItems: 'flex-end', maxWidth: '88%' }}>
      <BotAvatar />
      <View style={{ flexShrink: 1, gap: 8 }}>
        <View
          style={{
            backgroundColor: c.surface,
            borderRadius: 18,
            borderBottomLeftRadius: 4,
            borderWidth: 1.5,
            borderColor: c.line,
            paddingHorizontal: 14,
            paddingVertical: 10,
          }}
        >
          <Txt>{m.text}</Txt>
        </View>
        {m.manualFallback !== undefined && (
          <Button
            label="Isi manual"
            icon="edit-3"
            kind="secondary"
            small
            style={{ alignSelf: 'flex-start' }}
            onPress={() => {
              useFormPrefill.getState().set({ input: { title: m.manualFallback?.slice(0, 80), source: 'manual' } });
              router.push('/jadwal/form');
            }}
          />
        )}
      </View>
    </View>
  );
}

function SaveAll({ messageId }: { messageId: string }) {
  const msg = useApp((s) => s.chat.find((m) => m.id === messageId));
  if (!msg || msg.role !== 'drafts') return null;
  const ready = msg.items
    .map((it, i) => ({ it, i }))
    .filter(({ it }) => it.status === 'pending' && it.draft.missing.length === 0 && it.draft.title);
  if (ready.length < 2) return null;
  return (
    <Button
      label={`Simpan semua (${ready.length})`}
      icon="check-circle"
      onPress={() => {
        ready.forEach(({ i }) => saveDraft(messageId, i));
        useToast.getState().show(`${ready.length} jadwal tersimpan`);
      }}
    />
  );
}

function TypingBubble() {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: 8, alignItems: 'flex-end', marginTop: 12 }} accessibilityLabel="Kalibra sedang mengetik">
      <BotAvatar />
      <View style={{ flexDirection: 'row', gap: 4, backgroundColor: c.surface, borderRadius: 18, borderWidth: 1.5, borderColor: c.line, paddingHorizontal: 14, paddingVertical: 14 }}>
        {[0, 1, 2].map((i) => (
          <View key={i} style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: c.inkMuted, opacity: 0.4 + i * 0.25 }} />
        ))}
      </View>
    </View>
  );
}
