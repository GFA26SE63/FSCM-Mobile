import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// Vertical progress timeline ("Tiến trình").
class TimelineList extends StatelessWidget {
  const TimelineList(this.entries, {super.key});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i == entries.length - 1
                              ? AppColors.primary
                              : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i != entries.length - 1)
                        Expanded(
                            child:
                                Container(width: 2, color: AppColors.divider)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppDates.timeDay(entries[i].time),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        Text(
                          entries[i].delta.isEmpty
                              ? entries[i].label
                              : '${entries[i].label}  (${entries[i].delta})',
                          style: const TextStyle(height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
