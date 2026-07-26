import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

final appConnectionProvider = StreamProvider<bool>((ref) async* {
  final checker = InternetConnectionChecker();
  yield await checker.hasConnection;
  yield* checker.onStatusChange
      .map((status) => status == InternetConnectionStatus.connected)
      .distinct();
});
