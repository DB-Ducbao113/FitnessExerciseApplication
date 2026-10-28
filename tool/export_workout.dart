// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const String _defaultSupabaseUrl = 'https://xsqptdzselqyefpmdozz.supabase.co';
const String _defaultAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzcXB0ZHpzZWxxeWVmcG1kb3p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNjU4MjEsImV4cCI6MjA4NTg0MTgyMX0.MfdUQpEDB4m5d7xv4wmjKf52sRmapewG-r1ecW6Hndk';

void main(List<String> args) async {
  String? workoutId;
  String? serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  String? userBearerToken = Platform.environment['AETRON_USER_TOKEN'];

  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '-w' || args[i] == '--workout-id') && i + 1 < args.length) {
      workoutId = args[++i];
    } else if ((args[i] == '-s' || args[i] == '--service-key') &&
        i + 1 < args.length) {
      serviceRoleKey = args[++i];
    } else if ((args[i] == '-t' || args[i] == '--token') &&
        i + 1 < args.length) {
      userBearerToken = args[++i];
    } else if (!args[i].startsWith('-') && workoutId == null) {
      workoutId = args[i];
    }
  }

  workoutId ??= 'fa1af1d3-b209-4649-b928-47bf6e4502f9';

  print('================================================================');
  print('🛰️  AETRON WORKOUT & RAW GPS DATA EXPORTER');
  print('================================================================');
  print('📌 Workout ID: $workoutId');

  // Try reading service role key from backend/.env if available
  if (serviceRoleKey == null || serviceRoleKey.trim().isEmpty) {
    final backendEnv = File('backend/.env');
    if (backendEnv.existsSync()) {
      for (final line in backendEnv.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) {
          final val = trimmed.substring('SUPABASE_SERVICE_ROLE_KEY='.length).trim();
          if (val.isNotEmpty && !val.contains('replace_with')) {
            serviceRoleKey = val;
            break;
          }
        }
      }
    }
  }

  final authToken = serviceRoleKey?.isNotEmpty == true
      ? serviceRoleKey
      : (userBearerToken?.isNotEmpty == true ? userBearerToken : _defaultAnonKey);

  print('🔑 Using Auth: ${serviceRoleKey?.isNotEmpty == true ? "Service Role Key (Admin - Bypasses RLS)" : (userBearerToken?.isNotEmpty == true ? "User Bearer Token" : "Anon Key (Subject to RLS)")}');

  final outputDir = Directory('exports/$workoutId');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final client = HttpClient();

  try {
    // 1. Fetch Workout metadata
    print('\n📥 Fetching Workout metadata from Supabase...');
    final workoutRows = await _fetchSupabaseTable(
      client: client,
      endpoint: 'workouts',
      filter: 'id=eq.$workoutId',
      authToken: authToken!,
    );

    if (workoutRows.isNotEmpty) {
      final workoutFile = File('${outputDir.path}/workout.json');
      workoutFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(workoutRows.first),
      );
      print('   ✅ Saved workout metadata -> ${workoutFile.path}');
    } else {
      print('   ⚠️  No rows found in "workouts" table with current auth key.');
    }

    // 2. Fetch Workout Session metadata
    print('\n📥 Fetching Workout Session from Supabase...');
    final sessionRows = await _fetchSupabaseTable(
      client: client,
      endpoint: 'workout_sessions',
      filter: 'id=eq.$workoutId',
      authToken: authToken,
    );

    if (sessionRows.isNotEmpty) {
      final sessionFile = File('${outputDir.path}/workout_session.json');
      sessionFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(sessionRows.first),
      );
      print('   ✅ Saved workout session -> ${sessionFile.path}');
    }

    // 3. Fetch Raw GPS Points
    print('\n📥 Fetching Raw GPS Points from Supabase...');
    final rawGpsRows = await _fetchSupabaseTable(
      client: client,
      endpoint: 'raw_gps_points',
      filter: 'workout_id=eq.$workoutId&order=timestamp.asc',
      authToken: authToken,
    );

    if (rawGpsRows.isNotEmpty) {
      final jsonFile = File('${outputDir.path}/raw_gps_points.json');
      jsonFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(rawGpsRows),
      );
      print('   ✅ Saved ${rawGpsRows.length} raw GPS points (JSON) -> ${jsonFile.path}');

      // Write CSV
      final csvFile = File('${outputDir.path}/raw_gps_points.csv');
      final sink = csvFile.openWrite();
      sink.writeln('index,timestamp,latitude,longitude,altitude,speed,accuracy,heading,device_source');
      for (var i = 0; i < rawGpsRows.length; i++) {
        final r = rawGpsRows[i];
        sink.writeln('$i,${r['timestamp']},${r['latitude']},${r['longitude']},${r['altitude'] ?? ''},${r['speed'] ?? ''},${r['accuracy'] ?? ''},${r['heading'] ?? ''},${r['device_source'] ?? ''}');
      }
      await sink.close();
      print('   ✅ Saved ${rawGpsRows.length} raw GPS points (CSV) -> ${csvFile.path}');

      // Print quick stats
      final firstTime = DateTime.tryParse(rawGpsRows.first['timestamp']?.toString() ?? '');
      final lastTime = DateTime.tryParse(rawGpsRows.last['timestamp']?.toString() ?? '');
      final duration = firstTime != null && lastTime != null
          ? lastTime.difference(firstTime).inSeconds
          : 0;

      final accuracies = rawGpsRows
          .map((r) => double.tryParse(r['accuracy']?.toString() ?? ''))
          .whereType<double>()
          .toList();
      accuracies.sort();

      print('\n📊 THỐNG KÊ RAW GPS ĐÃ THU THẬP:');
      print('   - Tổng số điểm Raw GPS: ${rawGpsRows.length}');
      print('   - Thời lượng ghi nhận: ${duration}s (~${(duration / 60.0).toStringAsFixed(1)} phút)');
      if (accuracies.isNotEmpty) {
        print('   - Độ chính xác tốt nhất (Min Accuracy): ${accuracies.first.toStringAsFixed(1)}m');
        print('   - Độ chính xác trung vị (Median Accuracy): ${accuracies[accuracies.length ~/ 2].toStringAsFixed(1)}m');
        print('   - Độ chính xác tệ nhất (Max Accuracy): ${accuracies.last.toStringAsFixed(1)}m');
      }
    } else {
      print('   ⚠️  0 Raw GPS points returned via REST API with current credentials.');
      print('   ℹ️  Gợi ý: Do Row Level Security (RLS), hãy sử dụng lệnh SQL bên dưới để chạy trực tiếp trên Supabase Dashboard!');
    }

    print('\n================================================================');
    print('💡 CÁC CÂU LỆNH SQL DÙNG TRÊN SUPABASE SQL EDITOR (CHẠY 100% OK):');
    print('================================================================');
    print('''
-- 1. Lấy thông tin tổng thể Workout:
SELECT * FROM public.workouts WHERE id = '$workoutId';

-- 2. Lấy toàn bộ tọa độ Raw GPS (bao gồm cả 300-400m đầu):
SELECT 
    id,
    workout_id,
    timestamp,
    latitude,
    longitude,
    altitude,
    speed,
    accuracy,
    heading,
    device_source
FROM public.raw_gps_points 
WHERE workout_id = '$workoutId' 
ORDER BY timestamp ASC;
''');
  } finally {
    client.close();
  }
}

Future<List<Map<String, dynamic>>> _fetchSupabaseTable({
  required HttpClient client,
  required String endpoint,
  required String filter,
  required String authToken,
}) async {
  final uri = Uri.parse('$_defaultSupabaseUrl/rest/v1/$endpoint?$filter&select=*');
  final request = await client.getUrl(uri);
  request.headers.set('apikey', _defaultAnonKey);
  request.headers.set('Authorization', 'Bearer $authToken');
  request.headers.set('Range-Unit', 'items');
  request.headers.set('Range', '0-9999');

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final parsed = jsonDecode(responseBody);
    if (parsed is List) {
      return parsed.cast<Map<String, dynamic>>();
    }
  } else {
    print('   ❌ HTTP ${response.statusCode}: $responseBody');
  }
  return [];
}
