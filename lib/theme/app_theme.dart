import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Celý vzhled aplikace na jednom místě:
//  1. AppColors       – pevné barvy (značka, druhy akcí, stavy),
//  2. AppTheme        – světlé a tmavé téma (ThemeData) pro MaterialApp,
//  3. ThemeController – volba režimu (podle systému / světlý / tmavý)
//                       a její uložení v telefonu,
//  4. dekorativní widgety s barevným přechodem (pozadí, karta, ikona).
//
// Obrazovky barvy nezadávají napevno (žádné Colors.indigo apod.), ale berou
// je z tématu přes Theme.of(context).colorScheme – díky tomu se po přepnutí
// na tmavý režim přebarví celá aplikace najednou.

// ---------------------------------------------------------------------------
// 1. Barvy
// ---------------------------------------------------------------------------

/// Barvy, které jsou stejné ve světlém i tmavém režimu. Jsou zvolené jako
/// „střední“ odstíny, takže jsou dobře čitelné na bílém i tmavém pozadí.
abstract final class AppColors {
  /// Hlavní barva značky (indigo) – z ní se dopočítá celé barevné schéma.
  static const brand = Color(0xFF4F46E5);
  static const violet = Color(0xFF7C3AED);
  static const fuchsia = Color(0xFFC026D3);

  /// Druhy akcí v kalendáři (viz trainingColor).
  static const team = Color(0xFF6366F1);
  static const individual = Color(0xFF0D9488);
  static const match = Color(0xFFEA580C);

  /// Stavy – BUDU / splněno, NEBUDU / chyba, upozornění, bez odpovědi.
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
  static const neutral = Color(0xFF8B8FA3);
  static const planned = Color(0xFF64748B);

  /// Přechod značky – hlavičky, přihlašovací obrazovka, ikony trenérů.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, violet],
  );

  /// Výraznější přechod přes celou obrazovku (přihlášení, nastavení týmu).
  static LinearGradient backgroundGradient(Brightness brightness) =>
      brightness == Brightness.dark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF4A044E)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brand, violet, fuchsia],
            );

  /// Barva [color] jako text nebo ikona – v tmavém režimu se zesvětlí,
  /// aby byla na tmavém pozadí dobře čitelná.
  static Color readable(BuildContext context, Color color) =>
      Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(color, Colors.white, 0.35)!
          : color;

  /// Přechod pro hráče (zelenomodrá).
  static const playerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14B8A6), Color(0xFF0E7490)],
  );
}

// ---------------------------------------------------------------------------
// 2. Témata
// ---------------------------------------------------------------------------

/// Světlé a tmavé téma. Obě se staví stejnou funkcí [_build], liší se jen
/// barvami pozadí a povrchů.
abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: const Color(0xFFF3F4F9),
        surfaces: const [
          // surface, Lowest, Low, Container, High, Highest
          Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFF7F8FC),
          Color(0xFFF0F2F8), Color(0xFFEAEDF5), Color(0xFFE3E7F1),
        ],
        outlineVariant: const Color(0xFFE3E6EF),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: const Color(0xFF0B0D12),
        surfaces: const [
          Color(0xFF161922), Color(0xFF0F1117), Color(0xFF1A1E28),
          Color(0xFF1F2330), Color(0xFF252A38), Color(0xFF2C3242),
        ],
        outlineVariant: const Color(0xFF2A2F3D),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required List<Color> surfaces,
    required Color outlineVariant,
  }) {
    final isDark = brightness == Brightness.dark;

    // Schéma se dopočítá z barvy značky (Material 3). Varianta „fidelity“
    // drží barvy blízko zadané značce, místo aby je zesvětlila do pastelu.
    // Povrchy (karty, lišty, dialogy) přepisujeme vlastními neutrálními
    // odstíny, aby nebyly do fialova.
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: isDark ? const Color(0xFF8C8CFF) : AppColors.brand,
      onPrimary: isDark ? const Color(0xFF14104A) : Colors.white,
      error: isDark ? const Color(0xFFF87171) : AppColors.danger,
      surface: surfaces[0],
      surfaceContainerLowest: surfaces[1],
      surfaceContainerLow: surfaces[2],
      surfaceContainer: surfaces[3],
      surfaceContainerHigh: surfaces[4],
      surfaceContainerHighest: surfaces[5],
      outlineVariant: outlineVariant,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
    );

    // Nadpisy tučnější a s menšími mezerami mezi písmeny – moderní vzhled.
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: base.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: base.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleMedium: base.textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
    );

    final rounded16 =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text,

      // Moderní přechod mezi obrazovkami (nová obrazovka „vyjede“ a stará
      // ztmavne) – na Androidu místo výchozího přiblížení. iPhone si
      // nechává svůj systémový přechod.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...base.pageTransitionsTheme.builders,
          TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        },
      ),

      // Horní lišta splývá s pozadím, nadpis je velký a tučný.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
        // Barva ikon ve stavovém řádku telefonu (hodiny, baterie).
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // Karty bez stínu, s jemným okrajem a víc zakulacené.
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant),
        ),
      ),

      // Textová pole – vyplněná barvou karty, zakulacená, při psaní
      // zvýrazněná hlavní barvou.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(outlineVariant),
        enabledBorder: inputBorder(outlineVariant),
        focusedBorder: inputBorder(colors.primary, 2),
        errorBorder: inputBorder(colors.error),
        focusedErrorBorder: inputBorder(colors.error, 2),
        prefixIconColor: colors.onSurfaceVariant,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded16,
          padding: buttonPadding,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: rounded16, padding: buttonPadding),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded16,
          padding: buttonPadding,
          side: BorderSide(color: outlineVariant, width: 1.5),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded16,
          textStyle: text.labelLarge,
        ),
      ),

      // Přepínače (např. Nadcházející / Proběhlé) – vybraná část plná
      // hlavní barvou.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(rounded16),
          side: WidgetStatePropertyAll(BorderSide(color: outlineVariant)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary
                : colors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.onSurface,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.onSurfaceVariant,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: outlineVariant),
        backgroundColor: colors.surface,
        selectedColor: colors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
        labelStyle: text.labelLarge,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),

      // Spodní lišta – barva karty, vybraná položka v hlavní barvě.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
      ),

      // Hlášky dole jako plovoucí „bublina“ nad spodní lištou.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      listTileTheme: ListTileThemeData(iconColor: colors.onSurfaceVariant),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      dividerTheme: DividerThemeData(color: outlineVariant, space: 1),

      // Záložky (Přehled / Kalendář / Tým) – vybraná záložka je plný
      // zakulacený „knoflík“ v hlavní barvě, bez čáry pod záložkami.
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        splashBorderRadius: BorderRadius.circular(12),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Volba režimu
// ---------------------------------------------------------------------------

/// Pamatuje si zvolený režim vzhledu a ukládá ho do telefonu
/// (shared_preferences), takže platí i po restartu aplikace.
///
/// Je to [ValueNotifier] – MaterialApp v main.dart ho poslouchá přes
/// ValueListenableBuilder a po změně se celá aplikace překreslí v novém
/// režimu. Volba je jen v tomto telefonu (neukládá se do Firestore).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  /// Jediná instance pro celou aplikaci.
  static final instance = ThemeController._();

  static const _key = 'themeMode';

  /// Načte uloženou volbu. Volá se jednou při startu aplikace (main.dart).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      value = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (e) {
      // Když se uložení nepodaří přečíst, zůstane režim podle systému.
      debugPrint('Nepodařilo se načíst režim vzhledu: $e');
    }
  }

  /// Přepne režim (hned se projeví) a uloží ho na příště.
  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      debugPrint('Nepodařilo se uložit režim vzhledu: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// 4. Dekorativní widgety
// ---------------------------------------------------------------------------

/// Celoobrazovkové pozadí s barevným přechodem a dvěma průhlednými
/// „bublinami“ – přihlášení, zadání jména a nastavení týmu.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // Na barevném pozadí mají být ikony stavového řádku vždy bílé.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(brightness),
        ),
        child: Stack(
          children: [
            const Positioned(top: -80, right: -60, child: _Bubble(size: 260)),
            const Positioned(bottom: -100, left: -80, child: _Bubble(size: 320)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// Karta s barevným přechodem a ozdobnými kruhy – úvodní pozdrav na
/// Domů a profil v Nastavení účtu. Text uvnitř má být bílý.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.gradient = AppColors.brandGradient,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Stín v barvě přechodu (u zelenomodré karty zelenomodrý).
    final gradient = this.gradient;
    final shadow =
        gradient is LinearGradient ? gradient.colors.last : AppColors.brand;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(top: -40, right: -30, child: _Bubble(size: 140)),
          const Positioned(bottom: -50, right: 60, child: _Bubble(size: 100)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Ikona ve čtverci se zakulacenými rohy. S [gradient] je barevná (bílá
/// ikona na přechodu), s [color] jemně podbarvená (ikona v barvě [color]
/// na její průhledné verzi), bez obojího „skleněná“ – na barevné pozadí.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 40,
    this.gradient,
    this.color,
  });

  final IconData icon;
  final double size;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color? background;
    final Color iconColor;
    if (gradient != null) {
      background = null;
      iconColor = Colors.white;
    } else if (color != null) {
      background = color.withValues(alpha: isDark ? 0.22 : 0.12);
      iconColor = AppColors.readable(context, color);
    } else {
      background = Colors.white.withValues(alpha: 0.18);
      iconColor = Colors.white;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: gradient == null && color == null
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Icon(icon, size: size * 0.55, color: iconColor),
    );
  }
}

/// Průhledný bílý kruh na ozdobu barevných ploch.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}
