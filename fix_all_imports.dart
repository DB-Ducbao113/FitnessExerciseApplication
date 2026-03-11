import 'dart:io';

void main() async {
  final libDir = Directory(
    'c:\\IU\\PreThesis\\fitness_exercise_application\\lib',
  );
  if (!libDir.existsSync()) {
    print('lib directory not found');
    exit(1);
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final Map<String, String> replacements = {
    'presentation/screens/auth/': 'features/auth/screens/',
    'presentation/screens/home/': 'features/home/screens/',
    'presentation/widgets/home/': 'features/home/screens/widgets/',
    'presentation/screens/workout/': 'features/workout/screens/',
    'presentation/screens/history/': 'features/history/screens/',
    'presentation/screens/statistics/': 'features/statistics/screens/',
    'presentation/screens/stats/': 'features/statistics/screens/',
    'presentation/screens/profile/': 'features/profile/screens/',
    'presentation/screens/settings/': 'features/settings/screens/',
    'presentation/providers/': 'providers/',
    'domain/entities/': 'models/',
    'data/models/': 'models/',
    'domain/repositories/': 'repositories/',
    'data/repositories/': 'repositories/',
    'data/datasources/': 'services/datasources/',
    'data/local/': 'services/local/',
    'data/services/': 'services/',
    'core/services/': 'services/',
  };

  int updatedFiles = 0;

  for (final file in files) {
    String originalContent = file.readAsStringSync();
    String newContent = originalContent;

    for (final entry in replacements.entries) {
      newContent = newContent.replaceAll(
        'package:fitness_exercise_application/${entry.key}',
        'package:fitness_exercise_application/${entry.value}',
      );
    }

    if (newContent != originalContent) {
      file.writeAsStringSync(newContent);
      updatedFiles++;
    }
  }

  print('Second pass completed: updated $updatedFiles files.');
}
