import 'package:flutter/material.dart';
import '../services/diagnostic_analyzer.dart' as diag;
import '../config/app_theme.dart';

class VehicleHealthSummary extends StatelessWidget {
  final Map<String, dynamic> data;

  const VehicleHealthSummary({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final analyzer = diag.DiagnosticAnalyzer();
    final healthReport = analyzer.analyzeVehicleHealth(data);

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
            if (healthReport.recommendations.isNotEmpty) ...[
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
                          const Text(
                            '• ',
                            style: TextStyle(color: Colors.white),
                          ),
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
                  )
                  .toList(),
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
    if (healthScore >= 80) {
      return [AppTheme.primaryBlue, AppTheme.secondaryBlue];
    } else if (healthScore >= 60) {
      return [AppTheme.warningYellow, AppTheme.warningYellowLight];
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
