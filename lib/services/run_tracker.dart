import 'package:geolocator/geolocator.dart';

import 'run_service.dart';

/// Stav záznamu běhu: připraveno → běží ⇄ pauza → dokončeno.
enum RunState { ready, running, paused, finished }

/// Počítá rozběhnutý běh z bodů GPS – aktivní čas, vzdálenost a trasu.
///
/// Neví nic o GPS ani o databázi (body mu předává RunScreen), takže jde
/// otestovat bez telefonu. Běh je do uložení jen v paměti – když aplikace
/// spadne, ztratí se (průběžné ukládání uživatel nechtěl).
class RunTracker {
  /// [now] jde v testech nahradit, aby nemusely čekat na skutečný čas.
  RunTracker({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Body s horší přesností (v metrech) se zahazují – GPS „skáče“.
  static const maxAccuracyMeters = 25.0;

  final DateTime Function() _now;

  RunState _state = RunState.ready;
  DateTime? _startedAt;
  DateTime? _endedAt;

  // Aktivní čas se počítá z hodin (rozdíl časů), ne z tiků Timeru – ty se
  // se zhasnutým displejem můžou zpozdit nebo vynechat.
  Duration _activeBefore = Duration.zero;
  DateTime? _runningSince;

  int _segment = 0;
  double _distance = 0;
  bool _hasFix = false;
  final List<RunPoint> _points = [];

  RunState get state => _state;

  /// Přišel už aspoň jeden dost přesný bod? Do té doby UI ukazuje
  /// „Hledám signál GPS…“ (bez internetu může první zaměření trvat i
  /// desítky sekund).
  bool get hasFix => _hasFix;

  List<RunPoint> get points => List.unmodifiable(_points);

  /// Uběhnutá vzdálenost v metrech (bez úseků přes pauzu).
  double get distanceMeters => _distance;

  /// Aktivní čas v celých sekundách – bez pauz.
  int get activeSeconds {
    final since = _runningSince;
    final active = since == null
        ? _activeBefore
        : _activeBefore + _now().difference(since);
    return active.inSeconds;
  }

  void start() {
    if (_state != RunState.ready) return;
    final now = _now();
    _startedAt = now;
    _runningSince = now;
    _state = RunState.running;
  }

  /// Pozastaví běh: hodiny stojí a body se ignorují. GPS ale běží dál
  /// (drží zaměření, takže pokračování je okamžité).
  void pause() {
    if (_state != RunState.running) return;
    _stopClock();
    _state = RunState.paused;
  }

  /// Pokračuje po pauze novým úsekem – vzdálenost mezi posledním bodem
  /// před pauzou a prvním po ní se nepočítá (hráč mohl třeba popojet).
  void resume() {
    if (_state != RunState.paused) return;
    _runningSince = _now();
    _segment++;
    _state = RunState.running;
  }

  /// Ukončí běh (jde i z pauzy). Potom už jde jen uložit, nebo zahodit.
  void finish() {
    if (_state != RunState.running && _state != RunState.paused) return;
    _stopClock();
    _endedAt = _now();
    _state = RunState.finished;
  }

  void _stopClock() {
    final since = _runningSince;
    if (since != null) _activeBefore += _now().difference(since);
    _runningSince = null;
  }

  /// Zpracuje bod z GPS. Nepřesné body a body během pauzy se zahodí.
  void addPosition(double lat, double lng, double accuracy) {
    if (accuracy > maxAccuracyMeters) return;
    _hasFix = true;
    if (_state != RunState.running) return;

    final last = _points.isEmpty ? null : _points.last;
    if (last != null && last.s == _segment) {
      _distance += Geolocator.distanceBetween(last.lat, last.lng, lat, lng);
    }
    _points.add(RunPoint(lat: lat, lng: lng, t: activeSeconds, s: _segment));
  }

  /// Hotový běh pro uložení (jen po [finish]).
  Run toRun() {
    if (_state != RunState.finished) {
      throw StateError('Běh ještě není ukončený');
    }
    return Run(
      startedAt: _startedAt!,
      endedAt: _endedAt!,
      durationSeconds: activeSeconds,
      distanceMeters: _distance.round(),
      points: List.of(_points),
    );
  }
}
