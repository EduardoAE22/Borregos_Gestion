import 'package:flutter/material.dart';

class BackgroundWatermark extends StatelessWidget {
  const BackgroundWatermark({
    super.key,
    required this.logoPathOrUrl,
    this.opacity = 0.07,
    this.widthFactor = 0.55,
  });

  final String logoPathOrUrl;
  final double opacity;
  final double widthFactor;

  bool get _isNetworkImage {
    return logoPathOrUrl.startsWith('http://') ||
        logoPathOrUrl.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final safeOpacity = opacity.clamp(0.05, 0.10);
    final safeWidthFactor = widthFactor.clamp(0.2, 0.9);

    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: safeOpacity,
          child: FractionallySizedBox(
            widthFactor: safeWidthFactor,
            child: _isNetworkImage
                ? Image.network(
                    logoPathOrUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.asset(
                    logoPathOrUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    );
  }
}

class WatermarkedBody extends StatelessWidget {
  const WatermarkedBody({
    super.key,
    required this.child,
    this.logoPathOrUrl = 'assets/branding/borregos_logo.png',
    this.opacity = 0.07,
  });

  final Widget child;
  final String logoPathOrUrl;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackgroundWatermark(
            logoPathOrUrl: logoPathOrUrl,
            opacity: opacity,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
