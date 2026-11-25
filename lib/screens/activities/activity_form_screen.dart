import 'package:flutter/material.dart';
import '../../core/app_features.dart';
import '../../models/activity_address.dart';
import '../../repositories/device_features.dart';
import 'activity_location_editor.dart';
import 'activity_address_editor.dart';
import 'package:intl/intl.dart';
import '../../controllers/activity_controller.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../models/academic_activity.dart';
import '../../models/discipline.dart';
import '../../repositories/activity_repository.dart';
import 'discipline_dialog.dart';

class ActivityFormScreen extends StatefulWidget {
  const ActivityFormScreen({
    super.key,
    required this.controller,
    required this.features,
    this.activity,
    this.initialDate,
  });
  final ActivityController controller;
  final AppFeatures features;
  final AcademicActivity? activity;
  final DateTime? initialDate;
  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final String _id;
  late ActivityType _type;
  late ActivityPriority _priority;
  String? _disciplineId;
  late DateTime _dueAt;
  var _saving = false;
  var _capturing = false;
  var _lookingUp = false;
  Coordinates? _coordinates;
  ActivityAddress? _address;
  String? _error;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    _address = activity?.address;
    if (activity?.latitude != null && activity?.longitude != null) {
      _coordinates = Coordinates(activity!.latitude!, activity.longitude!);
    }
    _title = TextEditingController(text: activity?.title ?? '');
    _description = TextEditingController(text: activity?.description ?? '');
    _location = TextEditingController(text: activity?.location ?? '');
    _id = activity?.id ?? widget.controller.newId();
    _type = activity?.type ?? ActivityType.exam;
    _priority = activity?.priority ?? ActivityPriority.medium;
    _disciplineId = activity?.disciplineId;
    final suggested = DateTime.now().add(const Duration(hours: 1));
    final selected = widget.initialDate;
    _dueAt =
        activity?.dueAt ??
        (selected == null
            ? suggested
            : DateTime(
                selected.year,
                selected.month,
                selected.day,
                suggested.hour,
                suggested.minute,
              ));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day != null && mounted) {
      setState(
        () => _dueAt = DateTime(
          day.year,
          day.month,
          day.day,
          _dueAt.hour,
          _dueAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null && mounted) {
      setState(
        () => _dueAt = DateTime(
          _dueAt.year,
          _dueAt.month,
          _dueAt.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _createDiscipline() async {
    final discipline = await showDialog<Discipline>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DisciplineDialog(controller: widget.controller),
    );
    if (discipline != null && mounted) {
      setState(() => _disciplineId = discipline.id);
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _capturing ||
        _lookingUp ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final previous = widget.activity;
    final activity = AcademicActivity(
      id: _id,
      userId: widget.controller.userId,
      title: _title.text.trim(),
      disciplineId: _disciplineId,
      type: _type,
      description: _description.text.trim(),
      dueAt: _dueAt,
      priority: _priority,
      completed: previous?.completed ?? false,
      location: _location.text.trim(),
      latitude: _coordinates?.latitude,
      longitude: _coordinates?.longitude,
      address: _address,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await widget.controller.save(activity, isNew: previous == null);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              previous == null
                  ? 'Atividade cadastrada.'
                  : 'Atividade atualizada.',
            ),
          ),
        );
    } on ActivityFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.activity == null ? 'Nova atividade' : 'Editar atividade',
        ),
      ),
      body: PageContent(
        maxWidth: 560,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('activity-title'),
                controller: _title,
                enabled: !_saving,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o título da atividade.'
                    : null,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<ActivityType>(
                key: const Key('activity-type'),
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final type in ActivityType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _saving
                    ? null
                    : (type) {
                        if (type != null) setState(() => _type = type);
                      },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey('discipline-$_disciplineId'),
                initialValue: _disciplineId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Disciplina (opcional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Sem disciplina'),
                  ),
                  if (_disciplineId != null &&
                      !widget.controller.disciplines.any(
                        (d) => d.id == _disciplineId,
                      ))
                    DropdownMenuItem(
                      value: _disciplineId,
                      child: const Text('Disciplina indisponível'),
                    ),
                  for (final discipline in widget.controller.disciplines)
                    DropdownMenuItem(
                      value: discipline.id,
                      child: Text(
                        discipline.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) =>
                          setState(() => _disciplineId = id == '' ? null : id),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('new-discipline'),
                  onPressed: _saving ? null : _createDiscipline,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova disciplina'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data e horário',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('activity-date'),
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat('dd/MM/yyyy').format(_dueAt)),
                  ),
                  OutlinedButton.icon(
                    key: const Key('activity-time'),
                    onPressed: _saving ? null : _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(DateFormat('HH:mm').format(_dueAt)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<ActivityPriority>(
                key: const Key('activity-priority'),
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: [
                  for (final priority in ActivityPriority.values)
                    DropdownMenuItem(
                      value: priority,
                      child: Text(priority.label),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (priority) {
                        if (priority != null) {
                          setState(() => _priority = priority);
                        }
                      },
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('activity-description'),
                controller: _description,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('activity-location'),
                controller: _location,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Local (opcional)',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              ActivityLocationEditor(
                service: widget.features.location,
                initialValue: _coordinates,
                enabled: !_saving,
                onChanged: (value) => _coordinates = value,
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _capturing = busy);
                },
              ),
              const SizedBox(height: 20),
              ActivityAddressEditor(
                lookup: widget.features.addresses,
                initialValue: _address,
                enabled: !_saving,
                onChanged: (value) => _address = value,
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _lookingUp = busy);
                },
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                InlineMessage(message: _error!),
                const SizedBox(height: 16),
              ],
              FilledButton(
                key: const Key('save-activity'),
                onPressed: _saving || _capturing || _lookingUp ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar atividade'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
