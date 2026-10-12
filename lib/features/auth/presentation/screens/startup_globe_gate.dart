/// Keeps the native globe visible for the initial Flutter frame before the
/// auth stream decides whether to show login, onboarding, or the main shell.
class StartupGlobeGate {
  bool _completed = false;

  bool get shouldShow => !_completed;

  void complete() => _completed = true;
}
