import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Drobné widgety a dialogy sdílené více obrazovkami.

/// Nadpis sekce – malé tučné písmo velkými písmeny (např. „PROFIL“,
/// „DNES · PÁTEK 16. 10.“).
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(top: 8, bottom: 4),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Ikona role v týmu – trenér (fialový přechod, píšťalka) nebo hráč
/// (zelenomodrý přechod, běžec).
class RoleAvatar extends StatelessWidget {
  const RoleAvatar({super.key, required this.isCoach, this.size = 40});

  final bool isCoach;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconBadge(
      icon: isCoach ? Icons.sports : Icons.directions_run,
      size: size,
      gradient: isCoach ? AppColors.brandGradient : AppColors.playerGradient,
    );
  }
}

/// Dialog „Opravdu …?“ s tlačítky Zrušit a [confirmLabel] (červeně).
/// Vrací true, jen když uživatel akci potvrdil.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
