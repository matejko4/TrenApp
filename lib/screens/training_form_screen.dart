import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/team_service.dart';
import '../services/training_service.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/training_widgets.dart';

/// Formulář pro zadání nového tréninku, nebo úpravu existujícího
/// ([training] != null). Používá jen trenér.
///
/// Individuální trénink se zadává vybraným hráčům – buď všem najednou
/// („Všichni hráči“), nebo jen některým.
class TrainingFormScreen extends StatefulWidget {
  const TrainingFormScreen({super.key, required this.teamId, this.training});

  final String teamId;
  final Training? training;

  @override
  State<TrainingFormScreen> createState() => _TrainingFormScreenState();
}

class _TrainingFormScreenState extends State<TrainingFormScreen> {
  final _trainingService = TrainingService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      TeamService().streamTeamMembers(widget.teamId);

  late final _titleController =
      TextEditingController(text: widget.training?.title);
  late final _placeController =
      TextEditingController(text: widget.training?.place);
  late final _descriptionController =
      TextEditingController(text: widget.training?.description);

  late String _kind = widget.training?.kind ?? TrainingKind.team;
  late TrainingType _type = widget.training?.type ?? TrainingType.technique;
  late DateTime _date = widget.training?.startAt ?? DateTime.now();
  late TimeOfDay _start = widget.training == null
      ? const TimeOfDay(hour: 17, minute: 0)
      : TimeOfDay.fromDateTime(widget.training!.startAt);
  late TimeOfDay? _end = widget.training?.endAt == null
      ? null
      : TimeOfDay.fromDateTime(widget.training!.endAt!);
  late final Set<String> _selectedPlayers = {...?widget.training?.assignedTo};

  bool _loading = false;
  String _error = '';

  bool get _isTeam => _kind == TrainingKind.team;

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: end
          ? _end ?? _start.replacing(hour: (_start.hour + 1) % 24)
          : _start,
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _end = picked;
      } else {
        _start = picked;
      }
    });
  }

  Future<void> _save(Map<String, String> players) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _trainingService.saveTraining(
        teamId: widget.teamId,
        trainingId: widget.training?.id,
        kind: _kind,
        title: _titleController.text,
        type: _type,
        startAt: _at(_start),
        endAt: _end == null ? null : _at(_end!),
        place: _placeController.text,
        description: _descriptionController.text,
        // Jen hráči, kteří jsou pořád v týmu.
        assignedTo: _selectedPlayers.where(players.containsKey).toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.training != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Upravit trénink' : 'Nový trénink'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Chyba: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = playerNames(snapshot.data!.docs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: TrainingKind.team,
                    label: Text('Společný'),
                    icon: Icon(Icons.groups),
                  ),
                  ButtonSegment(
                    value: TrainingKind.individual,
                    label: Text('Individuální'),
                    icon: Icon(Icons.person),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) =>
                    setState(() => _kind = selection.first),
              ),
              const SizedBox(height: 8),
              Text(
                _isTeam
                    ? 'Pro celý tým – hráči odpoví BUDU / NEBUDU.'
                    : 'Pro vybrané hráče – sleduje se, jestli trénink splnili.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Název',
                  hintText: 'např. Trénink na hřišti',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              Text('Typ tréninku',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in TrainingType.values)
                    ChoiceChip(
                      avatar: Icon(trainingTypeIcon(type), size: 18),
                      label: Text(type.label),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _PickerField(
                label: 'Datum',
                icon: Icons.event,
                value: formatDate(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      label: 'Začátek',
                      icon: Icons.schedule,
                      value: formatTime(_at(_start)),
                      onTap: () => _pickTime(end: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerField(
                      label: 'Konec',
                      icon: Icons.schedule_outlined,
                      value: _end == null ? 'Nezadaný' : formatTime(_at(_end!)),
                      onTap: () => _pickTime(end: true),
                      onClear:
                          _end == null ? null : () => setState(() => _end = null),
                    ),
                  ),
                ],
              ),
              if (_isTeam) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _placeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Místo',
                    hintText: 'např. Hřiště u školy',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Popis / zadání',
                  hintText: 'např. 5 km volným tempem',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (!_isTeam) ...[
                const SizedBox(height: 16),
                Text('Pro které hráče',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _buildPlayerPicker(players),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _save(players),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isEdit ? 'Uložit změny' : 'Přidat trénink'),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerPicker(Map<String, String> players) {
    if (players.isEmpty) {
      return const Text(
        'V týmu zatím nejsou žádní hráči. Pozvi je pomocí kódu týmu.',
        style: TextStyle(color: Colors.black54),
      );
    }

    final sorted = players.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final selectedCount = players.keys.where(_selectedPlayers.contains).length;
    final allSelected = selectedCount == players.length;

    return Card.outlined(
      child: Column(
        children: [
          CheckboxListTile(
            tristate: true,
            value: allSelected ? true : (selectedCount == 0 ? false : null),
            title: const Text(
              'Všichni hráči',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Vybráno $selectedCount z ${players.length}'),
            onChanged: (_) => setState(() {
              if (allSelected) {
                _selectedPlayers.removeAll(players.keys);
              } else {
                _selectedPlayers.addAll(players.keys);
              }
            }),
          ),
          const Divider(height: 1),
          for (final player in sorted)
            CheckboxListTile(
              value: _selectedPlayers.contains(player.key),
              title: Text(player.value),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedPlayers.add(player.key);
                } else {
                  _selectedPlayers.remove(player.key);
                }
              }),
            ),
        ],
      ),
    );
  }
}

/// Pole formuláře, které místo psaní otevře výběr (data / času).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final onClear = this.onClear;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Smazat',
                  onPressed: onClear,
                ),
        ),
        child: Text(value),
      ),
    );
  }
}
