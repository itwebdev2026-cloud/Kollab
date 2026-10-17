import 'package:flutter/material.dart';

/// Single place to change colors, tagline and logo.
class Brand {
  static const navy = Color(0xFF0F1B3D);
  static const purple = Color(0xFF7B3FE4);
  static const blue = Color(0xFF3B82F6);
  static const pink = Color(0xFFEC4899);
  static const orange = Color(0xFFF97316);
  static const gradient = LinearGradient(
      colors: [purple, blue, pink, orange],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const name = 'KOLLAB';
  static const tagline = 'Discover. Match. Collaborate.';

  static ThemeData theme({bool dark = false}) {
    final ink = dark ? const Color(0xFFE8EDF4) : navy;
    final baseText =
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
            .textTheme
            .apply(
              fontFamily: 'Manrope',
              bodyColor: ink,
              displayColor: ink,
            );
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.08,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Manrope',
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        secondary: pink,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF101820) : Colors.white,
      appBarTheme: AppBarTheme(
          backgroundColor: dark ? const Color(0xFF101820) : Colors.white,
          foregroundColor: ink,
          elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)))),
      inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    );
  }
}

class CollavoLogo extends StatelessWidget {
  final double size;
  const CollavoLogo({super.key, this.size = 96});

  Widget _placeholder() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(size * .28),
          boxShadow: [
            BoxShadow(
              color: Brand.purple.withValues(alpha: .18),
              blurRadius: size * .14,
              offset: Offset(0, size * .06),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.handshake_rounded,
            size: size * .64,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Semantics(
        label: Brand.name,
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: Image.asset(
            'assets/images/collavo-logo.jpg',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        ),
      );
}
