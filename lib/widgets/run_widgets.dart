import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/run_service.dart';
import '../utils/date_format.dart';
import '../utils/run_format.dart';

// Zobrazení uloženého běhu – sdílí ho detail běhu (trenér i hráč) a karta
// „Můj běh“ v detailu tréninku.

/// Mapa trasy běhu: čára pro každý úsek (mezi úseky byla pauza), značka
/// startu a cíle, přiblížená na celou trasu.
///
/// Podklad jsou dlaždice OpenStreetMap (zdarma, bez API klíče). Bez
/// internetu se dlaždice nenačtou a ukáže se jen čára trasy.
class RunMap extends StatelessWidget {
  const RunMap({super.key, required this.run, this.interactive = true});

  final Run run;

  /// false = mapa jen na ukázku (v kartě), nejde posouvat ani přibližovat
  /// – jinak by se „prala“ s posouváním stránky.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in run.points) LatLng(p.lat, p.lng)];
    if (points.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFEEEEEE),
        child: Center(
          child: Text(
            'Trasa se nezaznamenala (GPS nenašlo signál).',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    // Trasa z jediného místa má nulovou velikost – přiblížení „na celou
    // trasu“ by nedávalo smysl, proto jen pevné přiblížení na ten bod.
    final bounds = LatLngBounds.fromPoints(points);
    final singleSpot =
        bounds.north == bounds.south && bounds.east == bounds.west;

    return FlutterMap(
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: 16,
        initialCameraFit: singleSpot
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(32),
                maxZoom: 17,
              ),
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tren_app',
        ),
        PolylineLayer(
          polylines: [
            // Úsek s jediným bodem (např. po pauze hned Ukončit) čáru nemá.
            for (final segment in run.segments)
              if (segment.length > 1)
                Polyline(
                  points: [for (final p in segment) LatLng(p.lat, p.lng)],
                  strokeWidth: 5,
                  color: Colors.teal,
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
              child: const _MapPin(color: Colors.green, icon: Icons.play_arrow),
            ),
            if (!singleSpot)
              Marker(
                point: points.last,
                child: const _MapPin(color: Colors.red, icon: Icons.flag),
              ),
          ],
        ),
        // Uvedení zdroje mapy vyžadují podmínky OpenStreetMap.
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// Údaje o běhu: čas, vzdálenost, tempo a kdy hráč běžel.
class RunStats extends StatelessWidget {
  const RunStats({super.key, required this.run});

  final Run run;

  @override
  Widget build(BuildContext context) {
    final pauses = run.pauseCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RunValue(label: 'Čas', value: formatDuration(run.durationSeconds)),
            RunValue(
              label: 'Vzdálenost',
              value: formatDistance(run.distanceMeters),
            ),
            RunValue(
              label: 'Tempo',
              value: formatPace(run.durationSeconds, run.distanceMeters),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${formatDate(run.startedAt)} v ${formatTime(run.startedAt)}'
          '${pauses == 0 ? '' : ' · pauzy: $pauses'}',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

/// Jedna hodnota s popiskem (např. „5,23 km“ / „Vzdálenost“) – v údajích
/// o běhu i na obrazovce záznamu.
class RunValue extends StatelessWidget {
  const RunValue({
    super.key,
    required this.label,
    required this.value,
    this.fontSize = 20,
  });

  final String label;
  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
