import 'package:flutter/material.dart';
import '../services/diagnostic_analyzer.dart' as diag;
import '../config/app_theme.dart';

class DiagnosticDataCard extends StatelessWidget {
  final String title;
  final double value;
  final String parameter;
  final IconData icon;
  final VoidCallback? onTap;

  const DiagnosticDataCard({
    super.key,
    required this.title,
    required this.value,
    required this.parameter,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final analyzer = diag.DiagnosticAnalyzer();
    final status = analyzer.analyzeParameter(parameter, value);

    // Only show colored border for warnings and critical
    final showColoredBorder =
        status.level == diag.DiagnosticLevel.warning ||
        status.level == diag.DiagnosticLevel.critical;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: showColoredBorder ? status.color : Colors.grey[300]!,
          width: showColoredBorder ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => _showDetailDialog(context, status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: status.level == diag.DiagnosticLevel.normal
                        ? Colors.grey[600]
                        : status.color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusIndicator(status.level),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatValue(value, parameter),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: status.level == diag.DiagnosticLevel.normal
                          ? AppTheme.secondaryBlue
                          : status.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status.level == diag.DiagnosticLevel.normal
                      ? Colors.grey[600]
                      : status.color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(diag.DiagnosticLevel level) {
    late IconData iconData;
    late Color color;

    switch (level) {
      case diag.DiagnosticLevel.normal:
        return const SizedBox.shrink(); // No icon for normal - minimal design
      case diag.DiagnosticLevel.warning:
        iconData = Icons.warning;
        color = AppTheme.warningYellow;
        break;
      case diag.DiagnosticLevel.critical:
        iconData = Icons.error;
        color = AppTheme.errorRed;
        break;
      case diag.DiagnosticLevel.unknown:
        iconData = Icons.help;
        color = Colors.grey;
        break;
    }

    return Icon(iconData, color: color, size: 20);
  }

  String _formatValue(double value, String parameter) {
    String unit = _getUnit(parameter);

    switch (parameter) {
      case 'batteryVoltage':
        return '${value.toStringAsFixed(1)}$unit';
      case 'speed':
      case 'rpm':
      case 'coolantTemp':
      case 'throttlePosition':
      case 'engineLoad':
      case 'fuelLevel':
        return '${value.toInt()}$unit';
      default:
        return '${value.toStringAsFixed(1)}$unit';
    }
  }

  String _getUnit(String parameter) {
    switch (parameter) {
      case 'rpm':
        return ' RPM';
      case 'speed':
        return ' km/h';
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

  void _showDetailDialog(BuildContext context, diag.ParameterStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: status.color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Value: ${_formatValue(value, parameter)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${status.message}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Recommendation:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              status.recommendation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
