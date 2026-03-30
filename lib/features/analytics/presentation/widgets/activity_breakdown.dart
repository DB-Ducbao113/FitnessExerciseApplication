import 'package:flutter/material.dart';

class ActivityBreakdown extends StatelessWidget {
  final Map<String, int> activityCounts;

  const ActivityBreakdown({super.key, required this.activityCounts});

  Color _getActivityColor(String activity) {
    switch (activity.toLowerCase()) {
      case 'running':
        return const Color(0xffFF6B6B);
      case 'cycling':
        return const Color(0xff4ECDC4);
      case 'walking':
        return const Color(0xff95E1D3);
      default:
        return const Color(0xff18b0e8);
    }
  }

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activityCounts.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No activity data',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final total = activityCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...activityCounts.entries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(0);
              final color = _getActivityColor(entry.key);
              final icon = _getActivityIcon(entry.key);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${entry.value} ($percentage%)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
