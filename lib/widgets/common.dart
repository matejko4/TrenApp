import 'package:flutter/material.dart';

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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Kolečko s ikonou role v týmu – trenér (indigo, píšťalka) nebo hráč
/// (teal, běžec).
class RoleAvatar extends StatelessWidget {
  const RoleAvatar({super.key, required this.isCoach});

  final bool isCoach;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: isCoach ? Colors.indigo : Colors.teal,
      child: Icon(
        isCoach ? Icons.sports : Icons.directions_run,
        color: Colors.white,
      ),
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
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
