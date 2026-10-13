import 'package:flutter/material.dart';

/// Temporary compatibility layer for the two legacy Stitch auth forms.
///
/// Those forms specify their complete dark palette inline.  Applying the
/// inverse matrix in light mode keeps every foreground/background pair
/// readable while the forms are migrated to Kinetic tokens.
class AuthThemeSurface extends StatelessWidget {
  const AuthThemeSurface({super.key, required this.child});

  final Widget child;

  static const _identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _lightPalette = <double>[
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(
        Theme.of(context).brightness == Brightness.light
            ? _lightPalette
            : _identity,
      ),
      child: child,
    );
  }
}
