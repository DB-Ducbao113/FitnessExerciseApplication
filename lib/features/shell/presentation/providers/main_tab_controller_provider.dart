import 'package:flutter_riverpod/flutter_riverpod.dart';

const int homeTabIndex = 0;
const int activityTabIndex = 1;
const int historyTabIndex = 2;
const int analyticsTabIndex = 3;
const int profileTabIndex = 4;

final mainTabControllerProvider = StateProvider<int>((ref) => homeTabIndex);
