import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_exercise_application/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/screens/workout_details_screen.dart';

class WorkoutEndScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String activityType;
  final int durationSeconds;

  const WorkoutEndScreen({
    super.key,
    required this.sessionId,
    required this.activityType,
    required this.durationSeconds,
  });

  @override
  ConsumerState<WorkoutEndScreen> createState() => _WorkoutEndScreenState();
}

class _WorkoutEndScreenState extends ConsumerState<WorkoutEndScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  double get _durationMinutes => widget.durationSeconds / 60;

  double? get _speed {
    final distance = double.tryParse(_distanceController.text);
    if (distance == null || distance == 0) return null;
    return distance / (_durationMinutes / 60);
  }

  // ─── Calorie helpers (identical to record_providers._computeCalories) ────────
  //
  // IMPORTANT: this formula MUST stay in sync with _computeCalories() in
  // record_providers.dart so the end-screen, record screen, stats, and
  // calendar all show the same number for the same session.
  //
  // Formula: kcal = weight_kg × distance_km × k
  //   k ≈ 0.92  (walking base)  |  1.05 (running base)
  //   +0.05 if speed > 10 km/h  |  +0.05 if speed > 15 km/h

  // Default weight used when no profile loaded (60 kg). Override via
  // workout_providers.finishWorkout which uses the caller-supplied calories.
  static const double _kDefaultWeightKg = 60.0;

  double _calorieK(double speedKmh) {
    final isRunning = widget.activityType.toLowerCase().contains('run');
    double k = isRunning ? 1.05 : 0.92;
    if (speedKmh > 10) k += 0.05;
    if (speedKmh > 15) k += 0.05;
    return k;
  }

  int? get _calories {
    final distance = double.tryParse(_distanceController.text);
    if (distance == null || distance <= 0) return null;
    final k = _calorieK(_speed ?? 0);
    return (_kDefaultWeightKg * distance * k).round();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call provider to finish workout
      await ref
          .read(workoutListProvider.notifier)
          .quickAddWorkout(
            activityType: widget.activityType,
            durationMinutes: widget.durationSeconds / 60.0,
          );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            // TODO: We will need a way to reliably fetch the recently generated ID if navigating to details
            builder: (_) => WorkoutDetailsScreen(workoutId: widget.sessionId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving workout: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Workout'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Workout Completed!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.activityType.toUpperCase(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 32),

              // Duration (Auto-filled)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xff18b0e8)),
                      const SizedBox(width: 12),
                      const Text('Duration', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(
                        '${_durationMinutes.toStringAsFixed(1)} min',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Distance Input
              const Text(
                'Enter Distance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Distance (km)',
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.straighten),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter distance';
                  }
                  final distance = double.tryParse(value);
                  if (distance == null || distance <= 0) {
                    return 'Please enter a valid distance';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Calculated Metrics
              if (_speed != null) ...[
                const Text(
                  'Calculated Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _MetricRow(
                          icon: Icons.speed,
                          label: 'Average Speed',
                          value: '${_speed!.toStringAsFixed(1)} km/h',
                        ),
                        const Divider(),
                        _MetricRow(
                          icon: Icons.local_fire_department,
                          label: 'Estimated Calories',
                          value: '$_calories kcal',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff18b0e8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Workout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff18b0e8)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
