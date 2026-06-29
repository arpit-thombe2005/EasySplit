import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EasySplit App Theme
/// Design System: Minimal, Black & White, Material 3
/// Inspired by: Stitch SplitMate Design System
class AppTheme {
  AppTheme._();

  // ── Color Palette ───────────────────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF7F7F7);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _surfaceDark = Color(0xFF1A1A1A);
  static const Color _cardDark = Color(0xFF242424);

  static const Color _grey100 = Color(0xFFF5F5F5);
  static const Color _grey200 = Color(0xFFE5E5E5);
  static const Color _grey300 = Color(0xFFD4D4D4);
  static const Color _grey400 = Color(0xFFA3A3A3);
  static const Color _grey500 = Color(0xFF737373);
  static const Color _grey600 = Color(0xFF525252);
  static const Color _grey700 = Color(0xFF404040);
  static const Color _grey800 = Color(0xFF262626);
  static const Color _grey900 = Color(0xFF171717);

  // Semantic colors
  static const Color _error = Color(0xFFDC2626);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFD97706);
  static const Color _info = Color(0xFF2563EB);

  // Positive / Negative balance indicators (muted, professional)
  static const Color positiveBalance = Color(0xFF166534); // dark green
  static const Color negativeBalance = Color(0xFF991B1B); // dark red
  static const Color positiveBalanceBg = Color(0xFFF0FDF4);
  static const Color negativeBalanceBg = Color(0xFFFEF2F2);
  static const Color positiveBalanceDark = Color(0xFF4ADE80);
  static const Color negativeBalanceDark = Color(0xFFF87171);

  // ── Typography ──────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme(
      TextTheme(
        // Display
        displayLarge: TextStyle(
          fontSize: 57, fontWeight: FontWeight.w300, color: primary, letterSpacing: -0.25),
        displayMedium: TextStyle(
          fontSize: 45, fontWeight: FontWeight.w300, color: primary),
        displaySmall: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w400, color: primary),

        // Headline
        headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
        headlineMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.25),
        headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: primary),

        // Title
        titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: primary),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: primary, letterSpacing: 0.15),
        titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary, letterSpacing: 0.1),

        // Body
        bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, color: primary, letterSpacing: 0.5),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, color: primary, letterSpacing: 0.25),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400, color: secondary, letterSpacing: 0.4),

        // Label
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary, letterSpacing: 0.1),
        labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: primary, letterSpacing: 0.5),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.5),
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: _black,
      onPrimary: _white,
      primaryContainer: _grey100,
      onPrimaryContainer: _black,
      secondary: _grey600,
      onSecondary: _white,
      secondaryContainer: _grey200,
      onSecondaryContainer: _grey800,
      surface: _surface,
      onSurface: _black,
      surfaceContainerHighest: _grey100,
      outline: _grey300,
      outlineVariant: _grey200,
      error: _error,
      onError: _white,
      shadow: _black.withValues(alpha: 0.06),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(_black, _grey500),
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        backgroundColor: _white,
        foregroundColor: _black,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: _black.withValues(alpha: 0.08),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _black,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _black, size: 22),
        actionsIconTheme: const IconThemeData(color: _black, size: 22),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _grey200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: _white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _black,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: _grey300, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _black,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _grey100,
        hintStyle: GoogleFonts.inter(color: _grey400, fontSize: 15),
        labelStyle: GoogleFonts.inter(color: _grey500, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _black, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _white,
        selectedItemColor: _black,
        unselectedItemColor: _grey400,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _white,
        indicatorColor: _grey100,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _black, size: 24);
          }
          return const IconThemeData(color: _grey400, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _black);
          }
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: _grey400);
        }),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _grey100,
        selectedColor: _black,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: _grey200,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _black,
        contentTextStyle: GoogleFonts.inter(color: _white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: _black),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: _grey600),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: _grey300,
        dragHandleSize: Size(40, 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _black,
        foregroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        extendedTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _white : _grey400),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _black : _grey200),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _black,
        linearTrackColor: _grey200,
        circularTrackColor: _grey200,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _black,
        unselectedLabelColor: _grey400,
        indicatorColor: _black,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
        dividerColor: _grey200,
        dividerHeight: 1,
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _white,
      onPrimary: _black,
      primaryContainer: _grey800,
      onPrimaryContainer: _white,
      secondary: _grey400,
      onSecondary: _black,
      secondaryContainer: _grey700,
      onSecondaryContainer: _grey200,
      surface: _surfaceDark,
      onSurface: _white,
      surfaceContainerHighest: _grey800,
      outline: _grey700,
      outlineVariant: _grey800,
      error: const Color(0xFFEF4444),
      onError: _black,
      shadow: Colors.black.withValues(alpha: 0.3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(_white, _grey400),
      scaffoldBackgroundColor: _surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceDark,
        foregroundColor: _white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: _white, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: _white, size: 22),
        actionsIconTheme: const IconThemeData(color: _white, size: 22),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _white,
          foregroundColor: _black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _white,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Color(0xFF404040), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _white,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _grey800,
        hintStyle: GoogleFonts.inter(color: _grey600, fontSize: 15),
        labelStyle: GoogleFonts.inter(color: _grey400, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _white, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _grey800,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _white, size: 24);
          }
          return const IconThemeData(color: _grey500, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _white);
          }
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: _grey500);
        }),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _white,
        contentTextStyle: GoogleFonts.inter(color: _black, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: _white),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: _grey400),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: Color(0xFF404040),
        dragHandleSize: Size(40, 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _white,
        foregroundColor: _black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _grey800,
        selectedColor: _white,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _black : _grey500),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _white : _grey700),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _white,
        linearTrackColor: Color(0xFF333333),
        circularTrackColor: Color(0xFF333333),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _white,
        unselectedLabelColor: _grey500,
        indicatorColor: _white,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
        dividerColor: const Color(0xFF2A2A2A),
        dividerHeight: 1,
      ),
    );
  }
}
