import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/firebase_options.dart';
import 'package:mocc/router/router.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/service/providers.dart';
import 'package:mocc/service/server_health_service.dart';
import 'package:mocc/theme/theme.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/service/graphql_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await EasyLocalization.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Firebase initialization failed or timed out: $e');
  }
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

class _MainAppState extends ConsumerState<MainApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    ref.read(serverHealthProvider.notifier).updateForeground(isForeground);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthController>(authControllerProvider, (previous, next) {
      if (next.isAuthenticated &&
          (previous == null || !previous.isAuthenticated)) {
        ref.read(notificationServiceProvider).refreshRegistration();
      }
    });

    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final moccTextTheme = MoccTypography.build(baseTextTheme);
    final moccTheme = MaterialTheme(moccTextTheme);
    final goRouter = ref.watch(goRouterProvider);
    final graphQLClient = ref.watch(graphQLClientProvider);

    return GraphQLProvider(
      client: ValueNotifier(graphQLClient),
      child: MaterialApp.router(
        routerConfig: goRouter,
        title: 'MOCC',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        theme: moccTheme.light(),
        darkTheme: moccTheme.dark(),
        themeMode: ThemeMode.system,
      ),
    );
  }
}
