import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:fitness_exercise_application/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/presentation/providers/user_profile_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile? existingProfile;

  const ProfileSetupScreen({super.key, this.existingProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _ageController;
  late String _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.existingProfile;
    _weightController = TextEditingController(
      text: profile?.weightKg.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: profile?.heightM.toString() ?? '',
    );
    _ageController = TextEditingController(text: profile?.age.toString() ?? '');
    _selectedGender = profile?.gender ?? 'male';
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Use existing ID if editing, otherwise generate new one
      final profileId = widget.existingProfile?.id ?? const Uuid().v4();
      // Keep existing createdAt if editing
      final createdAt = widget.existingProfile?.createdAt ?? DateTime.now();

      final profile = UserProfile(
        id: profileId,
        userId: user.id,
        weightKg: double.parse(_weightController.text),
        heightM: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        gender: _selectedGender,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(userProfileRepositoryProvider);

      if (widget.existingProfile != null) {
        // Update mode
        await repository.updateProfile(profile);
        // Invalidate provider to force refresh
        ref.invalidate(userProfileProvider(user.id));

        if (mounted) {
          Navigator.of(context).pop(); // Return to Profile Screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create mode: save profile then invalidate profile gate so
        // AuthWrapper automatically navigates → HomeScreen.
        await repository.createProfile(profile);
        // Invalidate the profile check — AuthWrapper will re-read and
        // route to HomeScreen once hasProfile returns true.
        ref.invalidate(hasUserProfileProvider(user.id));
        // No Navigator call here — AuthWrapper drives the transition.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Update Profile' : 'Complete Your Profile'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: isEditing, // Show back button if editing
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_outline,
                size: 80,
                color: Color(0xff18b0e8),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Update Personal Info' : 'Personal Information',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need this info to calculate accurate calories',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Weight
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: const Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight < 30 || weight > 300) {
                    return 'Weight must be between 30-300 kg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Height
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Height (m)',
                  hintText: 'e.g., 1.75',
                  prefixIcon: const Icon(Icons.height),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height';
                  }
                  final height = double.tryParse(value);
                  if (height == null || height < 1.0 || height > 2.5) {
                    return 'Height must be between 1.0-2.5 m';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age (years)',
                  prefixIcon: const Icon(Icons.cake),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age < 10 || age > 120) {
                    return 'Age must be between 10-120 years';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Gender
              const Text(
                'Gender',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Male'),
                      value: 'male',
                      groupValue: _selectedGender,
                      onChanged: (value) {
                        setState(() => _selectedGender = value!);
                      },
                      activeColor: const Color(0xff18b0e8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedGender == 'male'
                              ? const Color(0xff18b0e8)
                              : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Female'),
                      value: 'female',
                      groupValue: _selectedGender,
                      onChanged: (value) {
                        setState(() => _selectedGender = value!);
                      },
                      activeColor: const Color(0xff18b0e8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedGender == 'female'
                              ? const Color(0xff18b0e8)
                              : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff18b0e8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Update Profile' : 'Complete Setup',
                          style: const TextStyle(
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
