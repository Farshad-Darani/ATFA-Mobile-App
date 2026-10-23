import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';
import '../services/diagnostic_analyzer.dart' as diag;

/// Dark gauge tile. Pass [parameter] to show a warning or critical status.
class GaugeWidget extends StatelessWidget {
  const GaugeWidget({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.color,
    this.minValue = 0,
    this.muted = false,
    this.parameter,
  });

  final String title;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final Color color;
  final bool muted;

  /// Analyzer key for the reading; null for informational gauges such as speed.
  final String? parameter;

  @override
  Widget build(BuildContext context) {
    final analyzer = diag.DiagnosticAnalyzer();
    final status = parameter == null
        ? null
        : analyzer.analyzeParameter(parameter!, value);
    final level = status?.level;
    final implausible = status?.implausible ?? false;
    final abnormal =
        level == diag.DiagnosticLevel.warning ||
        level == diag.DiagnosticLevel.critical;
    final label = abnormal
        ? analyzer.levelLabel(parameter!, value, level!)
        : null;

    // Lighter tones keep contrast on the navy surface; grey when paused.
    final levelColor = muted
        ? AppTheme.secondarySlate
        : (level == diag.DiagnosticLevel.critical
              ? AppTheme.errorRedLight
              : AppTheme.warningYellow);
    final arcColor = (muted || implausible)
        ? AppTheme.secondarySlate
        : (abnormal ? levelColor : color);
    final numberColor = (muted || implausible)
        ? AppTheme.secondarySlate
        : (abnormal ? levelColor : Colors.white);

    return Card(
      elevation: 4,
      color: AppTheme.primarySlate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: !muted && abnormal
              ? levelColor
              : Colors.white.withValues(alpha: 0.08),
          width: !muted && abnormal ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: 120,
              // Glide between readings so slower updates still look continuous.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: value),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, shown, _) => CustomPaint(
                  painter: GaugePainter(
                    progress: ((shown - minValue) / (maxValue - minValue))
                        .clamp(0.0, 1.0),
                    color: arcColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          shown.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: numberColor,
                              ),
                        ),
                        Text(
                          unit,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.secondarySlate),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Fixed height keeps both gauges the same size with or without a status.
            SizedBox(
              height: 28,
              child: Center(
                child: implausible
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.help_outline_rounded,
                            color: AppTheme.secondarySlate,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Unlikely value',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.secondarySlate,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      )
                    : abnormal && label != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            level == diag.DiagnosticLevel.critical
                                ? Icons.error_rounded
                                : Icons.warning_amber_rounded,
                            color: levelColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: levelColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      )
                    : (level == diag.DiagnosticLevel.normal
                          ? Text(
                              'Normal',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.secondarySlate),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Background arc
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75, // Start angle
      math.pi * 1.5, // Sweep angle
      false,
      backgroundPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75, // Start angle
      math.pi * 1.5 * progress, // Sweep angle based on progress
      false,
      progressPaint,
    );

    // Draw tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = -math.pi * 0.75 + (math.pi * 1.5 * i / 10);
      final startRadius = radius - 5;
      final endRadius = radius + 5;

      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + endRadius * math.cos(angle);
      final endY = center.dy + endRadius * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is GaugePainter &&
        (oldDelegate.progress != progress || oldDelegate.color != color);
  }
}
