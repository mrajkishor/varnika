import 'package:flutter/material.dart';

/// Varnika's palette: indigo ink on warm paper, with marigold for action
/// and a calm teal for "protected".
class VColors {
  static const ink = Color(0xFF1E1B4B);
  static const marigold = Color(0xFFE8833A);
  static const teal = Color(0xFF14B8A6);
  static const rose = Color(0xFFE11D48);
  static const paper = Color(0xFFFBF7F0);
  static const night = Color(0xFF0E0D1A);
  static const nightSurface = Color(0xFF181630);
}

/// Semantic colors not covered by [ColorScheme].
@immutable
class VarnikaColors extends ThemeExtension<VarnikaColors> {
  const VarnikaColors({
    required this.protected,
    required this.unprotected,
    required this.download,
    required this.upload,
  });

  final Color protected;
  final Color unprotected;
  final Color download;
  final Color upload;

  @override
  VarnikaColors copyWith({
    Color? protected,
    Color? unprotected,
    Color? download,
    Color? upload,
  }) => VarnikaColors(
    protected: protected ?? this.protected,
    unprotected: unprotected ?? this.unprotected,
    download: download ?? this.download,
    upload: upload ?? this.upload,
  );

  @override
  VarnikaColors lerp(ThemeExtension<VarnikaColors>? other, double t) {
    if (other is! VarnikaColors) return this;
    return VarnikaColors(
      protected: Color.lerp(protected, other.protected, t)!,
      unprotected: Color.lerp(unprotected, other.unprotected, t)!,
      download: Color.lerp(download, other.download, t)!,
      upload: Color.lerp(upload, other.upload, t)!,
    );
  }
}

extension VarnikaTheme on BuildContext {
  VarnikaColors get vc => Theme.of(this).extension<VarnikaColors>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: VColors.ink, brightness: b)
      .copyWith(
        primary: dark ? const Color(0xFFB9B4FF) : VColors.ink,
        onPrimary: dark ? VColors.night : Colors.white,
        secondary: VColors.marigold,
        onSecondary: Colors.white,
        tertiary: VColors.teal,
        error: VColors.rose,
        surface: dark ? VColors.night : VColors.paper,
        surfaceContainerLowest: dark ? const Color(0xFF0A0914) : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF141228)
            : const Color(0xFFF6F1E8),
        surfaceContainer: dark ? VColors.nightSurface : const Color(0xFFF1EBDF),
        surfaceContainerHigh: dark
            ? const Color(0xFF211E3D)
            : const Color(0xFFEBE4D6),
        surfaceContainerHighest: dark
            ? const Color(0xFF2A2749)
            : const Color(0xFFE4DCCB),
        outlineVariant: dark
            ? const Color(0xFF34305A)
            : const Color(0xFFDCD3C1),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    scaffoldBackgroundColor: scheme.surface,
  );

  final text = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: VColors.marigold.withValues(alpha: dark ? 0.28 : 0.2),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [
      VarnikaColors(
        protected: VColors.teal,
        unprotected: dark ? const Color(0xFFFB923C) : VColors.marigold,
        download: dark ? const Color(0xFF5EEAD4) : VColors.teal,
        upload: dark ? const Color(0xFFC4B5FD) : const Color(0xFF6D5DD3),
      ),
    ],
  );
}
