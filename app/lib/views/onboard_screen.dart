import 'package:auth_buttons/auth_buttons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mocc/auth/auth_controller.dart';

class OnboardingScreen extends StatefulWidget {
  final bool loginPage;
  const OnboardingScreen({super.key, required this.loginPage});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int pageCount = 4;

  late final PageController _controller;
  double _page = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _controller.addListener(() {
      final p = _controller.page ?? _controller.initialPage.toDouble();
      setState(() => _page = p);
    });
    if (widget.loginPage) {
      _page = 4.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get currentIndex => _page.round().clamp(0, pageCount - 1);

  bool get isFirstPage => currentIndex <= 0;
  bool get isLastPage => currentIndex >= pageCount - 1;

  void next() {
    if (isLastPage) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void previous() {
    if (isFirstPage) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                children: [
                  _OnboardPage(
                    title: tr('step1_title'),
                    subtitle: tr('step1_description'),
                    lottieAsset: 'assets/lotties/Food animation.json',
                  ),
                  _OnboardPage(
                    title: tr('step2_title'),
                    subtitle: tr('step2_description'),
                    lottieAsset: 'assets/lotties/scan document.json',
                  ),
                  _OnboardPage(
                    title: tr('step3_title'),
                    subtitle: tr('step3_description'),
                    lottieAsset: 'assets/lotties/Trophy.json',
                  ),
                  const _OnboardLoginPage(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Left arrow
                      IconButton(
                        onPressed: isFirstPage ? null : previous,
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous',
                      ),

                      // Dots
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pageCount, (i) {
                            final active = i == currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: active ? 18 : 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Right arrow
                      IconButton(
                        onPressed: isLastPage ? null : next,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lottieAsset;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(lottieAsset, height: 260, fit: BoxFit.contain),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class _OnboardLoginPage extends ConsumerStatefulWidget {
  const _OnboardLoginPage();

  @override
  ConsumerState<_OnboardLoginPage> createState() => _OnboardLoginPageState();
}

class _OnboardLoginPageState extends ConsumerState<_OnboardLoginPage> {
  bool isLoading = false;
  bool isChecked = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authControllerProvider);

    final brightness = MediaQuery.of(context).platformBrightness;
    final systemThemeMode =
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

    final canLogin = isChecked && !isLoading;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'login_title',
            style: Theme.of(context).textTheme.headlineLarge,
          ).tr(),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: MicrosoftAuthButton(
              onPressed: canLogin
                  ? () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);

                      setState(() => isLoading = true);

                      try {
                        await auth.signIn();
                        if(auth.isAuthenticated) {
                            context.push('/app/home');
                        }
                      } catch (e) {
                        messenger?.showSnackBar(
                          SnackBar(content: Text('Sign-in failed: $e')),
                        );
                      } finally {
                        if (!mounted) return;
                        setState(() => isLoading = false);
                      }
                    }
                  : null,
              themeMode: canLogin ? systemThemeMode : ThemeMode.dark,

              isLoading: isLoading,
              text: tr('login'),
              style: AuthButtonStyle(
                progressIndicatorColor: Theme.of(context).primaryColor,
                height: 60,
                borderRadius: 999.0,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() => isChecked = value ?? false);
                  },
                ),
                Flexible(
                  child: Text(
                    tr('privacy_agreement'),
                    style: Theme.of(context).textTheme.bodyLarge, 
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
