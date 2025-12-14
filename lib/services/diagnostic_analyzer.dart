import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class DiagnosticAnalyzer {
  static final DiagnosticAnalyzer _instance = DiagnosticAnalyzer._internal();
  factory DiagnosticAnalyzer() => _instance;
  DiagnosticAnalyzer._internal();

  // Automotive parameter ranges and analysis
  static const Map<String, ParameterRange> _parameterRanges = {
    'rpm': ParameterRange(
      normal: RangeValues(700, 3000),
      warning: RangeValues(3000, 4500),
      critical: RangeValues(4500, 6500),
      unit: 'RPM',
      description: 'Engine Revolution Per Minute',
    ),
    'speed': ParameterRange(
      normal: RangeValues(0, 120),
      warning: RangeValues(120, 160),
      critical: RangeValues(160, 250),
      unit: 'km/h',
      description: 'Vehicle Speed',
    ),
    'coolantTemp': ParameterRange(
      normal: RangeValues(80, 95),
      warning: RangeValues(95, 105),
      critical: RangeValues(105, 130),
      unit: '°C',
      description: 'Engine Coolant Temperature',
    ),
    'throttlePosition': ParameterRange(
      normal: RangeValues(0, 80),
      warning: RangeValues(80, 95),
      critical: RangeValues(95, 100),
      unit: '%',
      description: 'Throttle Position Sensor',
    ),
    'batteryVoltage': ParameterRange(
      normal: RangeValues(12.2, 14.4),
      warning: RangeValues(11.8, 12.2),
      critical: RangeValues(10.0, 11.8),
      unit: 'V',
      description: 'Battery Voltage',
    ),
    'engineLoad': ParameterRange(
      normal: RangeValues(20, 70),
      warning: RangeValues(70, 85),
      critical: RangeValues(85, 100),
      unit: '%',
      description: 'Engine Load',
    ),
    'fuelLevel': ParameterRange(
      normal: RangeValues(25, 100),
      warning: RangeValues(10, 25),
      critical: RangeValues(0, 10),
      unit: '%',
      description: 'Fuel Level',
    ),
  };

  /// Analyze a parameter value and return its status
  ParameterStatus analyzeParameter(String parameter, double value) {
    final range = _parameterRanges[parameter];
    if (range == null) {
      return ParameterStatus(
        level: DiagnosticLevel.unknown,
        color: Colors.grey,
        message: 'Unknown parameter',
        recommendation: 'No analysis available',
      );
    }

    if (_isInRange(value, range.critical)) {
      return ParameterStatus(
        level: DiagnosticLevel.critical,
        color: AppTheme.errorRed,
        message: _getCriticalMessage(parameter, value),
        recommendation: _getCriticalRecommendation(parameter),
      );
    } else if (_isInRange(value, range.warning)) {
      return ParameterStatus(
        level: DiagnosticLevel.warning,
        color: AppTheme.warningYellow,
        message: _getWarningMessage(parameter, value),
        recommendation: _getWarningRecommendation(parameter),
      );
    } else if (_isInRange(value, range.normal)) {
      return ParameterStatus(
        level: DiagnosticLevel.normal,
        color: Colors.grey[600]!,
        message: 'Normal range',
        recommendation: 'Continue monitoring',
      );
    } else {
      return ParameterStatus(
        level: DiagnosticLevel.unknown,
        color: Colors.grey,
        message: 'Out of expected range',
        recommendation: 'Check sensor calibration',
      );
    }
  }

  /// Analyze overall vehicle health
  VehicleHealthReport analyzeVehicleHealth(Map<String, dynamic> data) {
    List<ParameterStatus> analyses = [];
    int criticalCount = 0;
    int warningCount = 0;
    int normalCount = 0;

    for (final entry in data.entries) {
      if (entry.value is num) {
        final status = analyzeParameter(entry.key, entry.value.toDouble());
        analyses.add(status);

        switch (status.level) {
          case DiagnosticLevel.critical:
            criticalCount++;
            break;
          case DiagnosticLevel.warning:
            warningCount++;
            break;
          case DiagnosticLevel.normal:
            normalCount++;
            break;
          case DiagnosticLevel.unknown:
            break;
        }
      }
    }

    // Calculate health score (0-100)
    int totalParameters = criticalCount + warningCount + normalCount;
    double healthScore = totalParameters > 0
        ? ((normalCount * 100 + warningCount * 50 + criticalCount * 0) /
                  totalParameters) /
              100 *
              100
        : 100.0;

    return VehicleHealthReport(
      healthScore: healthScore,
      criticalIssues: criticalCount,
      warnings: warningCount,
      normalParameters: normalCount,
      analyses: analyses,
      overallStatus: _getOverallStatus(criticalCount, warningCount),
      recommendations: _getOverallRecommendations(criticalCount, warningCount),
    );
  }

  bool _isInRange(double value, RangeValues range) {
    return value >= range.start && value <= range.end;
  }

  String _getCriticalMessage(String parameter, double value) {
    switch (parameter) {
      case 'coolantTemp':
        return 'Engine overheating! Temperature: ${value.toInt()}°C';
      case 'batteryVoltage':
        return 'Battery critically low: ${value.toStringAsFixed(1)}V';
      case 'rpm':
        return 'Engine over-revving: ${value.toInt()} RPM';
      case 'fuelLevel':
        return 'Fuel critically low: ${value.toInt()}%';
      default:
        return 'Critical level detected';
    }
  }

  String _getWarningMessage(String parameter, double value) {
    switch (parameter) {
      case 'coolantTemp':
        return 'Engine running hot: ${value.toInt()}°C';
      case 'batteryVoltage':
        return 'Battery voltage low: ${value.toStringAsFixed(1)}V';
      case 'engineLoad':
        return 'High engine load: ${value.toInt()}%';
      case 'fuelLevel':
        return 'Low fuel: ${value.toInt()}%';
      default:
        return 'Attention needed';
    }
  }

  String _getCriticalRecommendation(String parameter) {
    switch (parameter) {
      case 'coolantTemp':
        return 'STOP driving immediately! Check coolant system.';
      case 'batteryVoltage':
        return 'Check charging system and battery condition.';
      case 'rpm':
        return 'Reduce throttle, check transmission.';
      case 'fuelLevel':
        return 'Refuel immediately to avoid engine damage.';
      default:
        return 'Seek immediate professional diagnosis.';
    }
  }

  String _getWarningRecommendation(String parameter) {
    switch (parameter) {
      case 'coolantTemp':
        return 'Monitor closely, check coolant level.';
      case 'batteryVoltage':
        return 'Test battery and alternator soon.';
      case 'engineLoad':
        return 'Consider reducing load or checking engine.';
      case 'fuelLevel':
        return 'Plan to refuel soon.';
      default:
        return 'Monitor parameter closely.';
    }
  }

  DiagnosticLevel _getOverallStatus(int critical, int warning) {
    if (critical > 0) return DiagnosticLevel.critical;
    if (warning > 0) return DiagnosticLevel.warning;
    return DiagnosticLevel.normal;
  }

  List<String> _getOverallRecommendations(int critical, int warning) {
    List<String> recommendations = [];

    if (critical > 0) {
      recommendations.add('⚠️ URGENT: Address critical issues immediately');
      recommendations.add('🛑 Consider stopping driving until issues resolved');
    }

    if (warning > 0) {
      recommendations.add('⚡ Schedule maintenance for warning items');
      recommendations.add('📊 Monitor parameters closely');
    }

    if (critical == 0 && warning == 0) {
      recommendations.add('✅ Vehicle systems operating normally');
      recommendations.add('🔧 Continue regular maintenance schedule');
    }

    return recommendations;
  }
}

class ParameterRange {
  final RangeValues normal;
  final RangeValues warning;
  final RangeValues critical;
  final String unit;
  final String description;

  const ParameterRange({
    required this.normal,
    required this.warning,
    required this.critical,
    required this.unit,
    required this.description,
  });
}

class ParameterStatus {
  final DiagnosticLevel level;
  final Color color;
  final String message;
  final String recommendation;

  const ParameterStatus({
    required this.level,
    required this.color,
    required this.message,
    required this.recommendation,
  });
}

class VehicleHealthReport {
  final double healthScore;
  final int criticalIssues;
  final int warnings;
  final int normalParameters;
  final List<ParameterStatus> analyses;
  final DiagnosticLevel overallStatus;
  final List<String> recommendations;

  const VehicleHealthReport({
    required this.healthScore,
    required this.criticalIssues,
    required this.warnings,
    required this.normalParameters,
    required this.analyses,
    required this.overallStatus,
    required this.recommendations,
  });
}

enum DiagnosticLevel { normal, warning, critical, unknown }
