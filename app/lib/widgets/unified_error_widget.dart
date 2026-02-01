import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mocc/service/error_helper.dart';

class UnifiedErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final bool isCompact;

  const UnifiedErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final errorMessage = getErrorMessage(error);
    final isServerWakingUp = errorMessage == 'server_starting_up';

    final displayTitle = isServerWakingUp
        ? 'server_waking_up'.tr()
        : 'something_went_wrong'.tr();

    // Use the error helper's result for non-waking-up errors, or a friendly message for waking up
    final displayMessage = isServerWakingUp
        ? 'server_waking_up_message'.tr()
        : errorMessage.tr();

    if (isCompact) {
      return Card(
        color: cs.errorContainer,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isServerWakingUp
                      ? Icons.hourglass_empty
                      : Icons.error_outline,
                  color: cs.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.refresh, color: cs.onErrorContainer, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isServerWakingUp
                    ? cs.primaryContainer
                    : cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isServerWakingUp
                    ? Icons.cloud_sync_rounded
                    : Icons.error_outline_rounded,
                size: 32,
                color: isServerWakingUp
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
