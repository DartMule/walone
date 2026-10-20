import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Общие размеры, цвета и стили Walone. Цвета компонентов — из ColorScheme.
abstract final class WaloneDesign {
  static const space = 4.0;
  static const controlRadius = 8.0;
  static const controlHeight = 36.0;
  static const cardRadius = 12.0;
  static const playerRadius = 16.0;
  static const pagePadding = 24.0;
  static const cardPadding = 16.0;
  static const motion = Duration(milliseconds: 200);
  static const defaultAccent = Color(0xFF007AFF);
  static const accentColors = {
    'Синий': defaultAccent,
    'Бирюзовый': Color(0xFF009BA5),
    'Зелёный': Color(0xFF38A45C),
    'Жёлтый': Color(0xFFE3B341),
    'Оранжевый': Color(0xFFE88B35),
    'Красный': Color(0xFFE45858),
    'Розовый': Color(0xFFD85D9D),
    'Фиолетовый': Color(0xFF8B65CC),
  };

  static ThemeData theme(
    Brightness brightness, {
    Color accentColor = defaultAccent,
  }) {
    final dark = brightness == Brightness.dark;
    final font = Platform.isMacOS ? '.AppleSystemUIFont' : 'Segoe UI';
    var accents = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );
    if (accentColor == defaultAccent) {
      accents = accents.copyWith(
        primary: dark ? const Color(0xFF64B5FF) : const Color(0xFF0066CC),
        onPrimary: dark ? const Color(0xFF001D36) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF193B5C)
            : const Color(0xFFE4F0FF),
        onPrimaryContainer: dark
            ? const Color(0xFFD3E8FF)
            : const Color(0xFF004080),
      );
    }
    final scheme = accents.copyWith(
      surface: dark ? const Color(0xFF242426) : Colors.white,
      surfaceContainerLowest: dark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceContainerLow: dark
          ? const Color(0xFF222224)
          : const Color(0xFFF5F5F7),
      surfaceContainer: dark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFEEEEF0),
      surfaceContainerHigh: dark
          ? const Color(0xFF343436)
          : const Color(0xFFE8E8ED),
      surfaceContainerHighest: dark
          ? const Color(0xFF3A3A3C)
          : const Color(0xFFE2E2E7),
      onSurface: dark ? const Color(0xFFF2F2F7) : const Color(0xFF1D1D1F),
      onSurfaceVariant: dark
          ? const Color(0xFFAEAEB2)
          : const Color(0xFF636366),
      outline: dark ? const Color(0xFF8E8E93) : const Color(0xFF76767B),
      outlineVariant: dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
      error: dark ? const Color(0xFFFF6961) : const Color(0xFFBA1A1A),
      surfaceTint: Colors.transparent,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      visualDensity: VisualDensity.compact,
    );
    final text = base.textTheme
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleSmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(fontSize: 15, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 13, height: 1.5),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        )
        .apply(
          fontFamily: font,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF5F5F7),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: scheme.primary,
        scaffoldBackgroundColor: scheme.surfaceContainerLow,
        textTheme: CupertinoTextThemeData(primaryColor: scheme.primary),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      focusColor: scheme.primary.withValues(alpha: 0.16),
      listTileTheme: ListTileThemeData(
        shape: shape,
        iconColor: scheme.onSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: pagePadding,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: IconThemeData(size: 20, color: scheme.onSurfaceVariant),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: shape,
          foregroundColor: scheme.onSurfaceVariant,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(controlHeight, controlHeight),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surfaceContainerHigh,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          disabledBackgroundColor: scheme.surfaceContainer,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(shape),
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.surface
                : scheme.surfaceContainer,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: shape,
        side: BorderSide.none,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        constraints: const BoxConstraints(minHeight: controlHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        labelStyle: text.bodySmall,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => text.bodySmall!.copyWith(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline),
      ),
      dialogTheme: DialogThemeData(
        barrierColor: Colors.black.withValues(alpha: dark ? 0.38 : 0.20),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(playerRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.30 : 0.16),
        menuPadding: const EdgeInsets.all(space),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        textStyle: text.bodyMedium,
        position: PopupMenuPosition.under,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.bodySmall),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),
    );
  }
}
