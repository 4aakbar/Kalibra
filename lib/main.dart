import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/models.dart';
import 'core/notifications.dart';
import 'screens/cari_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/form_screen.dart';
import 'screens/hapus_akun_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pengaturan_screen.dart';
import 'screens/profil_screen.dart';
import 'ui/theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final app = AppState();
  await app.load();
  final reminders = Reminders(app);
  app.onSchedulesChanged = reminders.scheduleSync;
  reminders.onOpen = (id) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (id != null && app.byId(id) != null) {
      nav.pushNamed('/jadwal', arguments: DetailArgs(id));
    }
  };
  reminders.init().then((_) => reminders.sync()).catchError((Object e) => debugPrint('$e'));
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      Provider.value(value: reminders),
    ],
    child: const KalibraApp(),
  ));
}

class KalibraApp extends StatelessWidget {
  const KalibraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.select<AppState, ThemePref>((a) => a.prefs.theme);
    final onboarded = context.select<AppState, bool>((a) => a.onboarded);
    return MaterialApp(
      title: 'Kalibra',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(KColors.light),
      darkTheme: buildTheme(KColors.darkTheme),
      themeMode: switch (theme) {
        ThemePref.terang => ThemeMode.light,
        ThemePref.gelap => ThemeMode.dark,
        ThemePref.sistem => ThemeMode.system,
      },
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
      onGenerateRoute: (settings) {
        final Widget page = switch (settings.name) {
          '/home' => const HomeShell(),
          '/onboarding' => const OnboardingScreen(),
          '/jadwal' => DetailScreen(args: settings.arguments as DetailArgs),
          '/form' => FormScreen(args: settings.arguments as FormArgs? ?? const FormArgs()),
          '/profil' => const ProfilScreen(),
          '/pengaturan' => const PengaturanScreen(),
          '/cari' => const CariScreen(),
          '/hapus-akun' => const HapusAkunScreen(),
          _ => const HomeShell(),
        };
        return MaterialPageRoute(
          builder: (_) => page,
          settings: settings,
          fullscreenDialog: settings.name == '/form',
        );
      },
    );
  }
}
