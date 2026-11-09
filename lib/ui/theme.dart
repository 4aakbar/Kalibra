import 'package:flutter/material.dart';

import '../core/models.dart';

/// Warna kategori: solid (titik/aksen), soft (latar), ink (teks di atas soft).
class CatColor {
  final Color solid;
  final Color soft;
  final Color ink;
  const CatColor(this.solid, this.soft, this.ink);
}

/// Design token Kalibra. Arah visual: kertas krem hangat + indigo brand, aksen
/// kategori cerah, garis tegas dan bayangan keras kecil (editorial). Dark mode
/// memakai arang hangat, teks krem, dan indigo yang dicerahkan (bukan hitam + ungu).
class KColors extends ThemeExtension<KColors> {
  final bool dark;
  final Color bg, surface, surfaceAlt, ink, inkSoft, inkMuted, line, shadow, primary, primarySoft, onPrimary, accent;
  final Color danger, dangerSoft, success, successSoft, warning, warningSoft, gridLine;
  final Map<CategoryId, CatColor> category;

  const KColors({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.line,
    required this.shadow,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.gridLine,
    required this.category,
  });

  static const light = KColors(
    dark: false,
    bg: Color(0xFFFFF9F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFF1DE),
    ink: Color(0xFF1F1B16),
    inkSoft: Color(0xFF4A4239),
    inkMuted: Color(0xFF7D7366),
    line: Color(0xFF1F1B16),
    shadow: Color(0xFF1F1B16),
    primary: Color(0xFF3B2BD0),
    primarySoft: Color(0xFFE7E3FF),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF9B6BFF),
    danger: Color(0xFFD93B2B),
    dangerSoft: Color(0xFFFFE3DE),
    success: Color(0xFF17855A),
    successSoft: Color(0xFFDDF5E9),
    warning: Color(0xFF9A6A00),
    warningSoft: Color(0xFFFFF0C2),
    gridLine: Color(0xFFEADFCF),
    category: {
      CategoryId.kuliah: CatColor(Color(0xFF2E8FE0), Color(0xFFDCEEFF), Color(0xFF0B4C86)),
      CategoryId.tugas: CatColor(Color(0xFFFF6B57), Color(0xFFFFE4DF), Color(0xFF9A2617)),
      CategoryId.organisasi: CatColor(Color(0xFFF5B700), Color(0xFFFFF2C7), Color(0xFF7A5800)),
      CategoryId.magang: CatColor(Color(0xFF1FB27E), Color(0xFFD9F6EA), Color(0xFF0B6A47)),
      CategoryId.pribadi: CatColor(Color(0xFF9B6BFF), Color(0xFFEEE6FF), Color(0xFF5222C2)),
    },
  );

  static const darkTheme = KColors(
    dark: true,
    bg: Color(0xFF1F1C19),
    surface: Color(0xFF2A2622),
    surfaceAlt: Color(0xFF35302A),
    ink: Color(0xFFFFF4E3),
    inkSoft: Color(0xFFE5D9C6),
    inkMuted: Color(0xFFB3A794),
    line: Color(0xFF5A5147),
    shadow: Color(0x80000000),
    primary: Color(0xFF7A6DFF),
    primarySoft: Color(0xFF3A3466),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB79BFF),
    danger: Color(0xFFFF7A6B),
    dangerSoft: Color(0xFF4A2A25),
    success: Color(0xFF5BD6A0),
    successSoft: Color(0xFF1F3D30),
    warning: Color(0xFFF5C84B),
    warningSoft: Color(0xFF43381C),
    gridLine: Color(0xFF3A342E),
    category: {
      CategoryId.kuliah: CatColor(Color(0xFF5AB0F5), Color(0xFF1E3448), Color(0xFFB9DEFF)),
      CategoryId.tugas: CatColor(Color(0xFFFF8C7A), Color(0xFF4A2A25), Color(0xFFFFD0C7)),
      CategoryId.organisasi: CatColor(Color(0xFFF7C83A), Color(0xFF43381C), Color(0xFFFFE9A6)),
      CategoryId.magang: CatColor(Color(0xFF4FD1A0), Color(0xFF1F3D30), Color(0xFFB8F2DA)),
      CategoryId.pribadi: CatColor(Color(0xFFB79BFF), Color(0xFF362C55), Color(0xFFE2D6FF)),
    },
  );

  CatColor cat(CategoryId id) => category[id]!;

  @override
  KColors copyWith() => this;

  @override
  KColors lerp(ThemeExtension<KColors>? other, double t) => t < 0.5 ? this : (other as KColors? ?? this);
}

extension KContext on BuildContext {
  KColors get k => Theme.of(this).extension<KColors>()!;
}

const fontDisplay = 'BricolageGrotesque';
const fontBody = 'PlusJakartaSans';

/// Gaya teks Kalibra.
class KText {
  static const hero = TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w800, fontSize: 38, height: 1.1, letterSpacing: -1);
  static const display = TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, fontSize: 30, height: 1.15, letterSpacing: -0.6);
  static const title = TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, fontSize: 20, height: 1.25, letterSpacing: -0.2);
  static const subtitle = TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w600, fontSize: 16, height: 1.35);
  static const body = TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w400, fontSize: 15, height: 1.45);
  static const label = TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35);
  static const caption = TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w500, fontSize: 12, height: 1.3);
}

ThemeData buildTheme(KColors c) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: c.dark ? Brightness.dark : Brightness.light,
    fontFamily: fontBody,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      surface: c.bg,
      onSurface: c.ink,
      error: c.danger,
    ),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: fontBody),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: KText.subtitle.copyWith(color: c.bg, fontSize: 15),
      actionTextColor: c.cat(CategoryId.organisasi).solid,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary),
    dialogTheme: DialogThemeData(backgroundColor: c.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.bg),
  );
}
