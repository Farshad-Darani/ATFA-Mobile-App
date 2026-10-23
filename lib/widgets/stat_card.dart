import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/diagnostic_analyzer.dart' as diag;

/// Dark stat tile that flips to show the normal range and a recommendation.
class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.parameter,
    required this.icon,
    this.unit,
    this.analysisValue,
    this.toDisplay,
    this.muted = false,
  });

  final String title;
  final double value;
  final String parameter;
  final IconData icon;
  final String? unit;

  /// Metric reading used for range checks when [value] is a converted display value.
  final double? analysisValue;

  /// Converts metric range bounds to the displayed unit.
  final double Function(double)? toDisplay;

  /// Paused or saved data: neutral colors, the status icon stays visible.
  final bool muted;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  static const _flipBackAfter = Duration(seconds: 8);
  static const _secondary = AppTheme.secondarySlate;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _autoFlipBack;

  bool get _showingBack =>
      _controller.status == AnimationStatus.forward ||
      _controller.status == AnimationStatus.completed;

  void _toggle() {
    HapticFeedback.selectionClick();
    _autoFlipBack?.cancel();
    if (_showingBack) {
      _controller.reverse();
    } else {
      _controller.forward();
      _autoFlipBack = Timer(_flipBackAfter, () {
        if (mounted) _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _autoFlipBack?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _defaultUnit(String parameter) {
    switch (parameter) {
      case 'rpm':
        return 'RPM';
      case 'speed':
        return 'km/h';
      case 'coolantTemp':
        return '°C';
      case 'throttlePosition':
      case 'engineLoad':
      case 'fuelLevel':
        return '%';
      case 'batteryVoltage':
        return 'V';
      default:
        return '';
    }
  }

  String _fmt(double v) => widget.parameter == 'batteryVoltage'
      ? v.toStringAsFixed(1)
      : '${v.round()}';

  @override
  Widget build(BuildContext context) {
    final analyzer = diag.DiagnosticAnalyzer();
    final reading = widget.analysisValue ?? widget.value;
    final status = analyzer.analyzeParameter(widget.parameter, reading);
    final range = analyzer.rangeFor(widget.parameter);

    final level = status.level;
    final implausible = status.implausible;
    final abnormal =
        level == diag.DiagnosticLevel.warning ||
        level == diag.DiagnosticLevel.critical;
    // Lighter tones keep contrast on the navy surface; grey when paused.
    final levelColor = widget.muted
        ? _secondary
        : (level == diag.DiagnosticLevel.critical
              ? AppTheme.errorRedLight
              : AppTheme.warningYellow);

    final label = analyzer.levelLabel(widget.parameter, reading, level);

    final unit = widget.unit ?? _defaultUnit(widget.parameter);
    final convert = widget.toDisplay ?? (double v) => v;
    final rangeText = range == null
        ? null
        : '${_fmt(convert(range.normal.start))}–${_fmt(convert(range.normal.end))}'
              '${unit.isEmpty ? '' : ' $unit'}';

    final front = _buildFront(
      context,
      level: level,
      abnormal: abnormal,
      levelColor: levelColor,
      label: label,
      unit: unit,
      implausible: implausible,
    );
    final back = _buildBack(
      context,
      level: level,
      abnormal: abnormal,
      levelColor: levelColor,
      label: label,
      rangeText: rangeText,
      implausible: implausible,
      recommendation: (level == diag.DiagnosticLevel.unknown && !implausible)
          ? 'No reference range is available for this reading.'
          : status.recommendation,
    );

    return Semantics(
      button: true,
      hint: 'Tap for details',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final angle = _controller.value * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: Card(
                elevation: 4,
                color: AppTheme.primarySlate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: !widget.muted && abnormal
                        ? levelColor
                        : Colors.white.withValues(alpha: 0.08),
                    width: !widget.muted && abnormal ? 2 : 1,
                  ),
                ),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: back,
                      )
                    : front,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusIcon(diag.DiagnosticLevel level, Color color, double size) {
    return Icon(
      level == diag.DiagnosticLevel.critical
          ? Icons.error_rounded
          : Icons.warning_amber_rounded,
      color: color,
      size: size,
    );
  }

  Widget _buildFront(
    BuildContext context, {
    required diag.DiagnosticLevel level,
    required bool abnormal,
    required Color levelColor,
    required String? label,
    required String unit,
    required bool implausible,
  }) {
    final theme = Theme.of(context);
    final valueColor = (widget.muted || implausible)
        ? _secondary
        : (abnormal ? levelColor : Colors.white);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 18, color: _secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _fmt(widget.value),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: valueColor,
                                        ),
                                  ),
                                  if (unit.isNotEmpty)
                                    TextSpan(
                                      text: ' $unit',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: _secondary),
                                    ),
                                ],
                              ),
                            ),
                            if (abnormal) ...[
                              const SizedBox(width: 8),
                              _statusIcon(level, levelColor, 24),
                            ] else if (implausible) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.help_outline_rounded,
                                size: 24,
                                color: _secondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (abnormal && label != null)
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.muted ? _secondary : levelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (implausible)
                        Text(
                          'Unlikely value',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (level == diag.DiagnosticLevel.normal)
                        Text(
                          'Normal',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Low-emphasis hint that the card flips.
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: _secondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(
    BuildContext context, {
    required diag.DiagnosticLevel level,
    required bool abnormal,
    required Color levelColor,
    required String? label,
    required String? rangeText,
    required bool implausible,
    required String recommendation,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.close_rounded, size: 18, color: _secondary),
              ],
            ),
            const SizedBox(height: 8),
            if (abnormal)
              Row(
                children: [
                  _statusIcon(level, levelColor, 18),
                  const SizedBox(width: 6),
                  Text(
                    label ?? 'Out of range',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else if (implausible)
              Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: _secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Unlikely value',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else if (level == diag.DiagnosticLevel.normal)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: _secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Normal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (rangeText != null) ...[
              const SizedBox(height: 8),
              Text(
                'Normal range',
                style: theme.textTheme.bodySmall?.copyWith(color: _secondary),
              ),
              Text(
                rangeText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              recommendation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
