import 'package:flutter/material.dart';
import '../../core/app_features.dart';
import 'package:intl/intl.dart';
import '../../controllers/activity_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../repositories/activity_repository.dart';
import 'activity_form_screen.dart';

class ActivityDetailsScreen extends StatefulWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.controller,
    required this.activityId,
    required this.features,
  });
  final ActivityController controller;
  final String activityId;
  final AppFeatures features;
  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  String? _error;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir atividade?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-delete-activity'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _error = null);
    try {
      await widget.controller.delete(widget.activityId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Atividade excluída.')));
    } on ActivityFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _toggle() async {
    final activity = widget.controller.find(widget.activityId);
    if (activity == null) return;
    setState(() => _error = null);
    try {
      await widget.controller.setCompleted(activity.id, !activity.completed);
    } on ActivityFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final activity = widget.controller.find(widget.activityId);
      final busy = widget.controller.isSaving(widget.activityId);
      final discipline = widget.controller.disciplineFor(
        activity?.disciplineId,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Atividade'),
          actions: [
            IconButton(
              key: const Key('edit-activity'),
              tooltip: 'Editar atividade',
              onPressed: busy || activity == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => ActivityFormScreen(
                          controller: widget.controller,
                          features: widget.features,
                          activity: activity,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: const Key('delete-activity'),
              tooltip: 'Excluir atividade',
              onPressed: busy || activity == null ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: activity == null
            ? const Center(child: Text('Atividade não encontrada.'))
            : PageContent(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activity.type.label,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _field(
                      context,
                      'Data e horário',
                      DateFormat(
                        "dd/MM/yyyy 'às' HH:mm",
                      ).format(activity.dueAt),
                    ),
                    _field(
                      context,
                      'Situação',
                      activity.completed
                          ? 'Concluída'
                          : activity.isOverdueAt(DateTime.now())
                          ? 'Atrasada'
                          : 'Pendente',
                    ),
                    _field(context, 'Prioridade', activity.priority.label),
                    if (discipline != null)
                      _field(context, 'Disciplina', discipline.name),
                    if (activity.location.isNotEmpty)
                      _field(context, 'Local', activity.location),
                    if (activity.address != null)
                      _field(context, 'Endereço', activity.address!.formatted),
                    if (activity.latitude != null && activity.longitude != null)
                      _field(
                        context,
                        'Coordenadas capturadas',
                        'Latitude: ${activity.latitude!.toStringAsFixed(6)}\nLongitude: ${activity.longitude!.toStringAsFixed(6)}',
                      ),
                    _field(
                      context,
                      'Descrição',
                      activity.description.isEmpty
                          ? 'Sem descrição.'
                          : activity.description,
                    ),
                    if (_error != null) ...[
                      InlineMessage(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('toggle-activity'),
                      onPressed: busy ? null : _toggle,
                      icon: Icon(activity.completed ? Icons.undo : Icons.check),
                      label: Text(
                        busy
                            ? 'Salvando…'
                            : activity.completed
                            ? 'Marcar como pendente'
                            : 'Concluir atividade',
                      ),
                    ),
                  ],
                ),
              ),
      );
    },
  );
  Widget _field(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
