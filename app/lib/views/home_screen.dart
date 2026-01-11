import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/widgets/microsoft_profile_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: auth,
          builder: (context, _) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MicrosoftProfileAvatar(
                      isAuthenticated: auth.isAuthenticated,
                      getGraphToken: () => auth.acquireAccessToken(scopes: ['User.Read']),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}