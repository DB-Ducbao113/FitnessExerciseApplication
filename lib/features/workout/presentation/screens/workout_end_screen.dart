import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_details_screen.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

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

  double _calorieK(double speedKmh) {
    final isRunning = widget.activityType.toLowerCase().contains('run');
    double k = isRunning ? 1.05 : 0.92;
    if (speedKmh > 10) k += 0.05;
    if (speedKmh > 15) k += 0.05;
    return k;
  }

  double _getWeightKg() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return 60.0;
    final profileAsync = ref.read(userProfileProvider(userId));
    return profileAsync.valueOrNull?.weightKg ?? 60.0;
  }

  int? get _calories {
    final distance = double.tryParse(_distanceController.text);
    if (distance == null || distance <= 0) return null;
    final k = _calorieK(_speed ?? 0);
    return (_getWeightKg() * distance * k).round();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(workoutListProvider.notifier)
          .quickAddWorkout(
            activityType: widget.activityType,
            durationMinutes: widget.durationSeconds / 60.0,
          );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
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
    final userId = ref.watch(currentUserIdProvider);
    if (userId != null) ref.watch(userProfileProvider(userId));

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: const Text('Finish'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassCard(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withValues(alpha: 0.92),
                              _kNeonCyan,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 60,
                          color: _kBgTop,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Workout Completed!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.activityType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: _kMutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _MetricRow(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${_durationMinutes.toStringAsFixed(1)} min',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter distance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We will estimate speed and calories from your manual distance.',
                        style: TextStyle(
                          color: _kMutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _distanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Distance (km)',
                          hintText: '0.00',
                          labelStyle: const TextStyle(color: _kMutedText),
                          hintStyle: const TextStyle(color: _kMutedText),
                          prefixIcon: const Icon(
                            Icons.straighten_rounded,
                            color: _kNeonCyan,
                          ),
                          filled: true,
                          fillColor: const Color(0xff101a29),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _kCardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _kNeonCyan,
                              width: 1.5,
                            ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_speed != null)
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calculated metrics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _MetricRow(
                          icon: Icons.speed_rounded,
                          label: 'Average Speed',
                          value: '${_speed!.toStringAsFixed(1)} km/h',
                        ),
                        const SizedBox(height: 12),
                        _MetricRow(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Estimated Calories',
                          value: '${_calories ?? 0} kcal',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kNeonBlue, _kNeonCyan],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _kNeonCyan.withValues(alpha: 0.24),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: _kBgTop,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _kBgTop,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Workout',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
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
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xff101a29),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kNeonCyan, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: child,
    );
  }
}
