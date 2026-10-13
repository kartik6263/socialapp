import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useRef, type ComponentProps, type ReactNode } from 'react';
import {
  ActivityIndicator, Animated, Image, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
  type StyleProp, type TextInputProps, type TextProps, type TextStyle, type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { PlanStatus, UserSummary } from '@/api/types';
import { initials, toneFor } from '@/lib/format';
import { avatarTones, brandGradient, colors, fonts, glass, pills, placeholder, radius, type AvatarTone, type PillTone } from '@/theme';
import { Backdrop } from './glass';
import { Appear, useFocusRing, usePressScale, useReducedMotion } from './motion';
import { tr, useLanguage } from '@/i18n';

export type IconName = ComponentProps<typeof Feather>['name'];

export function Icon({ name, size = 20, color = colors.ink }: { name: IconName; size?: number; color?: string }) {
  useLanguage();
  return <Feather name={name} size={size} color={color} />;
}

// ---------- Typography ----------

type Variant = 'display' | 'title' | 'heading' | 'body' | 'bodyStrong' | 'small' | 'kicker' | 'caption' | 'section';

const textStyles: Record<Variant, TextStyle> = {
  display: { fontFamily: fonts.display, fontSize: 32, lineHeight: 36, letterSpacing: -1.2, color: colors.ink },
  title: { fontFamily: fonts.display, fontSize: 24, lineHeight: 29, letterSpacing: -0.7, color: colors.ink },
  heading: { fontFamily: fonts.display, fontSize: 18, lineHeight: 23, letterSpacing: -0.4, color: colors.ink },
  body: { fontFamily: fonts.body, fontSize: 14, lineHeight: 21, color: colors.inkSoft },
  bodyStrong: { fontFamily: fonts.bodyBold, fontSize: 14, lineHeight: 19, color: colors.ink },
  small: { fontFamily: fonts.body, fontSize: 12, lineHeight: 17, color: colors.inkSoft },
  kicker: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1.3, color: colors.brand },
  caption: { fontFamily: fonts.bodyMedium, fontSize: 11, lineHeight: 15, color: colors.inkSoft },
  section: { fontFamily: fonts.bodyBold, fontSize: 11, letterSpacing: 1.2, color: colors.brand, marginTop: 22, marginBottom: 8 },
};

export function T({ variant = 'body', style, ...rest }: TextProps & { variant?: Variant }) {
  useLanguage();
  return <Text {...rest} style={[textStyles[variant], style]} />;
}

/** Headline with an accent-coloured trailing phrase: "Discover who else is *doing it.*" */
export function Headline({ text, accent, size = 'display' }: { text: string; accent?: string; size?: 'display' | 'title' }) {
  useLanguage();
  return (
    <T variant={size} accessibilityRole="header">
      {text}
      {accent ? <Text style={{ color: colors.brand }}>{accent}</Text> : null}
    </T>
  );
}

// ---------- Buttons ----------

type ButtonKind = 'primary' | 'secondary' | 'text' | 'danger' | 'dangerSolid' | 'ink';

export function Button({
  label, onPress, kind = 'primary', icon, iconRight, disabled, loading, style, compact, accessibilityLabel, accessibilityHint,
}: {
  label: string;
  onPress?: () => void;
  kind?: ButtonKind;
  icon?: IconName;
  iconRight?: IconName;
  disabled?: boolean;
  loading?: boolean;
  style?: StyleProp<ViewStyle>;
  compact?: boolean;
  accessibilityLabel?: string;
  accessibilityHint?: string;
}) {
  useLanguage();
  const press = usePressScale(0.97);
  const focus = useFocusRing();
  const fg = kind === 'primary' || kind === 'dangerSolid' || kind === 'ink' ? '#fff' : kind === 'danger' ? colors.danger : kind === 'text' ? colors.brand : colors.ink;
  const bg = {
    primary: colors.brand, secondary: glass.fillStrong, text: 'transparent', danger: glass.fillStrong, dangerSolid: colors.danger, ink: colors.ink,
  }[kind];
  const off = !!disabled || !!loading;
  // Flex/margins from `style` belong on the outer Pressable so layouts like "two buttons side by side" keep working.
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: off, busy: !!loading }}
      onPress={onPress}
      disabled={off}
      onPressIn={press.onPressIn}
      onPressOut={press.onPressOut}
      {...focus.handlers}
      style={style}
    >
      <Animated.View
        style={[
          styles.button,
          compact && styles.buttonCompact,
          { backgroundColor: bg },
          (kind === 'secondary' || kind === 'danger') && { borderWidth: 1, borderColor: kind === 'danger' ? '#e6b3b3' : glass.border, ...glass.shadow, shadowOpacity: 0.06 },
          kind === 'primary' && styles.primaryShadow,
          kind === 'text' && { paddingHorizontal: 4, minHeight: 44 },
          off && { opacity: 0.45 },
          focus.ring,
          press.style,
        ]}
      >
        {kind === 'primary' ? (
          <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} style={[StyleSheet.absoluteFill, { borderRadius: compact ? 11 : radius.md }]} />
        ) : null}
        {loading ? <ActivityIndicator color={fg} size="small" /> : icon ? <Icon name={icon} size={15} color={fg} /> : null}
        <Text style={[styles.buttonText, { color: fg }, compact && { fontSize: 12 }]}>{label}</Text>
        {iconRight && !loading ? <Icon name={iconRight} size={15} color={fg} /> : null}
      </Animated.View>
    </Pressable>
  );
}

export function IconButton({ name, onPress, label, color, badge, filled }: { name: IconName; onPress?: () => void; label: string; color?: string; badge?: string | null; filled?: boolean }) {
  useLanguage();
  const press = usePressScale(0.9);
  const focus = useFocusRing();
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      onPress={onPress}
      onPressIn={press.onPressIn}
      onPressOut={press.onPressOut}
      {...focus.handlers}
      hitSlop={6}
    >
      {({ pressed }) => (
        <Animated.View style={[styles.iconButton, filled && styles.iconButtonFilled, pressed && { backgroundColor: glass.pressed }, focus.ring, press.style]}>
          <Icon name={name} size={19} color={color} />
          {badge ? (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{badge}</Text>
            </View>
          ) : null}
        </Animated.View>
      )}
    </Pressable>
  );
}

// ---------- Pills, chips, tabs ----------

export function Pill({ label, tone = 'neutral', icon, onPress, accessibilityLabel }: { label: string; tone?: PillTone; icon?: IconName; onPress?: () => void; accessibilityLabel?: string }) {
  useLanguage();
  const p = pills[tone];
  const body = (
    <View style={[styles.pill, { backgroundColor: p.bg }]}>
      {icon ? <Icon name={icon} size={11} color={p.fg} /> : null}
      <Text style={[styles.pillText, { color: p.fg }]}>{label}</Text>
    </View>
  );
  if (!onPress) return body;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={accessibilityLabel ?? label} hitSlop={4}>
      {body}
    </Pressable>
  );
}

export function Chip({ label, selected, onPress }: { label: string; selected?: boolean; onPress?: () => void }) {
  useLanguage();
  const press = usePressScale(0.95);
  const focus = useFocusRing();
  const body = (
    <Animated.View style={[styles.chip, selected && { backgroundColor: colors.brandPale, borderColor: colors.brand }, focus.ring, press.style]}>
      {selected ? <Icon name="check" size={13} color={colors.brand} /> : null}
      <Text style={[styles.chipText, selected && { color: colors.brand }]}>{label}</Text>
    </Animated.View>
  );
  // A chip without an action is a label, not a button: don't announce it as tappable.
  if (!onPress) return <View accessible accessibilityLabel={label}>{body}</View>;
  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ checked: !!selected }}
      accessibilityLabel={label}
      onPress={onPress}
      onPressIn={press.onPressIn}
      onPressOut={press.onPressOut}
      {...focus.handlers}
    >
      {body}
    </Pressable>
  );
}

export function SegmentTabs<K extends string>({ tabs, value, onChange }: { tabs: { key: K; label: string; count?: number }[]; value: K; onChange: (k: K) => void }) {
  useLanguage();
  return (
    <View style={styles.tabs} accessibilityRole="tablist">
      {tabs.map((t) => {
        const on = t.key === value;
        return (
          <Pressable key={t.key} onPress={() => onChange(t.key)} accessibilityRole="tab" accessibilityState={{ selected: on }} style={[styles.tab, on && { borderBottomColor: colors.brand }]}>
            <Text style={[styles.tabText, on && { color: colors.brand }]}>{t.label}</Text>
            {t.count ? <View style={styles.tabCount}><Text style={styles.tabCountText}>{t.count}</Text></View> : null}
          </Pressable>
        );
      })}
    </View>
  );
}

export function FilterPills<K extends string>({ options, value, onChange }: { options: { key: K; label: string }[]; value: K; onChange: (k: K) => void }) {
  useLanguage();
  return (
    <View style={{ flexDirection: 'row', gap: 8 }} accessibilityRole="tablist">
      {options.map((o) => {
        const on = o.key === value;
        return (
          <Pressable key={o.key} onPress={() => onChange(o.key)} accessibilityRole="tab" accessibilityState={{ selected: on }} style={[styles.filterPill, on && { backgroundColor: colors.ink, borderColor: colors.ink }]}>
            <Text style={[styles.chipText, on && { color: '#fff' }]}>{o.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function PlanStatusPill({ status }: { status: PlanStatus }) {
  useLanguage();
  const map: Record<PlanStatus, [string, PillTone]> = {
    DRAFT: [tr('Draft'), 'neutral'],
    ACTIVE: [tr('Active'), 'ok'],
    FULL: [tr('Full'), 'warn'],
    UPDATED: [tr('Updated'), 'blue'],
    CANCELLED: [tr('Cancelled'), 'bad'],
    COMPLETED: [tr('Completed'), 'neutral'],
  };
  const [label, tone] = map[status];
  return <Pill label={label} tone={tone} />;
}

// ---------- Avatars ----------

export function Avatar({ name, photoUrl, id = 0, size = 40, tone }: { name: string; photoUrl?: string | null; id?: number; size?: number; tone?: AvatarTone }) {
  useLanguage();
  const t = avatarTones[tone ?? toneFor(id)];
  return (
    <View style={[styles.avatar, { width: size, height: size, borderRadius: size / 2, backgroundColor: t.bg }]} accessibilityElementsHidden importantForAccessibility="no">
      {photoUrl ? (
        <Image source={{ uri: photoUrl }} style={{ width: size, height: size, borderRadius: size / 2 }} />
      ) : (
        <Text style={{ fontFamily: fonts.bodyBold, fontSize: Math.max(10, size * 0.3), color: t.fg }}>{initials(name)}</Text>
      )}
    </View>
  );
}

export function UserAvatar({ user, size = 40 }: { user: Pick<UserSummary, 'id' | 'displayName' | 'photoUrl'>; size?: number }) {
  useLanguage();
  return <Avatar name={user.displayName} photoUrl={user.photoUrl} id={user.id} size={size} />;
}

// ---------- Layout ----------

/** Every screen sits on the aurora backdrop; content eases in once on arrival. */
export function Screen({
  children, scroll = true, padded = true, refreshControl, edges = ['top'], footer, scrollRef, bg,
}: {
  children: ReactNode;
  scroll?: boolean;
  padded?: boolean;
  refreshControl?: ComponentProps<typeof ScrollView>['refreshControl'];
  edges?: ('top' | 'bottom')[];
  footer?: ReactNode;
  scrollRef?: React.Ref<ScrollView>;
  /** Solid colour instead of the aurora (rarely needed). */
  bg?: string;
}) {
  useLanguage();
  return (
    <View style={{ flex: 1, backgroundColor: bg ?? colors.paper }}>
      {bg ? null : <Backdrop />}
      <SafeAreaView style={{ flex: 1 }} edges={edges}>
        {scroll ? (
          <ScrollView
            ref={scrollRef}
            contentContainerStyle={[padded && { paddingHorizontal: 16 }, { paddingBottom: 40 }]}
            keyboardShouldPersistTaps="handled"
            refreshControl={refreshControl}
          >
            <Appear>{children}</Appear>
          </ScrollView>
        ) : (
          <Appear style={[{ flex: 1 }, padded && { paddingHorizontal: 16 }]}>{children}</Appear>
        )}
        {footer}
      </SafeAreaView>
    </View>
  );
}

export function goBack() {
  if (router.canGoBack()) router.back();
  else router.replace('/');
}

/** Screen header: back button + kicker/title, optional right action. */
export function Header({ title, kicker, right, onBack, center = false, large = true, hideBack = false }: {
  title?: string; kicker?: string; right?: ReactNode; onBack?: () => void; center?: boolean; large?: boolean;
  /** For the first step of a flow with nowhere to go back to: no button, rather than one that does nothing. */
  hideBack?: boolean;
}) {
  useLanguage();
  return (
    <View style={styles.header}>
      {hideBack ? <View style={{ width: 8 }} /> : <IconButton name="chevron-left" label={tr('Back')} onPress={onBack ?? goBack} filled />}
      <View style={{ flex: 1, alignItems: center ? 'center' : 'flex-start', paddingHorizontal: 4 }}>
        {kicker ? <T variant="kicker" numberOfLines={1}>{kicker}</T> : null}
        {title ? (
          <T variant={large && !center ? 'title' : 'bodyStrong'} style={large && !center ? { fontSize: 22, lineHeight: 26 } : { fontSize: 15 }} numberOfLines={1} accessibilityRole="header">
            {title}
          </T>
        ) : null}
      </View>
      <View style={{ minWidth: 40, alignItems: 'flex-end' }}>{right}</View>
    </View>
  );
}

export function Card({ children, style, onPress, accessibilityLabel }: { children: ReactNode; style?: StyleProp<ViewStyle>; onPress?: () => void; accessibilityLabel?: string }) {
  useLanguage();
  const press = usePressScale(0.985);
  const focus = useFocusRing();
  if (onPress) {
    return (
      <Pressable onPress={onPress} onPressIn={press.onPressIn} onPressOut={press.onPressOut} {...focus.handlers} accessibilityRole="button" accessibilityLabel={accessibilityLabel}>
        <Animated.View style={[styles.card, style, focus.ring, press.style]}>{children}</Animated.View>
      </Pressable>
    );
  }
  return <View style={[styles.card, style]}>{children}</View>;
}

export function SectionTitle({ title, danger }: { title: string; danger?: boolean }) {
  useLanguage();
  return <T variant="section" style={danger ? { color: colors.danger } : null}>{title.toUpperCase()}</T>;
}

/** A bordered group of rows (settings, safety tools…). */
export function Group({ children, danger, style }: { children: ReactNode; danger?: boolean; style?: StyleProp<ViewStyle> }) {
  useLanguage();
  return <View style={[styles.group, danger && { borderColor: '#efc9c9' }, style]}>{children}</View>;
}

export function IconTile({ name, tone = 'ok', size = 38 }: { name: IconName; tone?: PillTone; size?: number }) {
  useLanguage();
  const p = pills[tone];
  return (
    <View style={{ width: size, height: size, borderRadius: size * 0.32, backgroundColor: p.bg, alignItems: 'center', justifyContent: 'center' }}>
      <Icon name={name} size={size * 0.48} color={p.fg} />
    </View>
  );
}

/** Row inside a Group: icon tile, label/sub, value or toggle, chevron. */
export function Row({
  icon, label, sub, value, onPress, first, danger, tag, tagTone = 'warn', right, accessibilityLabel,
}: {
  icon?: IconName; label: string; sub?: string | null; value?: string | null; onPress?: () => void; first?: boolean;
  danger?: boolean; tag?: string; tagTone?: PillTone; right?: ReactNode; accessibilityLabel?: string;
}) {
  useLanguage();
  const content = (
    <>
      {icon ? <IconTile name={icon} tone={danger ? 'bad' : 'ok'} /> : null}
      <View style={{ flex: 1, gap: 2 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
          <Text style={[styles.rowLabel, danger && { color: colors.danger }]}>{label}</Text>
          {tag ? <Pill label={tag} tone={tagTone} /> : null}
        </View>
        {sub ? <Text style={styles.rowSub}>{sub}</Text> : null}
      </View>
      {right ?? (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, maxWidth: '45%' }}>
          {value ? <Text style={styles.rowValue} numberOfLines={1}>{value}</Text> : null}
          {onPress ? <Icon name="chevron-right" size={16} color={colors.inkSoft} /> : null}
        </View>
      )}
    </>
  );
  const style = [styles.row, !first && { borderTopWidth: 1, borderTopColor: colors.divider }];
  const a11y = accessibilityLabel ?? [label, sub, value, tag].filter(Boolean).join(', ');
  if (!onPress) return <View style={style} accessible accessibilityLabel={a11y}>{content}</View>;
  return <PressRow style={style} onPress={onPress} label={a11y}>{content}</PressRow>;
}

function PressRow({ style, onPress, label, children }: { style: StyleProp<ViewStyle>; onPress: () => void; label: string; children: ReactNode }) {
  const focus = useFocusRing();
  return (
    <Pressable onPress={onPress} {...focus.handlers} accessibilityRole="button" accessibilityLabel={label}
      style={({ pressed }) => [style, pressed && { backgroundColor: glass.pressed }, focus.ring]}>
      {children}
    </Pressable>
  );
}

export function Switch({ value, onChange, label, disabled }: { value: boolean; onChange: (v: boolean) => void; label: string; disabled?: boolean }) {
  useLanguage();
  const still = useReducedMotion();
  const focus = useFocusRing();
  const x = useRef(new Animated.Value(value ? 1 : 0)).current;
  useEffect(() => {
    if (still) x.setValue(value ? 1 : 0);
    else Animated.spring(x, { toValue: value ? 1 : 0, useNativeDriver: false, speed: 22, bounciness: 7 }).start();
  }, [value, still, x]);
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityLabel={label}
      accessibilityState={{ checked: value, disabled: !!disabled }}
      disabled={disabled}
      onPress={() => onChange(!value)}
      {...focus.handlers}
      hitSlop={8}
    >
      <Animated.View style={[styles.switch, { backgroundColor: x.interpolate({ inputRange: [0, 1], outputRange: [colors.track, colors.brand] }) }, disabled && { opacity: 0.45 }, focus.ring]}>
        <Animated.View style={[styles.knob, { transform: [{ translateX: x.interpolate({ inputRange: [0, 1], outputRange: [0, 20] }) }] }]}>
          {value ? <Icon name="check" size={12} color={colors.brand} /> : null}
        </Animated.View>
      </Animated.View>
    </Pressable>
  );
}

export function ToggleRow({ icon, label, sub, value, onChange, first, tag, disabled }: {
  icon?: IconName; label: string; sub?: string; value: boolean; onChange: (v: boolean) => void; first?: boolean; tag?: string; disabled?: boolean;
}) {
  useLanguage();
  return <Row icon={icon} label={label} sub={sub} first={first} tag={tag} right={<Switch value={value} onChange={onChange} label={label} disabled={disabled} />} />;
}

/** Radio card list (choice screens, report reasons, wizard options). */
export function RadioGroup<V extends string>({ options, value, onChange, label }: {
  options: { value: V; label: string; sub?: string; disabled?: boolean }[]; value: V | null; onChange: (v: V) => void; label: string;
}) {
  useLanguage();
  return (
    <View style={{ gap: 8 }} accessibilityRole="radiogroup" accessibilityLabel={label}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <Pressable
            key={o.value}
            disabled={o.disabled}
            onPress={() => onChange(o.value)}
            accessibilityRole="radio"
            accessibilityState={{ checked: on, disabled: !!o.disabled }}
            style={[styles.radio, on && { borderColor: colors.brand, backgroundColor: colors.brandPale }, o.disabled && { opacity: 0.5 }]}
          >
            <View style={[styles.radioRing, on && { borderColor: colors.brand }]}>{on ? <View style={styles.radioDot} /> : null}</View>
            <View style={{ flex: 1 }}>
              <Text style={styles.rowLabel}>{o.label}</Text>
              {o.sub ? <Text style={styles.rowSub}>{o.sub}</Text> : null}
            </View>
          </Pressable>
        );
      })}
    </View>
  );
}

export function StepBars({ total, current }: { total: number; current: number }) {
  useLanguage();
  return (
    <View style={{ flexDirection: 'row', gap: 6, paddingHorizontal: 16, paddingBottom: 8 }} accessibilityLabel={tr('Step {current} of {total}', { current, total })}>
      {Array.from({ length: total }, (_, i) => (
        <View key={i} style={{ flex: 1, height: 4, borderRadius: 2, backgroundColor: i < current ? colors.brand : colors.line }} />
      ))}
    </View>
  );
}

export function KeyValue({ rows }: { rows: { k: string; v: string }[] }) {
  useLanguage();
  return (
    <Group>
      {rows.map((r, i) => (
        <View key={r.k} style={[styles.kv, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }]}>
          <Text style={styles.rowSub}>{r.k}</Text>
          <Text style={[styles.rowLabel, { flex: 1, textAlign: 'right' }]}>{r.v}</Text>
        </View>
      ))}
    </Group>
  );
}

export function Diff({ changes }: { changes: { label: string; from: string; to: string }[] }) {
  useLanguage();
  return (
    <View style={{ gap: 6 }}>
      {changes.map((d) => (
        <View key={d.label} style={styles.diff}>
          <Text style={styles.diffLabel}>{tr(d.label).toUpperCase()}</Text>
          <Text style={styles.rowSub}>
            <Text style={{ textDecorationLine: 'line-through' }}>{d.from}</Text>
            {'  →  '}
            <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{d.to}</Text>
          </Text>
        </View>
      ))}
    </View>
  );
}

export function Banner({ icon, title, body, tone = 'ok', action, onAction }: {
  icon: IconName; title: string; body?: string; tone?: PillTone; action?: string; onAction?: () => void;
}) {
  useLanguage();
  const p = pills[tone];
  return (
    <View style={[styles.banner, { backgroundColor: tone === 'warn' ? '#fff8e6' : p.bg, borderColor: tone === 'warn' ? '#f0dca6' : 'transparent' }]} accessibilityRole={tone === 'bad' || tone === 'warn' ? 'alert' : undefined}>
      <Icon name={icon} size={17} color={p.fg} />
      <View style={{ flex: 1 }}>
        <Text style={{ fontFamily: fonts.bodyBold, color: tone === 'ok' ? colors.ink : p.fg, fontSize: 13 }}>{title}</Text>
        {body ? <Text style={{ fontFamily: fonts.body, color: colors.inkSoft, fontSize: 12, marginTop: 2, lineHeight: 17 }}>{body}</Text> : null}
      </View>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8} accessibilityRole="button">
          <Text style={{ fontFamily: fonts.bodyBold, color: p.fg, fontSize: 12 }}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function Note({ icon = 'lock', children }: { icon?: IconName; children: ReactNode }) {
  useLanguage();
  return (
    <View style={styles.note} accessibilityRole="text">
      <Icon name={icon} size={14} color={colors.brand} />
      <Text style={{ flex: 1, fontFamily: fonts.body, fontSize: 12, lineHeight: 17, color: colors.inkSoft }}>{children}</Text>
    </View>
  );
}

export function EmergencyNote() {
  useLanguage();
  return (
    <Note icon="shield">
      <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{tr('If you are in immediate danger,')}</Text> {tr('contact your local emergency services (112 in India) or someone you trust. Plans isn’t an emergency service.')}
    </Note>
  );
}

// ---------- States ----------

export function Loading({ label }: { label?: string }) {
  useLanguage();
  return (
    <View style={styles.centered} accessibilityLiveRegion="polite">
      <ActivityIndicator color={colors.brand} />
      {label ? <T variant="small" style={{ marginTop: 10 }}>{label}</T> : null}
    </View>
  );
}

export function Skeleton({ rows = 3 }: { rows?: number }) {
  useLanguage();
  return (
    <View style={{ gap: 10, marginTop: 8 }} accessibilityLabel={tr('Loading')}>
      {Array.from({ length: rows }, (_, i) => (
        <View key={i} style={styles.skeleton}>
          <View style={[styles.skelBlock, { width: 38, height: 38, borderRadius: 12 }]} />
          <View style={{ flex: 1, gap: 7 }}>
            <View style={[styles.skelBlock, { width: '55%' }]} />
            <View style={[styles.skelBlock, { width: '85%' }]} />
          </View>
        </View>
      ))}
    </View>
  );
}

export function StateBlock({ icon, title, body, tone = 'ok', actions }: {
  icon: IconName; title: string; body?: string; tone?: PillTone; actions?: { label: string; onPress: () => void; kind?: ButtonKind }[];
}) {
  useLanguage();
  return (
    <View style={styles.state} accessibilityRole="summary">
      <IconTile name={icon} tone={tone} size={56} />
      <T variant="title" style={{ textAlign: 'center', marginTop: 14, fontSize: 22 }} accessibilityRole="header">{title}</T>
      {body ? <T variant="body" style={{ textAlign: 'center', marginTop: 8 }}>{body}</T> : null}
      {actions?.length ? (
        <View style={{ alignSelf: 'stretch', gap: 8, marginTop: 18 }}>
          {actions.map((a) => <Button key={a.label} label={a.label} kind={a.kind ?? 'primary'} onPress={a.onPress} />)}
        </View>
      ) : null}
    </View>
  );
}

export function ErrorBlock({ error, onRetry, title }: { error: { message: string; isNetwork?: boolean }; onRetry: () => void; title?: string }) {
  useLanguage();
  return (
    <StateBlock
      icon={error.isNetwork ? 'wifi-off' : 'refresh-cw'}
      tone="neutral"
      title={error.isNetwork ? tr('You’re offline') : title ?? tr('Couldn’t load this')}
      body={error.isNetwork ? tr('Reconnect and try again.') : error.message}
      actions={[{ label: tr('Retry'), onPress: onRetry }]}
    />
  );
}

// ---------- Forms ----------

export function Field({ label, optional, hint, error, prefix, style, ref, ...input }: TextInputProps & {
  label: string; optional?: boolean; hint?: string; error?: string | null; prefix?: string; ref?: React.Ref<TextInput>;
}) {
  useLanguage();
  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={styles.label}>
        {label}
        {optional ? <Text style={{ fontFamily: fonts.body, color: colors.inkSoft }}> {tr('(optional)')}</Text> : null}
      </Text>
      <View style={[styles.input, error ? { borderColor: colors.danger } : null, input.multiline && { minHeight: 96, alignItems: 'flex-start', paddingTop: 12 }]}>
        {prefix ? <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{prefix}</Text> : null}
        <TextInput
          ref={ref}
          placeholderTextColor={placeholder}
          {...input}
          style={[{ flex: 1, fontFamily: fonts.body, fontSize: 15, color: colors.ink, paddingVertical: 0 }, input.multiline && { textAlignVertical: 'top' }, style]}
          accessibilityLabel={label}
          aria-invalid={!!error}
        />
      </View>
      {error ? <Text style={styles.error} accessibilityRole="alert" accessibilityLiveRegion="polite">{error}</Text> : hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </View>
  );
}

export function Logo({ size = 20 }: { size?: number }) {
  useLanguage();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }} accessibilityLabel={tr('Plans')}>
      <View style={styles.logoMark}>
        <View style={[styles.logoBar, { height: 7 }]} />
        <View style={[styles.logoBar, { height: 13 }]} />
        <View style={[styles.logoBar, { height: 9 }]} />
      </View>
      <Text style={{ fontFamily: fonts.display, fontSize: size, color: colors.ink }}>{tr('Plans')}</Text>
    </View>
  );
}

export function ScrollRow({ children }: { children: ReactNode }) {
  useLanguage();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, paddingHorizontal: 16 }} style={{ marginHorizontal: -16 }}>
      {children}
    </ScrollView>
  );
}

/** Android draws elevation shadows through translucent fills as a grey rim, so glass there relies on its border. */
const glassEdge = { borderWidth: 1, borderColor: glass.border, ...glass.shadow, ...(Platform.OS === 'android' ? { elevation: 0 } : null) };

export const styles = StyleSheet.create({
  button: { minHeight: 48, borderRadius: radius.md, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, overflow: 'visible' },
  buttonCompact: { minHeight: 36, paddingHorizontal: 12, borderRadius: 11 },
  buttonText: { fontFamily: fonts.bodyBold, fontSize: 14 },
  primaryShadow: { shadowColor: '#0c4f40', shadowOpacity: 0.28, shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, elevation: 4 },
  iconButton: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  iconButtonFilled: { backgroundColor: glass.fillStrong, borderWidth: 1, borderColor: glass.border },
  badge: { position: 'absolute', right: -3, top: -2, minWidth: 19, height: 19, paddingHorizontal: 5, borderRadius: 10, borderWidth: 2, borderColor: '#fff', backgroundColor: colors.badge, alignItems: 'center', justifyContent: 'center' },
  badgeText: { color: '#fff', fontSize: 10, fontFamily: fonts.bodyBold },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 4, borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 4, alignSelf: 'flex-start' },
  pillText: { fontFamily: fonts.bodyBold, fontSize: 11 },
  chip: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderColor: glass.border, backgroundColor: glass.fill, borderRadius: radius.pill, paddingHorizontal: 14, paddingVertical: 10, minHeight: 40 },
  chipText: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink },
  filterPill: { borderWidth: 1, borderColor: glass.border, backgroundColor: glass.fill, borderRadius: radius.pill, paddingHorizontal: 14, paddingVertical: 9, minHeight: 40, justifyContent: 'center' },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.line, paddingHorizontal: 12 },
  tab: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: 12, paddingHorizontal: 8, borderBottomWidth: 2, borderBottomColor: 'transparent', marginBottom: -1, minHeight: 44 },
  tabText: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.inkSoft },
  tabCount: { minWidth: 18, height: 18, borderRadius: 9, paddingHorizontal: 5, backgroundColor: colors.brandPale, alignItems: 'center', justifyContent: 'center' },
  tabCountText: { fontFamily: fonts.bodyBold, fontSize: 10, color: colors.brand },
  avatar: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, minHeight: 60, gap: 6 },
  card: { backgroundColor: glass.fill, borderRadius: 22, padding: 16, ...glassEdge },
  group: { backgroundColor: glass.fill, borderRadius: 20, overflow: 'hidden', borderWidth: 1, borderColor: glass.border },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 13, minHeight: 56 },
  rowLabel: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  rowSub: { fontFamily: fonts.body, fontSize: 12, lineHeight: 17, color: colors.inkSoft },
  rowValue: { fontFamily: fonts.bodySemi, fontSize: 12, color: colors.inkSoft },
  switch: { width: 46, height: 26, borderRadius: 13, backgroundColor: colors.track, padding: 3 },
  knob: { width: 20, height: 20, borderRadius: 10, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 2 },
  radio: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderRadius: 18, borderWidth: 1, borderColor: glass.border, backgroundColor: glass.fill },
  radioRing: { width: 20, height: 20, borderRadius: 10, borderWidth: 2, borderColor: colors.inputBorder, alignItems: 'center', justifyContent: 'center' },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.brand },
  kv: { flexDirection: 'row', alignItems: 'flex-start', gap: 12, paddingHorizontal: 14, paddingVertical: 12 },
  diff: { backgroundColor: glass.fillSoft, borderRadius: 12, padding: 10, gap: 3 },
  diffLabel: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: colors.inkSoft },
  banner: { flexDirection: 'row', gap: 10, padding: 13, borderRadius: 18, alignItems: 'center', borderWidth: 1 },
  note: { flexDirection: 'row', gap: 8, padding: 12, borderRadius: 16, backgroundColor: glass.fill, borderWidth: 1, borderColor: glass.border, alignItems: 'flex-start' },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 40 },
  skeleton: { flexDirection: 'row', gap: 12, padding: 14, borderRadius: 20, backgroundColor: glass.fillSoft, borderWidth: 1, borderColor: glass.border, alignItems: 'center' },
  skelBlock: { height: 10, borderRadius: 5, backgroundColor: 'rgba(24,35,33,0.08)' },
  state: { alignItems: 'center', paddingVertical: 36, paddingHorizontal: 8 },
  label: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.ink, marginBottom: 6 },
  input: { flexDirection: 'row', alignItems: 'center', gap: 8, minHeight: 50, borderWidth: 1, borderColor: colors.inputBorder, borderRadius: radius.md, backgroundColor: glass.fillStrong, paddingHorizontal: 14 },
  hint: { fontFamily: fonts.body, fontSize: 11, color: colors.inkSoft, marginTop: 5 },
  error: { fontFamily: fonts.bodySemi, fontSize: 12, color: colors.dangerText, marginTop: 5 },
  logoMark: { width: 28, height: 28, borderRadius: 9, backgroundColor: colors.brand, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'center', gap: 2, paddingBottom: 7, transform: [{ rotate: '-4deg' }] },
  logoBar: { width: 3, borderRadius: 3, backgroundColor: colors.lime },
});
