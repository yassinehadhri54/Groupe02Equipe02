import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topWaveHeight = (constraints.maxHeight * 0.18)
                .clamp(54.0, 130.0)
                .toDouble();
            final bottomWaveHeight = (constraints.maxHeight * 0.12)
                .clamp(38.0, 88.0)
                .toDouble();

            return Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFFFF8F1)),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topWaveHeight,
                  child: SizedBox(
                    key: const ValueKey('auth-top-wave'),
                    child: const IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(painter: _AuthTopWavePainter()),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: bottomWaveHeight,
                  child: SizedBox(
                    key: const ValueKey('auth-bottom-wave'),
                    child: const IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(painter: _AuthBottomWavePainter()),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: topWaveHeight + 8),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('auth-scroll-view'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          width < 380 ? 20 : 28,
                          8,
                          width < 380 ? 20 : 28,
                          16,
                        ),
                        child: child,
                      ),
                    ),
                    SizedBox(height: bottomWaveHeight + 8),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: compact ? 52 : 70),
                child: Text(
                  '🌱',
                  style: TextStyle(fontSize: compact ? 34 : 38),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Campus',
                        style: TextStyle(color: AppTheme.burgundy),
                      ),
                      TextSpan(
                        text: 'Save',
                        style: TextStyle(color: AppTheme.gold),
                      ),
                    ],
                  ),
                  key: const ValueKey('auth-logo'),
                  style: TextStyle(
                    fontSize: compact ? 32 : 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Des repas de qualité, à petit prix\nsur ton campus',
                key: ValueKey('auth-slogan'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: _AuthFoodIllustration(
            key: const ValueKey('auth-illustration'),
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _AuthFoodIllustration extends StatelessWidget {
  const _AuthFoodIllustration({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = compact ? 0.82 : 1.0;

    return AspectRatio(
      aspectRatio: 0.9,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF5DEDA),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Text('🥖', style: TextStyle(fontSize: 61 * scale)),
          ),
          Positioned(
            top: 30,
            left: 2,
            child: Text('🥬', style: TextStyle(fontSize: 51 * scale)),
          ),
          Positioned(
            bottom: 8,
            right: 4,
            child: Text('🛍️', style: TextStyle(fontSize: 76 * scale)),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            child: Text('🍎', style: TextStyle(fontSize: 43 * scale)),
          ),
        ],
      ),
    );
  }
}

class _AuthTopWavePainter extends CustomPainter {
  const _AuthTopWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.28,
        size.width * 0.65,
        size.height * 0.70,
        size.width * 0.42,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.58,
        size.width * 0.12,
        size.height * 1.10,
        0,
        size.height * 0.72,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = AppTheme.burgundy);
  }

  @override
  bool shouldRepaint(covariant _AuthTopWavePainter oldDelegate) => false;
}

class _AuthBottomWavePainter extends CustomPainter {
  const _AuthBottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPath = Path()
      ..moveTo(0, size.height * 0.10)
      ..cubicTo(
        size.width * 0.25,
        size.height * 1.1,
        size.width * 0.55,
        size.height,
        size.width,
        size.height * 0.15,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(goldPath, Paint()..color = AppTheme.gold);

    final burgundyPath = Path()
      ..moveTo(size.width * 0.32, size.height)
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.92,
        size.width * 0.56,
        size.height * 0.04,
        size.width * 0.79,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.90,
        size.height * 0.67,
        size.width * 0.95,
        size.height * 0.86,
        size.width,
        size.height * 0.73,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(burgundyPath, Paint()..color = AppTheme.burgundy);
  }

  @override
  bool shouldRepaint(covariant _AuthBottomWavePainter oldDelegate) => false;
}
