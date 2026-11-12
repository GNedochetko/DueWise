import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../controllers/activity_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../models/academic_activity.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.controller,
    required this.onOpenActivity,
    required this.onToggle,
  });
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ActivityController controller;
  final ValueChanged<String> onOpenActivity;
  final ValueChanged<AcademicActivity> onToggle;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<AcademicActivity>>{};
    for (final activity in widget.controller.activities) {
      final day = DateTime(
        activity.dueAt.year,
        activity.dueAt.month,
        activity.dueAt.day,
      );
      (grouped[day] ??= []).add(activity);
    }
    List<AcademicActivity> activitiesOn(DateTime date) =>
        grouped[DateTime(date.year, date.month, date.day)] ?? [];
    final selected = activitiesOn(widget.selectedDay);
    return PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<AcademicActivity>(
                locale: 'pt_BR',
                firstDay: DateTime(2000),
                lastDay: DateTime(2100, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                eventLoader: activitiesOn,
                selectedDayPredicate: (day) =>
                    isSameDay(day, widget.selectedDay),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                  widget.onDaySelected(selectedDay);
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: AppColors.paleBlue,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: AppColors.primary),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            DateFormat("d 'de' MMMM", 'pt_BR').format(widget.selectedDay),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (widget.controller.loading)
            const Center(child: CircularProgressIndicator())
          else if (widget.controller.error != null) ...[
            InlineMessage(message: widget.controller.error!),
            OutlinedButton(
              onPressed: widget.controller.load,
              child: const Text('Tentar novamente'),
            ),
          ] else if (selected.isEmpty)
            const Text(
              'Nenhuma atividade nesta data.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final activity in selected) ...[
              ActivityTile(
                activity: activity,
                discipline: widget.controller.disciplineFor(
                  activity.disciplineId,
                ),
                busy: widget.controller.isSaving(activity.id),
                onTap: () => widget.onOpenActivity(activity.id),
                onToggle: widget.controller.isSaving(activity.id)
                    ? null
                    : () => widget.onToggle(activity),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
