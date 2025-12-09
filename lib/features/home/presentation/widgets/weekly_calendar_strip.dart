import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class WeeklyCalendarStrip extends StatelessWidget {
  const WeeklyCalendarStrip({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.assignmentCountForDay,
    required this.milestoneCountForDay,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final int Function(DateTime day) assignmentCountForDay;
  final int Function(DateTime day) milestoneCountForDay;

  static final DateTime _firstDay = DateTime(2020);
  static final DateTime _lastDay = DateTime(2100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assignments & Calendar',
              style: theme.textTheme.titleLarge,
            ),
            Text(
              DateFormat.MMMd().format(focusedDay),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TableCalendar<void>(
          firstDay: _firstDay,
          lastDay: _lastDay,
          focusedDay: focusedDay,
          calendarFormat: CalendarFormat.week,
          availableGestures: AvailableGestures.horizontalSwipe,
          availableCalendarFormats: const {
            CalendarFormat.week: 'Week',
          },
          headerVisible: false,
          selectedDayPredicate: (day) => isSameDay(day, selectedDay),
          onDaySelected: (selected, focused) {
            onDaySelected(selected);
          },
          onPageChanged: onPageChanged,
          calendarStyle: CalendarStyle(
            markersAlignment: Alignment.bottomCenter,
            markerDecoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final assignments = assignmentCountForDay(day).clamp(0, 3);
              final milestones = milestoneCountForDay(day).clamp(0, 3);
              if (assignments == 0 && milestones == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < assignments; i++)
                      _Dot(color: theme.colorScheme.primary),
                    for (int i = 0; i < milestones; i++)
                      _Dot(color: theme.colorScheme.secondary),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
