import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/run_service.dart';
import '../services/run_tracker.dart';
import '../services/training_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../utils/run_format.dart';
import '../widgets/common.dart';
import '../widgets/run_widgets.dart';

/// Záznam běžeckého tréninku pomocí GPS (čas, vzdálenost, tempo, trasa).
///
/// Stavy (viz [RunState]):
/// ```
/// [Start] → BĚŽÍ: čas, vzdálenost, tempo   [Pauza] [Ukončit]
///           PAUZA: hodnoty stojí           [Pokračovat] [Ukončit]
///           DOKONČENO: souhrn              [Zahodit] [Uložit běh]
/// ```
/// Funguje i bez internetu – GPS signál internet nepotřebuje a uložený
/// běh se odešle, až bude připojení (viz RunService.saveRun).
class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.teamId, required this.training});

  final String teamId;
  final Training training;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final _runService = RunService();
  final _tracker = RunTracker();
  StreamSubscription<Position>? _positions;
  Timer? _clock;

  bool _starting = false;
  bool _saving = false;
  // Po uložení se obrazovka zavírá bez dotazu „Zahodit běh?“.
  bool _saved = false;
  String _error = '';
  // Výpadek GPS během běhu (např. vypnutá poloha) – dosud zaznamenaný běh
  // zůstává, jen se ukáže upozornění.
  String _gpsWarning = '';

  RunState get _state => _tracker.state;

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  void _stopTracking() {
    _positions?.cancel();
    _positions = null;
    _clock?.cancel();
    _clock = null;
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = '';
    });
    try {
      await _runService.ensureLocationReady();
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = errorText(e);
        });
      }
      return;
    }
    if (!mounted) return;

    _positions = _runService.positions().listen(
      (position) => setState(() {
        _gpsWarning = '';
        _tracker.addPosition(
          position.latitude,
          position.longitude,
          position.accuracy,
        );
      }),
      onError: (Object e) {
        debugPrint('Chyba GPS během běhu: $e');
        if (!mounted) return;
        setState(
          () => _gpsWarning = e is LocationServiceDisabledException
              ? 'Poloha v telefonu je vypnutá – zapni ji, ať se běh zaznamenává dál.'
              : 'Signál GPS se ztratil.',
        );
      },
    );
    // GPS při stání nic neposílá – hodiny na displeji překresluje Timer.
    // Samotný čas počítá RunTracker z hodin, ne z tiků.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _starting = false;
      _tracker.start();
    });
  }

  void _finish() {
    _stopTracking();
    setState(_tracker.finish);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final sent = await _runService.saveRun(
        widget.teamId,
        widget.training.id,
        _tracker.toRun(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _saved = true;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Běh uložen'
                : 'Běh je uložený v telefonu, odešle se, až budeš online.',
          ),
        ),
      );
    } catch (e) {
      // Běh zůstává na obrazovce, aby se při chybě neztratil.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorText(e);
        });
      }
    }
  }

  /// Zeptá se, jestli běh opravdu zahodit, a případně obrazovku zavře.
  Future<void> _confirmDiscard() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Zahodit běh?',
      message: 'Záznam běhu se neuloží.',
      confirmLabel: 'Zahodit',
    );
    if (confirmed && mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = widget.training.description;
    final seconds = _tracker.activeSeconds;
    final meters = _tracker.distanceMeters;
    final statusColor = _statusColor();

    // Zpět (tlačítko i šipka v AppBaru) během běhu nebo po něm se nejdřív
    // zeptá, jestli běh zahodit.
    return PopScope(
      canPop: _state == RunState.ready || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.training.title)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _StatusBanner(text: _statusText(), color: statusColor),
                const Spacer(),
                // Čas uprostřed velkého kruhu v barvě stavu. Kruh se na
                // menším displeji zmenší (Flexible + AspectRatio), čísla
                // se do něj vždy vejdou (FittedBox).
                Flexible(
                  flex: 8,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 260,
                      maxHeight: 260,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.6),
                            width: 6,
                          ),
                        ),
                        child: FittedBox(
                          child: Column(
                            children: [
                              Text(
                                formatDuration(seconds),
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                'Čas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    RunValue(
                      label: 'Vzdálenost',
                      value: formatDistance(meters),
                      fontSize: 28,
                    ),
                    RunValue(
                      label: 'Tempo',
                      value: formatPace(seconds, meters),
                      fontSize: 28,
                    ),
                  ],
                ),
                const Spacer(),
                if (_state == RunState.ready && description != null) ...[
                  Text(description, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                if (_gpsWarning.isNotEmpty && _state != RunState.finished) ...[
                  Text(
                    _gpsWarning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error.isNotEmpty) ...[
                  Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusText() => switch (_state) {
    RunState.ready => 'Telefon můžeš během běhu zhasnout, záznam poběží dál.',
    RunState.running => _tracker.hasFix ? 'Běžíš' : 'Hledám signál GPS…',
    RunState.paused => 'Pauza',
    RunState.finished => 'Běh dokončen',
  };

  Color _statusColor() => switch (_state) {
    RunState.ready => AppColors.planned,
    RunState.running => _tracker.hasFix ? AppColors.success : AppColors.warning,
    RunState.paused => AppColors.warning,
    RunState.finished => AppColors.team,
  };

  Widget _buildButtons() {
    if (_starting || _saving) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final stop = _BigButton(
      label: 'Ukončit',
      icon: Icons.stop,
      color: AppColors.danger,
      onPressed: _finish,
    );
    return switch (_state) {
      RunState.ready => _BigButton(
        label: 'Start',
        icon: Icons.play_arrow,
        color: AppColors.success,
        onPressed: _start,
      ),
      RunState.running => _ButtonRow(
        left: _BigButton(
          label: 'Pauza',
          icon: Icons.pause,
          color: AppColors.warning,
          outlined: true,
          onPressed: () => setState(_tracker.pause),
        ),
        right: stop,
      ),
      RunState.paused => _ButtonRow(
        left: _BigButton(
          label: 'Pokračovat',
          icon: Icons.play_arrow,
          color: AppColors.success,
          onPressed: () => setState(_tracker.resume),
        ),
        right: stop,
      ),
      RunState.finished => _ButtonRow(
        left: _BigButton(
          label: 'Zahodit',
          icon: Icons.delete_outline,
          color: AppColors.danger,
          outlined: true,
          onPressed: _confirmDiscard,
        ),
        right: _BigButton(
          label: 'Uložit běh',
          icon: Icons.save,
          color: AppColors.brand,
          onPressed: _save,
        ),
      ),
    };
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    const size = Size(double.infinity, 56);
    if (outlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: size,
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
