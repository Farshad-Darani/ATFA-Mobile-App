import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../services/ai_service.dart';
import '../services/diagnostic_analyzer.dart' as diag;
import '../services/dtc_descriptions.dart';
import '../widgets/stat_card.dart';
import '../widgets/engine_codes_card.dart';
import '../widgets/engine_codes_sheet.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/status_card.dart';
import '../widgets/vehicle_health_summary.dart';
import '../config/app_theme.dart';

class LiveDataPage extends StatefulWidget {
  final VoidCallback? onNavigateToConnect;
  final VoidCallback? onNavigateToAI;

  const LiveDataPage({
    super.key,
    this.onNavigateToConnect,
    this.onNavigateToAI,
  });

  @override
  State<LiveDataPage> createState() => _LiveDataPageState();
}

class _LiveDataPageState extends State<LiveDataPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final bt_service.BluetoothService _bluetoothService =
      bt_service.BluetoothService();
  final _aiService = AiService();
  bool _polling = false;
  Map<String, dynamic> _currentData = {};
  bool _isDataStreaming = false;
  bool _isPaused = false;
  String? _aiInsight;
  bool _aiInsightLoading = false;
  DateTime? _lastInsightFetch;
  late AnimationController _rotationController;
  bool _useCelsius = true; // Temperature unit preference
  bool _useKmh = true; // Speed unit preference

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _bluetoothService.connectionState.addListener(_onConnectionChanged);
    // Cover an adapter that connected before this page was built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bluetoothService.isConnected) _startDataStream();
    });
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload preferences when navigating back to this tab
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCelsius = prefs.getBool('useCelsius') ?? true;
      _useKmh = prefs.getBool('useKmh') ?? true;
    });
  }

  double _convertSpeed(double kmh) {
    return _useKmh ? kmh : kmh * 0.621371; // Convert to mph
  }

  double _convertTemperature(double celsius) {
    return _useCelsius
        ? celsius
        : (celsius * 9 / 5) + 32; // Convert to Fahrenheit
  }

  String _getSpeedUnit() {
    return _useKmh ? 'km/h' : 'mph';
  }

  String _getTemperatureUnit() {
    return _useCelsius ? '°C' : '°F';
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (_bluetoothService.connectionState.value) {
      _startDataStream();
    } else {
      _stopDataStream();
    }
  }

  void _startDataStream() {
    setState(() {
      _isDataStreaming = true;
      _isPaused = false;
    });
    _pollLoop();
  }

  // Back-to-back polling: the next read starts as soon as the last one ends.
  Future<void> _pollLoop() async {
    if (_polling) return;
    _polling = true;
    while (mounted && _isDataStreaming && !_isPaused) {
      if (!_bluetoothService.isConnected) {
        _stopDataStream();
        break;
      }
      try {
        final data = await _bluetoothService.getRealTimeData();
        if (!mounted) break;
        if (data.isEmpty) {
          // Another caller is mid-read; wait briefly instead of spinning.
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }
        setState(() => _currentData = data);
        _logReadings(data);
        _maybeRefreshInsight();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    _polling = false;
  }

  // Debug-only trace of each reading and how it is classified.
  void _logReadings(Map<String, dynamic> data) {
    if (!kDebugMode) return;
    final analyzer = diag.DiagnosticAnalyzer();
    final parts = <String>[];
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is num) {
        final level = analyzer.analyzeParameter(entry.key, v.toDouble()).level;
        parts.add('${entry.key}=$v:${level.name}');
      } else {
        parts.add('${entry.key}=$v');
      }
    }
    debugPrint('[live] ${parts.join(' | ')}');
  }

  void _pauseDataStream() {
    _bluetoothService.setPaused(true);
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeDataStream() {
    _bluetoothService.setPaused(false);
    setState(() {
      _isPaused = false;
    });
    _pollLoop();
  }

  void _stopDataStream() {
    _bluetoothService.setPaused(false);
    setState(() {
      _isDataStreaming = false;
      _isPaused = false;
    });
  }

  // Refresh AI insight at most once every 30 seconds
  Future<void> _maybeRefreshInsight() async {
    final now = DateTime.now();
    if (_aiInsightLoading) return;
    if (_lastInsightFetch != null &&
        now.difference(_lastInsightFetch!).inSeconds < 30) {
      return;
    }
    _lastInsightFetch = now;
    setState(() => _aiInsightLoading = true);
    final insight = await _aiService.getQuickInsight(_currentData);
    if (mounted) {
      setState(() {
        _aiInsight = insight;
        _aiInsightLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isConnected = _bluetoothService.isConnected;
    final hasSavedSnapshot = !isConnected && _currentData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(isConnected, hasSavedSnapshot),
            if (!isConnected) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onNavigateToConnect,
                style: AppTheme.primaryButtonStyle,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(hasSavedSnapshot ? 'Reconnect' : 'Connect Adapter'),
              ),
            ],
            const SizedBox(height: 16),

            // Data Display
            Expanded(
              child: _currentData.isEmpty
                  ? _buildNoDataView()
                  : _buildDiagnosticDataView(hasSavedSnapshot),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isConnected, bool hasSavedSnapshot) {
    if (!isConnected) {
      return hasSavedSnapshot
          ? const StatusCard(
              icon: Icons.history,
              title: 'Saved snapshot',
              subtitle: 'Last reading from this session. Adapter disconnected.',
              color: AppTheme.secondarySlate,
            )
          : StatusCard(
              icon: Icons.bluetooth_disabled,
              title: 'Offline',
              subtitle: 'Connect your Atfa adapter to see live data',
              color: Colors.grey[500]!,
            );
    }
    if (_isPaused) {
      return StatusCard(
        icon: Icons.pause_circle_outline,
        title: 'Paused',
        subtitle: 'Readings are frozen',
        color: AppTheme.warningAmber,
        highlighted: true,
        trailing: _buildPauseButton(),
      );
    }
    if (_currentData.isEmpty) {
      return const StatusCard(
        icon: Icons.bluetooth_connected,
        title: 'Connected',
        subtitle: 'Waiting for vehicle data\u2026',
        color: AppTheme.successGreen,
        highlighted: true,
        pulse: true,
      );
    }
    final name = _bluetoothService.connectedDevice?.platformName ?? '';
    return StatusCard(
      icon: Icons.sensors,
      title: 'Live',
      subtitle: name.isNotEmpty ? name : 'Receiving data',
      color: AppTheme.successGreen,
      highlighted: true,
      pulse: true,
      trailing: _buildPauseButton(),
    );
  }

  // Tonal amber while paused so the button matches the card.
  Widget _buildPauseButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.filled(
      onPressed: _isPaused ? _resumeDataStream : _pauseDataStream,
      tooltip: _isPaused ? 'Resume' : 'Pause',
      icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      style: IconButton.styleFrom(
        backgroundColor: _isPaused
            ? AppTheme.warningAmber.withValues(alpha: 0.18)
            : (isDark ? AppTheme.secondarySlate : AppTheme.primarySlate),
        foregroundColor: _isPaused
            ? AppTheme.warningAmber
            : (isDark ? AppTheme.primarySlate : Colors.white),
        fixedSize: const Size(44, 44),
      ),
    );
  }

  Widget _buildNoDataView() {
    final isConnected = _bluetoothService.isConnected;
    final isWaitingForData = isConnected && _isDataStreaming;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isWaitingForData)
            RotationTransition(
              turns: _rotationController,
              child: Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            )
          else
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          if (isWaitingForData)
            _AnimatedDotsText(
              text: 'Waiting for vehicle data',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            )
          else ...[
            Text(
              'Live engine data appears here',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'RPM, speed, coolant temperature and more, as soon as your adapter is connected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _num(String key) => (_currentData[key] as num?)?.toDouble();

  Widget _plainCard(
    String key,
    String title,
    IconData icon,
    bool muted, {
    String? unit,
  }) {
    return StatCard(
      title: title,
      value: _num(key),
      parameter: key,
      icon: icon,
      muted: muted,
      unit: unit,
    );
  }

  // Fuel trims are signed; they are rated on how far they sit from zero.
  Widget _trimCard(String key, String title, bool muted) {
    final trim = _num(key);
    return StatCard(
      title: title,
      value: trim,
      analysisValue: trim?.abs(),
      parameter: 'fuelTrim',
      icon: Icons.tune,
      muted: muted,
      unit: '%',
    );
  }

  // Temperatures are analysed in Celsius and shown in the chosen unit.
  Widget _tempCard(String key, String title, IconData icon, bool muted) {
    final celsius = _num(key);
    return StatCard(
      title: title,
      value: celsius == null ? null : _convertTemperature(celsius),
      analysisValue: celsius,
      toDisplay: _convertTemperature,
      parameter: key,
      icon: icon,
      muted: muted,
      unit: _getTemperatureUnit(),
    );
  }

  Widget _buildDiagnosticDataView(bool hasSavedSnapshot) {
    final muted = _isPaused || hasSavedSnapshot;
    final supported = _bluetoothService.supportedPids;
    bool shows(int pid) => supported == null || supported.contains(pid);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vehicle Health Summary Card
          VehicleHealthSummary(
            data: _currentData,
            aiInsight: _aiInsight,
            aiInsightLoading: _aiInsightLoading,
            onAskAI: widget.onNavigateToAI,
            isPaused: _isPaused,
            isSavedSnapshot: hasSavedSnapshot,
          ),
          const SizedBox(height: 16),

          // Main gauges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GaugeWidget(
                  title: 'RPM',
                  value: _num('rpm'),
                  maxValue: 6000,
                  unit: 'rpm',
                  parameter: 'rpm',
                  color: AppTheme.accentOrange,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GaugeWidget(
                  title: 'Speed',
                  value: _num('speed') == null
                      ? null
                      : _convertSpeed(_num('speed')!),
                  maxValue: _useKmh ? 160 : 100,
                  unit: _getSpeedUnit(),
                  color: AppTheme.accentOrange,
                  muted: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cards are hidden for sensors the car does not report.
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              if (shows(0x05))
                _tempCard(
                  'coolantTemp',
                  'Coolant Temp',
                  Icons.thermostat,
                  muted,
                ),
              if (shows(0x11))
                _plainCard(
                  'throttlePosition',
                  'Throttle Position',
                  Icons.speed,
                  muted,
                ),
              _plainCard(
                'batteryVoltage',
                'Battery Voltage',
                Icons.battery_full,
                muted,
              ),
              if (shows(0x04))
                _plainCard(
                  'engineLoad',
                  'Engine Load',
                  Icons.fitness_center,
                  muted,
                ),
              if (shows(0x0F))
                _tempCard('intakeAirTemp', 'Intake Air Temp', Icons.air, muted),
              EngineCodesCard(
                muted: muted,
                onTap: () =>
                    showEngineCodesSheet(context, describe: describeDtc),
              ),
              if (shows(0x2F))
                _plainCard(
                  'fuelLevel',
                  'Fuel Level',
                  Icons.local_gas_station,
                  muted,
                ),
              if (shows(0x5C))
                _tempCard('oilTemp', 'Oil Temp', Icons.oil_barrel, muted),
              if (shows(0x06))
                _trimCard('shortTermFuelTrim', 'Short Fuel Trim', muted),
              if (shows(0x07))
                _trimCard('longTermFuelTrim', 'Long Fuel Trim', muted),
              if (shows(0x10))
                _plainCard(
                  'mafRate',
                  'Air Flow',
                  Icons.waves,
                  muted,
                  unit: 'g/s',
                ),
              if (shows(0x0B))
                _plainCard(
                  'manifoldPressure',
                  'Manifold Pressure',
                  Icons.compress,
                  muted,
                  unit: 'kPa',
                ),
              if (shows(0x0E))
                _plainCard(
                  'timingAdvance',
                  'Ignition Timing',
                  Icons.timer_outlined,
                  muted,
                  unit: '°',
                ),
              if (shows(0x46))
                _tempCard(
                  'ambientTemp',
                  'Outside Temp',
                  Icons.wb_sunny_outlined,
                  muted,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothService.connectionState.removeListener(_onConnectionChanged);
    _rotationController.dispose();
    super.dispose();
  }
}

// Animated dots widget for "Waiting for vehicle data..."
class _AnimatedDotsText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _AnimatedDotsText({required this.text, this.style});

  @override
  State<_AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<_AnimatedDotsText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      final newDotCount = (_controller.value * 4).floor() % 4;
      if (newDotCount != _dotCount) {
        setState(() {
          _dotCount = newDotCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.text, style: widget.style, textAlign: TextAlign.center),
        SizedBox(
          width: 24, // Fixed width for 3 dots
          child: Text(
            '.' * _dotCount,
            style: widget.style,
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }
}
