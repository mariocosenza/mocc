import 'dart:async';
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

class _ServerStatusOverlayState extends ConsumerState<ServerStatusOverlay>
    with WidgetsBindingObserver {
  bool _isVisible = false;
  bool _isForeground = true;
  Timer? _showTimer;
  ProviderSubscription<ServerStatus>? _serverStatusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serverHealthProvider.notifier).startCheck();
    });
    _serverStatusSub = ref.listenManual<ServerStatus>(
      serverHealthProvider,
      (previous, next) {
        if (!mounted) return;

        if (!_isForeground) {
          _showTimer?.cancel();
          if (_isVisible) {
            setState(() {
              _isVisible = false;
            });
          }
          return;
        }

        if (next == ServerStatus.online || next == ServerStatus.initial) {
          _showTimer?.cancel();
          if (_isVisible) {
            setState(() {
              _isVisible = false;
            });
          }
          return;
        }

        if (_isVisible) return;

        _showTimer?.cancel();
        _showTimer = Timer(const Duration(seconds: 1), () {
          if (!mounted) return;
          final current = ref.read(serverHealthProvider);
          if (current != ServerStatus.online &&
              current != ServerStatus.initial) {
            setState(() {
              _isVisible = true;
            });
          }
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showTimer?.cancel();
    _serverStatusSub?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground =
        state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (_isForeground != isForeground) {
      setState(() {
        _isForeground = isForeground;
        if (!_isForeground) {
          _isVisible = false;
        }
      });
    }
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = ref.watch(serverHealthProvider);
    final notifier = ref.read(serverHealthProvider.notifier);

    if (!_isForeground || status == ServerStatus.online) {
      return const SizedBox.shrink();
    }

    if (!_isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Blur barrier
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: cs.scrim.withValues(alpha: 0.3)),
          ),
        ),

        // Centered Card
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.15),
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
                      color: cs.error,
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      _getStatusMessage(status),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      _getStatusSubtext(status),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (status == ServerStatus.error)
                    FilledButton.icon(
                      onPressed: notifier.retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('retry'.tr()),
                    )
                  else
                    // nice pulsing loading bar or just circular
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
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
