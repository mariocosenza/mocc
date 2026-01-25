import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/firebase_options.dart';
import 'package:mocc/router/router.dart';
import 'package:mocc/service/providers.dart';
import 'package:mocc/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('it')],
      path: 'assets/translations',
      fallbackLocale: Locale('it'),
      child: const ProviderScope(child: MainApp()),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final moccTextTheme = MoccTypography.build(baseTextTheme);
    final moccTheme = MaterialTheme(moccTextTheme);
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Mocc',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: moccTheme.light(),
      darkTheme: moccTheme.dark(),
      themeMode: ThemeMode.system,
    );
  }
}
