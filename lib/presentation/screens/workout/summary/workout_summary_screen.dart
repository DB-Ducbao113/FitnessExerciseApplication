import 'package:flutter/material.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final int workoutId;
  final String activityType;
  final String trackingMode;
  final int durationSeconds;
  final double distanceMeters;
  final double avgPace;
  final int calories;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutId,
    required this.activityType,
    required this.trackingMode,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgPace,
    required this.calories,
  });

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0)
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0) return '-:--';
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
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
    final distanceKm = distanceMeters / 1000;
    final isOutdoor = trackingMode == 'outdoor';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Workout Summary'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Force them to use actions
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Static Map or Icon Header
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.blue[50],
              child: Center(
                child: isOutdoor
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.map, size: 100, color: Colors.blue[200]),
                          Text(
                            'Route Snapshot\n(Placeholder)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight:
                                  bool.fromEnvironment("dart.vm.product")
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        _getActivityIcon(activityType),
                        size: 120,
                        color: Colors.blue[300],
                      ),
              ),
            ),

            // Main Stats Card
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getActivityIcon(activityType),
                          color: const Color(0xff18b0e8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activityType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          distanceKm.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, left: 8),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'TIME',
                          value: _formatDuration(durationSeconds),
                        ),
                        if (isOutdoor)
                          _StatItem(
                            label: 'AVG PACE',
                            value: _formatPace(avgPace),
                          ),
                        _StatItem(label: 'CALORIES', value: '$calories kcal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Navigate to detailed analysis screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Detailed view coming soon!'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff18b0e8),
                        side: const BorderSide(
                          color: Color(0xff18b0e8),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'View Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // In a real app, this triggers the background sync loop
                        // Navigation pops back to home immediately to provide fast UX.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Saved to Server! 🎉'),
                            backgroundColor: Colors.green[600],
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff18b0e8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Save to Server',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
