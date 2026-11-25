import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/academic_activity.dart';
import '../../models/discipline.dart';
import '../theme/app_theme.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onToggle,
    this.discipline,
    this.busy = false,
  });
  final AcademicActivity activity;
  final Discipline? discipline;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final overdue = activity.isOverdueAt(DateTime.now());
    final status = activity.completed
        ? 'Concluída'
        : overdue
        ? 'Atrasada'
        : 'Pendente';
    return Card(
      child: InkWell(
        key: Key('activity-${activity.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Checkbox(
                  key: Key('complete-${activity.id}'),
                  value: activity.completed,
                  semanticLabel: activity.completed
                      ? 'Reabrir ${activity.title}'
                      : 'Concluir ${activity.title}',
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: activity.completed ? AppColors.muted : null,
                        decoration: activity.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (discipline != null) ...[
                      Text(
                        discipline!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(discipline!.color)),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '${activity.type.label} · Prioridade ${activity.priority.label.toLowerCase()}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd/MM/yyyy • HH:mm').format(activity.dueAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: overdue
                            ? Theme.of(context).colorScheme.error
                            : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
