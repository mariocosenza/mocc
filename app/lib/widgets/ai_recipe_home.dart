import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mocc/models/recipe_model.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AiRecipeOfTheDayCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  final bool showTitle;

  const AiRecipeOfTheDayCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.showTitle = true,
  });

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isAi = recipe.generatedByAI == true;
    final int eco = recipe.ecoPointsReward ?? 0;

    final Color top = _a(cs.primaryContainer, 0.92);
    final Color bottom = _a(cs.secondaryContainer, 0.92);
    final Color ink = cs.onPrimaryContainer;

    return Semantics(
      label: tr('ai_recipe_of_the_day'),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 10),
                color: _a(Colors.black, 0.12),
              ),
            ],
            border: Border.all(color: _a(cs.onSurface, 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Pill(
                    icon: Icons.auto_awesome_rounded,
                    text: tr('ai_recipe_of_the_day'),
                    foreground: ink,
                    background: _a(ink, 0.10),
                    border: _a(ink, 0.15),
                  ),
                  const Spacer(),
                  _EcoPointsPill(
                    ecoPoints: eco,
                    foreground: ink,
                    background: _a(ink, 0.10),
                    border: _a(ink, 0.15),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (showTitle) ...[
                Text(
                  recipe.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              MarkdownBody(
                data: recipe.description,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: 16),
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Footer hints: AI tag, optional action cue
              Row(
                children: [
                  if (isAi)
                    _Pill(
                      icon: Icons.smart_toy_outlined,
                      text: tr("generated_by_ai"),
                      foreground: _a(ink, 0.92),
                      background: _a(ink, 0.08),
                      border: _a(ink, 0.12),
                    ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, color: _a(ink, 0.85)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcoPointsPill extends StatelessWidget {
  final int ecoPoints;
  final Color foreground;
  final Color background;
  final Color border;

  const _EcoPointsPill({
    required this.ecoPoints,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_rounded, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            '+$ecoPoints',
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            tr("pts"),
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;
  final Color border;

  const _Pill({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
