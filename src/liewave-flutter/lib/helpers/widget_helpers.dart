import 'dart:math';
import 'package:flutter/material.dart';

// ----- Yardımcı Widget: Dalga animasyonu -----
class SoundWaveAnimation extends StatefulWidget {
  const SoundWaveAnimation({super.key});

  @override
  _SoundWaveAnimationState createState() => _SoundWaveAnimationState();
}

class _SoundWaveAnimationState extends State<SoundWaveAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int waveCount = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return CustomPaint(
            painter: WavePainter(animationValue: _controller.value, waveCount: waveCount),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final int waveCount;
  WavePainter({required this.animationValue, required this.waveCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.6)..strokeWidth = 3..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final waveWidth = size.width / waveCount;

    for (int i = 0; i < waveCount; i++) {
      final phase = (animationValue + i / waveCount) % 1.0;
      final amplitude = 10 * sin(phase * 2 * pi);
      final x = waveWidth * i + waveWidth / 2;

      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ----- Yardımcı Widget: Gradient Button -----
class GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  const GradientButton({super.key, 
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          backgroundColor: enabled ? null : theme.disabledColor,
          // Gradient için dekorasyona gerekirse Wrap yerine CustomButton eklenebilir
        ),
      ),
    );
  }
}

// ----- Yardımcı Widget: Animasyonlu Prediction Kartı -----
class AnimatedPredictionCard extends StatefulWidget {
  final String prediction;
  final String confidence;
  const AnimatedPredictionCard({super.key, required this.prediction, required this.confidence});

  @override
  _AnimatedPredictionCardState createState() => _AnimatedPredictionCardState();
}

class _AnimatedPredictionCardState extends State<AnimatedPredictionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _colorAnim = ColorTween(
      begin: Colors.transparent,
      end: widget.prediction.toLowerCase() == 'truth'
          ? Colors.green.withOpacity(0.3)
          : (widget.prediction.toLowerCase() == 'lie' ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
    ).animate(_controller);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) => Container(
        margin: const EdgeInsets.only(top: 36),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: _colorAnim.value,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _colorAnim.value?.withOpacity(0.5) ?? Colors.transparent,
              blurRadius: 20,
              spreadRadius: 1,
            )
          ],
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Prediction',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.prediction.toLowerCase() == 'truth'
                    ? Icons.check_circle_outline
                    : (widget.prediction.toLowerCase() == 'lie' ? Icons.cancel_outlined : Icons.info_outline),
                color: widget.prediction.toLowerCase() == 'truth'
                    ? Colors.green[700]
                    : (widget.prediction.toLowerCase() == 'lie' ? Colors.red[700] : Colors.blueAccent),
                size: 48,
              ),
              const SizedBox(width: 16),
              Text(
                widget.prediction,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: widget.prediction.toLowerCase() == 'truth'
                      ? Colors.green[700]
                      : (widget.prediction.toLowerCase() == 'lie' ? Colors.red[700] : Colors.blueAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Confidence',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.confidence,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

