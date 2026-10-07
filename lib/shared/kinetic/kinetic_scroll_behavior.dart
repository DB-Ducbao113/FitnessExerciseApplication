import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Global scroll behavior for the Aetron Kinetic design system.
///
/// Enables seamless drag-to-scroll across desktop platforms (macOS, Windows, Linux)
/// and Web for all pointer input types (mouse cursor drag, trackpad pan/drag,
/// touch, stylus) alongside modern kinetic bouncing scroll physics.
class KineticScrollBehavior extends MaterialScrollBehavior {
  const KineticScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Avoid asserting on desktop platforms when the Scrollable has no controller
    if (details.controller == null) {
      return child;
    }
    return super.buildScrollbar(context, child, details);
  }
}
