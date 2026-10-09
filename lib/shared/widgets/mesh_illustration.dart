import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Phones linked to a hub, with a slow radar pulse. Static when the user has
/// turned animations off.
class MeshIllustration extends StatefulWidget {
  const MeshIllustration({super.key, this.size = 240});

  final double size;

  @override
  State<MeshIllustration> createState() => _MeshIllustrationState();
}

class _MeshIllustrationState extends State<MeshIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _MeshPainter(progress: _controller.value, scheme: scheme),
          ),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({required this.progress, required this.scheme});

  final double progress;
  final ColorScheme scheme;

  static const _peers = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Two expanding pulse rings, half a cycle apart.
    for (final phase in [progress, (progress + 0.5) % 1]) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = scheme.primary.withValues(alpha: 0.35 * (1 - phase));
      canvas.drawCircle(center, radius * (0.25 + 0.75 * phase), ring);
    }

    // Peers on a slowly turning orbit.
    final turn = progress * 2 * math.pi / 6;
    final peers = [
      for (var i = 0; i < _peers; i++)
        center +
            Offset.fromDirection(
              turn + i * 2 * math.pi / _peers,
              radius * (i.isEven ? 0.72 : 0.56),
            ),
    ];

    final link = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = scheme.outlineVariant;
    for (var i = 0; i < peers.length; i++) {
      canvas
        ..drawLine(center, peers[i], link)
        ..drawLine(peers[i], peers[(i + 1) % peers.length], link);
    }

    final colors = [scheme.tertiary, scheme.secondary, scheme.primary];
    for (var i = 0; i < peers.length; i++) {
      canvas
        ..drawCircle(peers[i], radius * 0.09, Paint()..color = scheme.surface)
        ..drawCircle(
          peers[i],
          radius * 0.07,
          Paint()..color = colors[i % colors.length],
        );
    }

    canvas
      ..drawCircle(
        center,
        radius * 0.2,
        Paint()..color = scheme.primaryContainer,
      )
      ..drawCircle(center, radius * 0.13, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.progress != progress || old.scheme != scheme;
}
