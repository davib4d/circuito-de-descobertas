import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta tirada da referência visual: céu lilás, nuvens menta e um único
/// ponto coral reservado para a ação principal.
abstract final class AppColors {
  static const lilas = Color(0xFFB58DF1);
  static const lilasForte = Color(0xFF9A6FE6);
  static const lilasFundo = Color(0xFFF3ECFF);
  static const lilasNevoa = Color(0xFFE6D9FB);
  static const uva = Color(0xFF3A2A5E);
  static const uvaSuave = Color(0xFF75679A);
  static const menta = Color(0xFF8FE3A7);
  static const mentaClara = Color(0xFFDFF7E5);
  static const mentaTexto = Color(0xFF23824A);
  static const coral = Color(0xFFF8736C);
  static const branco = Colors.white;
}

abstract final class AppTheme {
  static ThemeData claro() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lilasForte,
        primary: AppColors.lilasForte,
        secondary: AppColors.menta,
        tertiary: AppColors.coral,
        surface: AppColors.branco,
      ),
      scaffoldBackgroundColor: AppColors.lilasFundo,
    );

    final texto = GoogleFonts.montserratTextTheme(base.textTheme).apply(
      bodyColor: AppColors.uva,
      displayColor: AppColors.uva,
    );

    return base.copyWith(
      textTheme: texto,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.lilasNevoa, width: 2),
          foregroundColor: AppColors.uva,
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.branco,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
      ),
    );
  }
}
