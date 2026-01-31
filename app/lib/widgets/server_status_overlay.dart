import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mocc/service/server_health_service.dart';

class ServerStatusOverlay extends ConsumerStatefulWidget {
  const ServerStatusOverlay({super.key});

  @override
  ConsumerState<ServerStatusOverlay> createState() =>
      _ServerStatusOverlayState();
}

class _ServerStatusOverlayState extends ConsumerState<ServerStatusOverlay> {
  // If true, the overlay is visible. We start false and enable it after a delay.
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Trigger check on mount if we haven't already
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serverHealthProvider.notifier).startCheck();
    });

    // Add a small delay before showing the overlay to avoid flickering if connection is fast
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  String _getStatusMessage(ServerStatus status) {
    switch (status) {
      case ServerStatus.initial:
      case ServerStatus.checking:
        return 'status_checking_connection'.tr();
      case ServerStatus.wakingUp:
        return 'status_waking_up'.tr();
      case ServerStatus.online:
        return 'status_connected'.tr();
      case ServerStatus.error:
        return 'status_connection_failed'.tr();
    }
  }

  String _getStatusSubtext(ServerStatus status) {
    if (status == ServerStatus.wakingUp) {
      return 'status_waking_up_hint'.tr();
    }
    if (status == ServerStatus.error) {
      return 'status_failed_hint'.tr();
    }
    return 'status_secure_hint'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serverHealthProvider);
    final notifier = ref.read(serverHealthProvider.notifier);

    // If ready, completely hide (unblock everything)
    if (status == ServerStatus.online) return const SizedBox.shrink();

    // If not ready, but grace period hasn't passed, show invisible blocking widget?
    // User requested: "Add a small delay befor showing the banner because it will be always shown even if online"
    // If I return SizedBox.shrink() here, the user sees the UI and can interact.
    // If the server connects in 200ms, they might tap something that fails.
    // However, the user explicitly complained about it blocking/showing.
    // I will return SizedBox.shrink() if _isVisible is false, effectively allowing interaction for the first 800ms.
    // This is a trade-off: improved UX (no flicker) vs potential race condition (user clicks fast).
    if (!_isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Blur barrier
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
        ),

        // Centered Card
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == ServerStatus.error)
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    )
                  else
                    // Use a nice animation for waiting
                    SizedBox(
                      height: 120,
                      child: Lottie.asset(
                        'assets/lotties/Walking burger.json',
                        fit: BoxFit.contain,
                      ),
                    ),

                  const SizedBox(height: 24),

                  Text(
                    _getStatusMessage(status),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _getStatusSubtext(status),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  if (status == ServerStatus.error)
                    FilledButton.icon(
                      onPressed: notifier.retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('retry'.tr()), // Using existing 'retry' key
                    )
                  else
                    // nice pulsing loading bar or just circular
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
