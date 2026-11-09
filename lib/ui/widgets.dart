import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/categories.dart';
import '../core/models.dart';
import 'theme.dart';

/// Kartu dengan garis tegas dan bayangan keras kecil (offset tanpa blur).
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
    this.offset = 3,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets padding;
  final double radius;
  final double offset;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final body = Container(
      margin: EdgeInsets.only(right: offset, bottom: offset),
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.line, width: 1.5),
        boxShadow: offset > 0 ? [BoxShadow(color: c.shadow, offset: Offset(offset, offset))] : null,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: body),
    );
  }
}

enum KButtonKind { primary, secondary, ghost, danger }

class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = KButtonKind.primary,
    this.icon,
    this.small = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final KButtonKind kind;
  final IconData? icon;
  final bool small;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final enabled = onPressed != null;
    final bg = switch (kind) {
      KButtonKind.primary => c.primary,
      KButtonKind.secondary => c.surface,
      KButtonKind.ghost => Colors.transparent,
      KButtonKind.danger => c.danger,
    };
    final fg = switch (kind) {
      KButtonKind.primary => c.onPrimary,
      KButtonKind.secondary => c.ink,
      KButtonKind.ghost => c.primary,
      KButtonKind.danger => Colors.white,
    };
    final bordered = kind != KButtonKind.ghost;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: small ? 16 : 18, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: (small ? KText.label : KText.subtitle).copyWith(color: fg)),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: _Pressable(
          onTap: onPressed,
          builder: (pressed) => Container(
            margin: EdgeInsets.only(right: bordered ? 3 : 0, bottom: bordered ? 3 : 0),
            transform: pressed && bordered ? Matrix4.translationValues(2, 2, 0) : null,
            constraints: BoxConstraints(minHeight: small ? 38 : 50),
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: bordered ? Border.all(color: c.line, width: 1.5) : null,
              boxShadow: bordered && enabled && !pressed ? [BoxShadow(color: c.shadow, offset: const Offset(3, 3))] : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.builder});
  final VoidCallback? onTap;
  final Widget Function(bool pressed) builder;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: widget.builder(_pressed),
      );
}

class KChip extends StatelessWidget {
  const KChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.color,
    this.softColor,
    this.inkColor,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final Color? softColor;
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final bg = selected ? (color ?? c.primary) : (softColor ?? c.surface);
    final fg = selected ? (color != null ? const Color(0xFF1F1B16) : c.onPrimary) : (inkColor ?? c.ink);
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected || softColor == null ? c.line : Colors.transparent, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
        Text(label, style: KText.label.copyWith(color: fg)),
      ]),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: chip),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.id, this.selected = false, this.onTap, this.small = false});
  final CategoryId id;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final col = context.k.cat(id);
    if (small) {
      return Semantics(
        label: 'Kategori ${categoryLabel[id]}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: col.soft, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: col.solid, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(categoryLabel[id]!, style: KText.caption.copyWith(color: col.ink)),
          ]),
        ),
      );
    }
    return KChip(
      label: categoryLabel[id]!,
      icon: categoryIcon[id],
      selected: selected,
      onTap: onTap,
      color: col.solid,
      softColor: col.soft,
      inkColor: col.ink,
    );
  }
}

class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: Semantics(
              selected: v == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(v),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? c.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label, style: KText.label.copyWith(color: v == value ? c.bg : c.ink)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 40, this.onTap});
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final app = context.watch<AppState>();
    final name = app.prefs.nickname.trim();
    final attention = !app.prefs.notificationsEnabled && onTap != null;
    return Semantics(
      button: onTap != null,
      label: attention ? 'Profil, ada yang perlu dicek' : 'Profil',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.cat(CategoryId.organisasi).solid,
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Text(name.isEmpty ? 'K' : name[0].toUpperCase(),
                style: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w800, fontSize: size * 0.45, color: const Color(0xFF1F1B16))),
          ),
          if (attention)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Header bersama tiga tab: judul kiri, aksi, Cari, avatar profil.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: KText.display))),
        ...actions,
        IconButton(
          tooltip: 'Cari jadwal',
          icon: const Icon(Icons.search_rounded, size: 26),
          onPressed: () => Navigator.pushNamed(context, '/cari'),
        ),
        const SizedBox(width: 4),
        Avatar(onTap: () => Navigator.pushNamed(context, '/profil')),
      ]),
    );
  }
}

/// Header layar dalam (tanpa tab bar) dengan tombol kembali.
class StackHeader extends StatelessWidget {
  const StackHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(children: [
          IconButton(tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
          Expanded(child: Semantics(header: true, child: Text(title, style: KText.title, overflow: TextOverflow.ellipsis))),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(children: [
        Transform.rotate(
          angle: -0.1,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Icon(icon, size: 32, color: c.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: KText.title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body, style: KText.body.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: 14),
          KButton(label: actionLabel!, onPressed: onAction, kind: KButtonKind.secondary, small: true, expand: false),
        ],
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: KText.label.copyWith(color: color ?? context.k.inkMuted, letterSpacing: 1));
}

class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.label, this.icon, this.value, this.onTap, this.danger = false, this.trailing});
  final String label;
  final IconData? icon;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final color = danger ? c.danger : c.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 12)],
            Expanded(child: Text(label, style: KText.subtitle.copyWith(color: color, fontSize: 15))),
            if (value != null) Text(value!, style: KText.body.copyWith(color: c.inkMuted)),
            ?trailing,
            if (onTap != null && trailing == null) Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          ]),
        ),
      ),
    );
  }
}

/// Tombol tambah melayang dengan bayangan keras.
class KFab extends StatelessWidget {
  const KFab({super.key, required this.onPressed, required this.color, required this.label});
  final VoidCallback onPressed;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line, width: 1.5),
            boxShadow: [BoxShadow(color: c.shadow, offset: const Offset(3, 3))],
          ),
          child: const Icon(Icons.add_rounded, size: 28, color: Color(0xFF1F1B16)),
        ),
      ),
    );
  }
}

/// Toast di atas tab bar dengan aksi Urungkan (5 detik).
void showToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 5),
    persist: false,
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

/// Kolom isian berlabel.
class KField extends StatelessWidget {
  const KField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.maxLength,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final int? maxLength;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    OutlineInputBorder border(Color color, [double w = 1.5]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: w));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: KText.label.copyWith(color: c.ink)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 3 : 1,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        style: KText.body.copyWith(color: c.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: KText.body.copyWith(color: c.inkMuted),
          errorText: error,
          counterText: '',
          filled: true,
          fillColor: c.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: border(c.line),
          focusedBorder: border(c.primary, 2),
          errorBorder: border(c.danger),
          focusedErrorBorder: border(c.danger, 2),
        ),
      ),
    ]);
  }
}
