import 'package:flutter/material.dart';
import '../services/diagnostic_analyzer.dart' as diag;
import '../config/app_theme.dart';

class VehicleHealthSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? aiInsight;
  final bool aiInsightLoading;
  final VoidCallback? onAskAI;
  final bool isPaused;
  final bool isSavedSnapshot;

  const VehicleHealthSummary({
    super.key,
    required this.data,
    this.aiInsight,
    this.aiInsightLoading = false,
    this.onAskAI,
    this.isPaused = false,
    this.isSavedSnapshot = false,
  });

  @override
  Widget build(BuildContext context) {
    final analyzer = diag.DiagnosticAnalyzer();
    final healthReport = analyzer.analyzeVehicleHealth(data);
    final isArchivedState = isPaused || isSavedSnapshot;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getHealthGradientColors(healthReport.healthScore),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _getHealthIcon(healthReport.overallStatus),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vehicle Health Score',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isArchivedState)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      isSavedSnapshot ? 'SAVED' : 'PAUSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: healthReport.healthScore / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${healthReport.healthScore.toInt()}%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusIndicator(
                  context,
                  'Critical',
                  healthReport.criticalIssues,
                  AppTheme.errorRed,
                  Icons.error,
                ),
                _buildStatusIndicator(
                  context,
                  'Warnings',
                  healthReport.warnings,
                  AppTheme.warningYellow,
                  Icons.warning,
                ),
                _buildStatusIndicator(
                  context,
                  'Normal',
                  healthReport.normalParameters,
                  Colors.grey[400]!,
                  Icons.check_circle_outline,
                ),
              ],
            ),
            if (aiInsightLoading || aiInsight != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white54),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'AI Insight',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (aiInsightLoading)
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  aiInsight!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              if (onAskAI != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onAskAI,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ask AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ] else if (healthReport.recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white54),
              const SizedBox(height: 8),
              Text(
                'Recommendations:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...healthReport.recommendations
                  .take(2)
                  .map(
                    (rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.white)),
                          Expanded(
                            child: Text(
                              rec,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  List<Color> _getHealthGradientColors(double healthScore) {
    if (isPaused || isSavedSnapshot) {
      return [const Color(0xFF5B6D85), const Color(0xFF7A879B)];
    }
    if (healthScore >= 80) {
      return [AppTheme.primaryBlue, AppTheme.secondaryBlue];
    } else if (healthScore >= 60) {
      return [AppTheme.accentOrange, const Color(0xFFFFB74D)];
    } else {
      return [AppTheme.errorRed, AppTheme.errorRedLight];
    }
  }

  IconData _getHealthIcon(diag.DiagnosticLevel status) {
    switch (status) {
      case diag.DiagnosticLevel.normal:
        return Icons.verified;
      case diag.DiagnosticLevel.warning:
        return Icons.warning;
      case diag.DiagnosticLevel.critical:
        return Icons.emergency;
      case diag.DiagnosticLevel.unknown:
        return Icons.help;
    }
  }
}
