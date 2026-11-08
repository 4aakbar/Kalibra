import { Feather } from '@expo/vector-icons';
import type { ComponentProps, ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type PressableProps,
  type StyleProp,
  type TextInputProps,
  type TextProps,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView, type Edge } from 'react-native-safe-area-context';

import { categoryMeta } from '@/lib/categories';
import type { CategoryId } from '@/lib/types';
import { fonts, radius, useTheme } from '@/theme';

export type IconName = ComponentProps<typeof Feather>['name'];

// ---------------------------------------------------------------------------
// Teks

type Variant = 'hero' | 'display' | 'title' | 'subtitle' | 'body' | 'label' | 'caption';

const variantStyle: Record<Variant, TextStyle> = {
  hero: { fontFamily: fonts.displayHeavy, fontSize: 40, lineHeight: 44, letterSpacing: -1 },
  display: { fontFamily: fonts.display, fontSize: 30, lineHeight: 34, letterSpacing: -0.6 },
  title: { fontFamily: fonts.display, fontSize: 20, lineHeight: 25, letterSpacing: -0.2 },
  subtitle: { fontFamily: fonts.semibold, fontSize: 16, lineHeight: 22 },
  body: { fontFamily: fonts.body, fontSize: 15, lineHeight: 22 },
  label: { fontFamily: fonts.semibold, fontSize: 13, lineHeight: 18 },
  caption: { fontFamily: fonts.medium, fontSize: 12, lineHeight: 16 },
};

export function Txt({
  variant = 'body',
  color,
  muted,
  style,
  ...rest
}: TextProps & { variant?: Variant; color?: string; muted?: boolean }) {
  const c = useTheme();
  return (
    <Text
      maxFontSizeMultiplier={1.6}
      {...rest}
      style={[variantStyle[variant], { color: color ?? (muted ? c.inkMuted : c.ink) }, style]}
    />
  );
}

// ---------------------------------------------------------------------------
// Layout

export function Screen({
  children,
  edges = ['top'],
  style,
}: {
  children: ReactNode;
  edges?: Edge[];
  style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  return (
    <SafeAreaView edges={edges} style={[{ flex: 1, backgroundColor: c.bg }, style]}>
      {children}
    </SafeAreaView>
  );
}

/** Kartu dengan garis tegas dan bayangan keras kecil (berfungsi sama di iOS, Android, web). */
export function Card({
  children,
  style,
  offset = 3,
  color,
  borderColor,
  onPress,
  accessibilityLabel,
}: {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  offset?: number;
  color?: string;
  borderColor?: string;
  onPress?: () => void;
  accessibilityLabel?: string;
}) {
  const c = useTheme();
  const flat = StyleSheet.flatten(style) ?? {};
  const r = (flat.borderRadius as number | undefined) ?? radius.md;
  const body = (
    <View style={{ marginRight: offset, marginBottom: offset }}>
      <View
        style={{
          position: 'absolute',
          left: offset,
          top: offset,
          right: -offset,
          bottom: -offset,
          borderRadius: r,
          backgroundColor: c.scheme === 'dark' ? '#000000' : c.shadow,
          opacity: c.scheme === 'dark' ? 0.5 : 1,
        }}
      />
      <View
        style={[
          {
            backgroundColor: color ?? c.surface,
            borderRadius: r,
            borderWidth: 1.5,
            borderColor: borderColor ?? c.line,
            padding: 14,
          },
          style,
        ]}
      >
        {children}
      </View>
    </View>
  );
  if (!onPress) return body;
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      style={({ pressed }) => ({ transform: [{ translateX: pressed ? 1.5 : 0 }, { translateY: pressed ? 1.5 : 0 }] })}
    >
      {body}
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Tombol

type ButtonKind = 'primary' | 'secondary' | 'ghost' | 'danger';

export function Button({
  label,
  onPress,
  kind = 'primary',
  icon,
  disabled,
  loading,
  small,
  style,
  accessibilityLabel,
}: {
  label: string;
  onPress?: () => void;
  kind?: ButtonKind;
  icon?: IconName;
  disabled?: boolean;
  loading?: boolean;
  small?: boolean;
  style?: StyleProp<ViewStyle>;
  accessibilityLabel?: string;
}) {
  const c = useTheme();
  const bg = { primary: c.primary, secondary: c.surface, ghost: 'transparent', danger: c.danger }[kind];
  const fg = { primary: c.onPrimary, secondary: c.ink, ghost: c.primary, danger: '#FFFFFF' }[kind];
  const bordered = kind !== 'ghost';
  const offset = bordered && !disabled ? 3 : 0;
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled: !!disabled }}
      hitSlop={6}
      style={({ pressed }) => [
        { marginRight: offset, marginBottom: offset, opacity: disabled ? 0.45 : 1 },
        pressed && offset ? { transform: [{ translateX: 2 }, { translateY: 2 }] } : null,
        style,
      ]}
    >
      {({ pressed }) => (
        <View>
          {offset > 0 && !pressed && (
            <View
              style={{
                position: 'absolute',
                left: offset,
                top: offset,
                right: -offset,
                bottom: -offset,
                borderRadius: radius.pill,
                backgroundColor: c.scheme === 'dark' ? '#000' : c.shadow,
                opacity: c.scheme === 'dark' ? 0.5 : 1,
              }}
            />
          )}
          <View
            style={{
              minHeight: small ? 38 : 50,
              paddingHorizontal: small ? 14 : 22,
              borderRadius: radius.pill,
              backgroundColor: bg,
              borderWidth: bordered ? 1.5 : 0,
              borderColor: c.line,
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
            }}
          >
            {loading ? (
              <ActivityIndicator color={fg} />
            ) : (
              <>
                {icon && <Feather name={icon} size={small ? 16 : 18} color={fg} />}
                <Txt variant={small ? 'label' : 'subtitle'} color={fg}>
                  {label}
                </Txt>
              </>
            )}
          </View>
        </View>
      )}
    </Pressable>
  );
}

export function IconButton({
  icon,
  onPress,
  label,
  size = 22,
  color,
  style,
}: {
  icon: IconName;
  onPress?: () => void;
  label: string;
  size?: number;
  color?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={label}
      hitSlop={8}
      style={({ pressed }) => [
        { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22, opacity: pressed ? 0.6 : 1 },
        style,
      ]}
    >
      <Feather name={icon} size={size} color={color ?? c.ink} />
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Chip

export function Chip({
  label,
  selected,
  onPress,
  icon,
  color,
  softColor,
  inkColor,
  style,
}: {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: IconName;
  color?: string;
  softColor?: string;
  inkColor?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  const bg = selected ? (color ?? c.primary) : (softColor ?? c.surface);
  const fg = selected ? (color ? c.ink : c.onPrimary) : (inkColor ?? c.ink);
  const content = (
    <View
      style={[
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 6,
          paddingHorizontal: 12,
          minHeight: 34,
          borderRadius: radius.pill,
          borderWidth: 1.5,
          borderColor: selected ? c.line : softColor ? 'transparent' : c.line,
          backgroundColor: bg,
        },
        style,
      ]}
    >
      {icon && <Feather name={icon} size={14} color={selected && color ? '#1F1B16' : fg} />}
      <Txt variant="label" color={selected && color ? '#1F1B16' : fg}>
        {label}
      </Txt>
    </View>
  );
  if (!onPress) return content;
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      accessibilityLabel={label}
      hitSlop={6}
    >
      {content}
    </Pressable>
  );
}

export function CategoryChip({
  id,
  selected,
  onPress,
  small,
}: {
  id: CategoryId;
  selected?: boolean;
  onPress?: () => void;
  small?: boolean;
}) {
  const c = useTheme();
  const meta = categoryMeta(id);
  const col = c.category[id];
  if (small) {
    return (
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 4,
          alignSelf: 'flex-start',
          paddingHorizontal: 8,
          paddingVertical: 2,
          borderRadius: radius.pill,
          backgroundColor: col.soft,
        }}
        accessibilityLabel={`Kategori ${meta.label}`}
      >
        <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: col.solid }} />
        <Txt variant="caption" color={col.ink}>
          {meta.label}
        </Txt>
      </View>
    );
  }
  return (
    <Chip
      label={meta.label}
      icon={meta.icon}
      selected={selected}
      onPress={onPress}
      color={col.solid}
      softColor={col.soft}
      inkColor={col.ink}
    />
  );
}

// ---------------------------------------------------------------------------
// Form

export function Field({
  label,
  error,
  style,
  ...rest
}: TextInputProps & { label?: string; error?: string; style?: StyleProp<ViewStyle> }) {
  const c = useTheme();
  return (
    <View style={[{ gap: 6 }, style]}>
      {label && <Txt variant="label">{label}</Txt>}
      <TextInput
        placeholderTextColor={c.inkMuted}
        {...rest}
        style={{
          minHeight: 48,
          borderWidth: 1.5,
          borderColor: error ? c.danger : c.line,
          borderRadius: radius.md,
          paddingHorizontal: 14,
          paddingVertical: rest.multiline ? 12 : 0,
          backgroundColor: c.surface,
          color: c.ink,
          fontFamily: fonts.body,
          fontSize: 15,
          textAlignVertical: rest.multiline ? 'top' : 'center',
        }}
        accessibilityLabel={label}
      />
      {error && (
        <Txt variant="caption" color={c.danger}>
          {error}
        </Txt>
      )}
    </View>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  const c = useTheme();
  return (
    <View
      style={{
        flexDirection: 'row',
        borderWidth: 1.5,
        borderColor: c.line,
        borderRadius: radius.pill,
        padding: 3,
        backgroundColor: c.surface,
      }}
      accessibilityRole="tablist"
    >
      {options.map((o) => {
        const active = o.value === value;
        return (
          <Pressable
            key={o.value}
            onPress={() => onChange(o.value)}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            style={{
              flex: 1,
              minHeight: 36,
              borderRadius: radius.pill,
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: active ? c.ink : 'transparent',
            }}
          >
            <Txt variant="label" color={active ? c.bg : c.ink}>
              {o.label}
            </Txt>
          </Pressable>
        );
      })}
    </View>
  );
}

export function ListRow({
  icon,
  label,
  value,
  onPress,
  danger,
  right,
}: {
  icon?: IconName;
  label: string;
  value?: string;
  onPress?: () => void;
  danger?: boolean;
  right?: ReactNode;
}) {
  const c = useTheme();
  const color = danger ? c.danger : c.ink;
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        minHeight: 52,
        paddingHorizontal: 14,
        backgroundColor: pressed ? c.surfaceAlt : 'transparent',
      })}
    >
      {icon && <Feather name={icon} size={19} color={color} />}
      <Txt variant="subtitle" color={color} style={{ flex: 1, fontSize: 15 }}>
        {label}
      </Txt>
      {value && <Txt muted>{value}</Txt>}
      {right}
      {onPress && !right && <Feather name="chevron-right" size={18} color={c.inkMuted} />}
    </Pressable>
  );
}

export function SectionTitle({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
      <Txt variant="label" muted style={{ textTransform: 'uppercase', letterSpacing: 1 }}>
        {children}
      </Txt>
      {right}
    </View>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: IconName;
  title: string;
  body: string;
  action?: { label: string; onPress: () => void };
}) {
  const c = useTheme();
  return (
    <View style={{ alignItems: 'center', paddingVertical: 36, paddingHorizontal: 24, gap: 10 }}>
      <View
        style={{
          width: 72,
          height: 72,
          borderRadius: 24,
          backgroundColor: c.primarySoft,
          borderWidth: 1.5,
          borderColor: c.line,
          alignItems: 'center',
          justifyContent: 'center',
          transform: [{ rotate: '-6deg' }],
        }}
      >
        <Feather name={icon} size={30} color={c.primary} />
      </View>
      <Txt variant="title" style={{ textAlign: 'center', marginTop: 6 }}>
        {title}
      </Txt>
      <Txt muted style={{ textAlign: 'center' }}>
        {body}
      </Txt>
      {action && <Button label={action.label} onPress={action.onPress} small kind="secondary" style={{ marginTop: 6 }} />}
    </View>
  );
}

export function PressableScale(props: PressableProps & { children: ReactNode }) {
  return <Pressable {...props} style={({ pressed }) => [{ opacity: pressed ? 0.7 : 1 }, props.style as ViewStyle]} />;
}
