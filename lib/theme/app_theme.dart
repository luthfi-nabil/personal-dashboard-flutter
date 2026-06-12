import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color line;
  final Color line2;
  final Color accent;
  final Color pos;
  final Color neg;
  final Color transfer;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.line2,
    required this.accent,
    required this.pos,
    required this.neg,
    required this.transfer,
  });

  @override
  AppColors copyWith({
    Color? bg, Color? surface, Color? surface2,
    Color? ink, Color? ink2, Color? muted,
    Color? line, Color? line2, Color? accent,
    Color? pos, Color? neg, Color? transfer,
  }) =>
      AppColors(
        bg: bg ?? this.bg, surface: surface ?? this.surface, surface2: surface2 ?? this.surface2,
        ink: ink ?? this.ink, ink2: ink2 ?? this.ink2, muted: muted ?? this.muted,
        line: line ?? this.line, line2: line2 ?? this.line2, accent: accent ?? this.accent,
        pos: pos ?? this.pos, neg: neg ?? this.neg, transfer: transfer ?? this.transfer,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      pos: Color.lerp(pos, other.pos, t)!,
      neg: Color.lerp(neg, other.neg, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

// ── Color tokens ───────────────────────────────────────────────────────────
const _inkColors = AppColors(
  bg:       Color(0xFFF4F1EA),
  surface:  Color(0xFFFBF8F1),
  surface2: Color(0xFFFFFFFF),
  ink:      Color(0xFF1A1A1A),
  ink2:     Color(0xFF3A382F),
  muted:    Color(0xFF6B6857),
  line:     Color(0x14000000),
  line2:    Color(0x0D000000),
  accent:   Color(0xFF1D4ED8),
  pos:      Color(0xFF1F8A4C),
  neg:      Color(0xFFC43A2B),
  transfer: Color(0xFF7C3AED),
);

const _warmColors = AppColors(
  bg:       Color(0xFFF5EDE0),
  surface:  Color(0xFFFBF3E3),
  surface2: Color(0xFFFFFFFF),
  ink:      Color(0xFF1A1A1A),
  ink2:     Color(0xFF3A382F),
  muted:    Color(0xFF6B6857),
  line:     Color(0x14000000),
  line2:    Color(0x0D000000),
  accent:   Color(0xFFC2410C),
  pos:      Color(0xFF1F8A4C),
  neg:      Color(0xFFC43A2B),
  transfer: Color(0xFF7C3AED),
);

const _darkColors = AppColors(
  bg:       Color(0xFF0E0E10),
  surface:  Color(0xFF17171B),
  surface2: Color(0xFF1F1F24),
  ink:      Color(0xFFF4F1EA),
  ink2:     Color(0xFFD4D0C4),
  muted:    Color(0xFF8A8678),
  line:     Color(0x14FFFFFF),
  line2:    Color(0x0DFFFFFF),
  accent:   Color(0xFF7AA7FF),
  pos:      Color(0xFF1F8A4C),
  neg:      Color(0xFFC43A2B),
  transfer: Color(0xFF7C3AED),
);

// ── ThemeData builders ─────────────────────────────────────────────────────
ThemeData _buildTheme(AppColors c) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    colorScheme: ColorScheme(
      brightness: c.bg == const Color(0xFF0E0E10) ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.bg,
      secondary: c.accent,
      onSecondary: c.bg,
      error: c.neg,
      onError: c.bg,
      surface: c.surface,
      onSurface: c.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w600, fontSize: 16),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: c.surface),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.ink,
      foregroundColor: c.bg,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: c.muted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dividerColor: c.line,
    cardColor: c.surface,
  );
}

class AppTheme {
  static ThemeData get(String theme) => switch (theme) {
        'warm' => _buildTheme(_warmColors),
        'dark' => _buildTheme(_darkColors),
        _      => _buildTheme(_inkColors),
      };

  static AppColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;
}
