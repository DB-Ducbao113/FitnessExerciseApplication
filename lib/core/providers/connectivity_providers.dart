import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

final appConnectionProvider = StreamProvider<bool>((ref) {
  final checker = InternetConnectionChecker.createInstance();
  final controller = StreamController<bool>();

  checker.hasConnection.then((connected) {
    if (!controller.isClosed) {
      controller.add(connected);
    }
  }).catchError((err, stack) {
    if (!controller.isClosed) {
      controller.add(false);
    }
  });

  final subscription = checker.onStatusChange
      .map((status) => status == InternetConnectionStatus.connected)
      .distinct()
      .listen(
        (connected) {
          if (!controller.isClosed) {
            controller.add(connected);
          }
        },
        onError: (err, stack) {
          if (!controller.isClosed) {
            controller.add(false);
          }
        },
      );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});
