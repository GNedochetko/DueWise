import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/activity_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../core/widgets/sync_status_card.dart';
import '../../models/academic_activity.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.controller,
    required this.onOpenActivity,
    required this.onToggle,
  });
  final String name;
  final ActivityController controller;
  final ValueChanged<String> onOpenActivity;
  final ValueChanged<AcademicActivity> onToggle;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ActivityType? _type;
  ActivityStatus? _status;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final all = controller.activities;
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    bool sameDay(DateTime day) =>
        day.year == now.year && day.month == now.month && day.day == now.day;
    final counts = [
      all.where((item) => !item.completed && sameDay(item.dueAt)).length,
      all
          .where(
            (item) =>
                !item.completed &&
                !item.dueAt.isBefore(now) &&
                !item.dueAt.isAfter(end),
          )
          .length,
      all.where((item) => item.isOverdueAt(now)).length,
    ];
    final filtered = all
        .where(
          (item) =>
              (_type == null || item.type == _type) &&
              item.matchesStatus(_status, now),
        )
        .toList();
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;
    return PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            firstName.isEmpty ? 'Sua agenda' : 'Olá, $firstName',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now),
            style: const TextStyle(color: AppColors.muted),
          ),
          if (controller.syncState != null) ...[
            const SizedBox(height: 16),
            SyncStatusCard(
              state: controller.syncState!,
              onRetry: controller.syncNow,
            ),
          ],
          const SizedBox(height: 28),
          if (controller.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (controller.error != null) ...[
            InlineMessage(message: controller.error!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.load,
              child: const Text('Tentar novamente'),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontal =
                    constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18;
                Widget summary(int i) => Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${counts[i]}',
                        key: Key('summary-$i'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['Hoje', 'Próximos 7 dias', 'Atrasadas'][i],
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
                return Card(
                  child: horizontal
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < counts.length; i++) ...[
                                if (i > 0)
                                  const VerticalDivider(
                                    width: 1,
                                    color: AppColors.border,
                                  ),
                                Expanded(child: summary(i)),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < counts.length; i++) ...[
                              if (i > 0) const Divider(),
                              summary(i),
                            ],
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Atividades', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('filter-type'),
              initialValue: 'all',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Todos os tipos'),
                ),
                for (final type in ActivityType.values)
                  DropdownMenuItem(value: type.name, child: Text(type.label)),
              ],
              onChanged: (value) => setState(
                () => _type = value == 'all' || value == null
                    ? null
                    : ActivityType.values.byName(value),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('filter-status'),
              initialValue: 'all',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Situação'),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Todas as situações'),
                ),
                for (final status in ActivityStatus.values)
                  DropdownMenuItem(
                    value: status.name,
                    child: Text(status.label),
                  ),
              ],
              onChanged: (value) => setState(
                () => _status = value == 'all' || value == null
                    ? null
                    : ActivityStatus.values.byName(value),
              ),
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    all.isEmpty
                        ? 'Nenhuma atividade cadastrada. Use o botão + para começar.'
                        : 'Nenhuma atividade corresponde aos filtros.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              for (final activity in filtered) ...[
                ActivityTile(
                  activity: activity,
                  discipline: controller.disciplineFor(activity.disciplineId),
                  busy: controller.isSaving(activity.id),
                  onTap: () => widget.onOpenActivity(activity.id),
                  onToggle: controller.isSaving(activity.id)
                      ? null
                      : () => widget.onToggle(activity),
                ),
                const SizedBox(height: 12),
              ],
          ],
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
