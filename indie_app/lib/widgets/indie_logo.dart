import 'package:flutter/material.dart';

/// The Indie "in" mark — the icon only, used in app bars, splash and headers.
class IndieMark extends StatelessWidget {
  final double size;
  const IndieMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/indie_icon.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Full lockup: mark + "indie" wordmark + tagline. Used on splash/onboarding.
class IndieFullLogo extends StatelessWidget {
  final double width;
  const IndieFullLogo({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/indie_logo_full.png',
      width: width,
      filterQuality: FilterQuality.high,
    );
  }
}
