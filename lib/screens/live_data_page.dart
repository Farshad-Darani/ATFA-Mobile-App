import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../services/ai_service.dart';
import '../widgets/diagnostic_data_card.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/vehicle_health_summary.dart';
import '../widgets/vehicle_offline_prompt.dart';
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
  Timer? _dataTimer;
  Map<String, dynamic> _currentData = {};
  bool _isDataStreaming = false;
  bool _isPaused = false;
  String? _aiInsight;
  bool _aiInsightLoading = false;
  DateTime? _lastInsightFetch;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotationController;
  bool _useCelsius = true; // Temperature unit preference
  bool _useKmh = true; // Speed unit preference

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    // Don't auto-start - let user control when to start
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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

  void _startDataStream() {
    setState(() {
      _isDataStreaming = true;
    });

    _dataTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDataFromDevice();
    });

    // Get initial data immediately
    _updateDataFromDevice();
  }

  void _updateDataFromDevice() {
    if (!_bluetoothService.isConnected) {
      _stopDataStream();
      return;
    }

    _bluetoothService
        .getRealTimeData()
        .then((data) {
          if (mounted && data.isNotEmpty) {
            setState(() {
              _currentData = data;
            });
            _maybeRefreshInsight();
          }
        })
        .catchError((error) {
          if (mounted) {
            // Keep existing data on error, just don't update time
          }
        });
  }

  void _pauseDataStream() {
    _dataTimer?.cancel();
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
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDataFromDevice();
    });
    _updateDataFromDevice();
  }

  void _stopDataStream() {
    _dataTimer?.cancel();
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
            // Connection Status Bar - Works for both connected and disconnected
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]!.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final actionWidth = constraints.maxWidth < 380 ? 132.0 : 156.0;

                  return Row(
                    children: [
                      // Animated pulse circle when live streaming, static otherwise
                      if (isConnected && _isDataStreaming && !_isPaused)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.8 + (_pulseAnimation.value * 0.4),
                              child: Opacity(
                                opacity: _pulseAnimation.value,
                                child: Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: AppTheme.accentOrange,
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: hasSavedSnapshot
                              ? Colors.blueGrey[400]
                              : _isPaused
                                  ? Colors.grey[400]
                                  : (isConnected
                                      ? AppTheme.accentOrange
                                      : Colors.grey[600]),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasSavedSnapshot
                              ? 'Saved snapshot'
                              : _isPaused
                                  ? 'Paused'
                                  : (isConnected ? 'Live' : 'Offline'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: actionWidth,
                        height: 48,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: !_isDataStreaming
                                ? ElevatedButton.icon(
                                    key: const ValueKey('start_live'),
                                    onPressed: isConnected ? _startDataStream : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isConnected
                                          ? AppTheme.primarySlate
                                          : Colors.grey[400],
                                      foregroundColor: isConnected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.wifi_tethering_rounded, size: 20),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Start Live',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  )
                                : _currentData.isEmpty
                                    ? Container(
                                        key: const ValueKey('connecting'),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppTheme.primarySlate.withValues(alpha: 0.10),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedBuilder(
                                              animation: _pulseAnimation,
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: 0.85 + (_pulseAnimation.value * 0.25),
                                                  child: Opacity(
                                                    opacity: _pulseAnimation.value,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: Icon(
                                                Icons.circle,
                                                size: 10,
                                                color: AppTheme.accentOrange,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Connecting live...',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Row(
                                        key: const ValueKey('live_controls'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _isPaused
                                                ? _resumeDataStream
                                                : _pauseDataStream,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _isPaused
                                                  ? AppTheme.primarySlate
                                                  : Colors.white,
                                              foregroundColor: _isPaused
                                                  ? Colors.white
                                                  : AppTheme.primarySlate,
                                              elevation: 0,
                                              side: BorderSide(
                                                color: _isPaused
                                                    ? AppTheme.primarySlate
                                                    : AppTheme.primarySlate.withValues(alpha: 0.15),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: Icon(
                                              _isPaused
                                                  ? Icons.play_arrow_rounded
                                                  : Icons.pause_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              _isPaused ? 'Resume' : 'Pause',
                                              maxLines: 1,
                                              softWrap: false,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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

  Widget _buildNoDataView() {
    final isConnected = _bluetoothService.isConnected;
    final isWaitingForData = isConnected && _isDataStreaming;

    if (!isConnected) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: VehicleOfflinePrompt(
            title: 'Vehicle is offline',
            message: 'Turn on Bluetooth and connect your vehicle before viewing live data and diagnostics.',
            actionLabel: 'Go to Connect',
            onAction: widget.onNavigateToConnect,
          ),
        ),
      );
    }

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
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          const SizedBox(height: 16),
          if (isWaitingForData)
            _AnimatedDotsText(
              text: 'Waiting for vehicle data',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            )
          else
            Text(
              'Press Start Diagnostics to begin',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticDataView(bool hasSavedSnapshot) {
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
                  value: (_currentData['rpm'] ?? 0).toDouble(),
                  maxValue: 6000,
                  unit: 'rpm',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GaugeWidget(
                  title: 'Speed',
                  value: _convertSpeed((_currentData['speed'] ?? 0).toDouble()),
                  maxValue: _useKmh ? 160 : 100,
                  unit: _getSpeedUnit(),
                  color: AppTheme.primarySlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnostic data cards grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              DiagnosticDataCard(
                title: 'Coolant Temp',
                value: _convertTemperature(
                  (_currentData['coolantTemp'] ?? 0).toDouble(),
                ),
                parameter: 'coolantTemp',
                icon: Icons.thermostat,
                unit: _getTemperatureUnit(),
              ),
              DiagnosticDataCard(
                title: 'Throttle Position',
                value: (_currentData['throttlePosition'] ?? 0).toDouble(),
                parameter: 'throttlePosition',
                icon: Icons.speed,
              ),
              DiagnosticDataCard(
                title: 'Battery Voltage',
                value: (_currentData['batteryVoltage'] ?? 0).toDouble(),
                parameter: 'batteryVoltage',
                icon: Icons.battery_full,
              ),
              DiagnosticDataCard(
                title: 'Engine Load',
                value: (_currentData['engineLoad'] ?? 0).toDouble(),
                parameter: 'engineLoad',
                icon: Icons.fitness_center,
              ),
              DiagnosticDataCard(
                title: 'Intake Air Temp',
                value: _convertTemperature(
                  (_currentData['intakeAirTemp'] ?? 0).toDouble(),
                ),
                parameter: 'intakeAirTemp',
                icon: Icons.air,
                unit: _getTemperatureUnit(),
              ),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        (_currentData['errorCodes'] as List?)?.isNotEmpty ==
                            true
                        ? AppTheme.errorRed
                        : Colors.grey[300]!,
                    width:
                        (_currentData['errorCodes'] as List?)?.isNotEmpty ==
                            true
                        ? 3
                        : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => _showErrorCodes(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color:
                              (_currentData['errorCodes'] as List?)
                                      ?.isNotEmpty ==
                                  true
                              ? AppTheme.errorRed
                              : Colors.grey[600],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error Codes',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_currentData['errorCodes'] as List?)?.length ?? 0}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    (_currentData['errorCodes'] as List?)
                                            ?.isNotEmpty ==
                                        true
                                    ? AppTheme.errorRed
                                    : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showErrorCodes() {
    final errorCodes = _currentData['errorCodes'] as List<String>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostic Error Codes'),
        content: SizedBox(
          width: double.maxFinite,
          child: errorCodes.isEmpty
              ? const Text('No error codes detected.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: errorCodes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(
                        Icons.error,
                        color: AppTheme.errorRed,
                      ),
                      title: Text(errorCodes[index]),
                      subtitle: Text(_getErrorDescription(errorCodes[index])),
                    );
                  },
                ),
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

  String _getErrorDescription(String code) {
    switch (code) {
      // ── Fuel & Air Metering ──────────────────────────────────────────
      case 'P0100': return 'Mass or Volume Air Flow Circuit Malfunction';
      case 'P0101': return 'Mass Air Flow Circuit Range/Performance';
      case 'P0102': return 'Mass Air Flow Circuit Low Input';
      case 'P0103': return 'Mass Air Flow Circuit High Input';
      case 'P0104': return 'Mass Air Flow Circuit Intermittent';
      case 'P0105': return 'Manifold Absolute Pressure Circuit Malfunction';
      case 'P0106': return 'MAP Circuit Range/Performance';
      case 'P0107': return 'MAP Circuit Low Input';
      case 'P0108': return 'MAP Circuit High Input';
      case 'P0110': return 'Intake Air Temperature Circuit Malfunction';
      case 'P0111': return 'Intake Air Temperature Circuit Range/Performance';
      case 'P0112': return 'Intake Air Temperature Circuit Low Input';
      case 'P0113': return 'Intake Air Temperature Circuit High Input';
      case 'P0115': return 'Engine Coolant Temperature Circuit Malfunction';
      case 'P0116': return 'Engine Coolant Temperature Circuit Range/Performance';
      case 'P0117': return 'Engine Coolant Temperature Circuit Low Input';
      case 'P0118': return 'Engine Coolant Temperature Circuit High Input';
      case 'P0120': return 'Throttle Position Sensor A Circuit Malfunction';
      case 'P0121': return 'Throttle Position Sensor A Range/Performance';
      case 'P0122': return 'Throttle Position Sensor A Circuit Low Input';
      case 'P0123': return 'Throttle Position Sensor A Circuit High Input';
      case 'P0125': return 'Insufficient Coolant Temperature for Closed Loop Fuel Control';
      case 'P0128': return 'Coolant Thermostat Below Regulating Temperature';
      case 'P0130': return 'O2 Sensor Circuit Malfunction (Bank 1, Sensor 1)';
      case 'P0131': return 'O2 Sensor Circuit Low Voltage (Bank 1, Sensor 1)';
      case 'P0132': return 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 1)';
      case 'P0133': return 'O2 Sensor Circuit Slow Response (Bank 1, Sensor 1)';
      case 'P0134': return 'O2 Sensor Circuit No Activity (Bank 1, Sensor 1)';
      case 'P0135': return 'O2 Sensor Heater Circuit Malfunction (Bank 1, Sensor 1)';
      case 'P0136': return 'O2 Sensor Circuit Malfunction (Bank 1, Sensor 2)';
      case 'P0137': return 'O2 Sensor Circuit Low Voltage (Bank 1, Sensor 2)';
      case 'P0138': return 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 2)';
      case 'P0139': return 'O2 Sensor Circuit Slow Response (Bank 1, Sensor 2)';
      case 'P0140': return 'O2 Sensor Circuit No Activity (Bank 1, Sensor 2)';
      case 'P0141': return 'O2 Sensor Heater Circuit Malfunction (Bank 1, Sensor 2)';
      case 'P0150': return 'O2 Sensor Circuit Malfunction (Bank 2, Sensor 1)';
      case 'P0151': return 'O2 Sensor Circuit Low Voltage (Bank 2, Sensor 1)';
      case 'P0152': return 'O2 Sensor Circuit High Voltage (Bank 2, Sensor 1)';
      case 'P0153': return 'O2 Sensor Circuit Slow Response (Bank 2, Sensor 1)';
      case 'P0155': return 'O2 Sensor Heater Circuit Malfunction (Bank 2, Sensor 1)';
      case 'P0156': return 'O2 Sensor Circuit Malfunction (Bank 2, Sensor 2)';
      case 'P0158': return 'O2 Sensor Circuit High Voltage (Bank 2, Sensor 2)';
      case 'P0161': return 'O2 Sensor Heater Circuit Malfunction (Bank 2, Sensor 2)';

      // ── Fuel System ──────────────────────────────────────────────────
      case 'P0170': return 'Fuel Trim Malfunction (Bank 1)';
      case 'P0171': return 'System Too Lean (Bank 1)';
      case 'P0172': return 'System Too Rich (Bank 1)';
      case 'P0173': return 'Fuel Trim Malfunction (Bank 2)';
      case 'P0174': return 'System Too Lean (Bank 2)';
      case 'P0175': return 'System Too Rich (Bank 2)';
      case 'P0190': return 'Fuel Rail Pressure Sensor Circuit Malfunction';
      case 'P0191': return 'Fuel Rail Pressure Sensor Circuit Range/Performance';
      case 'P0192': return 'Fuel Rail Pressure Sensor Circuit Low Input';
      case 'P0193': return 'Fuel Rail Pressure Sensor Circuit High Input';

      // ── Misfire ───────────────────────────────────────────────────────
      case 'P0300': return 'Random/Multiple Cylinder Misfire Detected';
      case 'P0301': return 'Cylinder 1 Misfire Detected';
      case 'P0302': return 'Cylinder 2 Misfire Detected';
      case 'P0303': return 'Cylinder 3 Misfire Detected';
      case 'P0304': return 'Cylinder 4 Misfire Detected';
      case 'P0305': return 'Cylinder 5 Misfire Detected';
      case 'P0306': return 'Cylinder 6 Misfire Detected';
      case 'P0307': return 'Cylinder 7 Misfire Detected';
      case 'P0308': return 'Cylinder 8 Misfire Detected';

      // ── Knock & Timing ───────────────────────────────────────────────
      case 'P0320': return 'Ignition/Distributor Engine Speed Input Circuit Malfunction';
      case 'P0325': return 'Knock Sensor 1 Circuit Malfunction (Bank 1)';
      case 'P0326': return 'Knock Sensor 1 Circuit Range/Performance (Bank 1)';
      case 'P0327': return 'Knock Sensor 1 Circuit Low Input (Bank 1)';
      case 'P0328': return 'Knock Sensor 1 Circuit High Input (Bank 1)';
      case 'P0330': return 'Knock Sensor 2 Circuit Malfunction (Bank 2)';
      case 'P0335': return 'Crankshaft Position Sensor A Circuit Malfunction';
      case 'P0336': return 'Crankshaft Position Sensor A Circuit Range/Performance';
      case 'P0340': return 'Camshaft Position Sensor A Circuit Malfunction (Bank 1)';
      case 'P0341': return 'Camshaft Position Sensor A Circuit Range/Performance (Bank 1)';
      case 'P0342': return 'Camshaft Position Sensor A Circuit Low Input (Bank 1)';
      case 'P0343': return 'Camshaft Position Sensor A Circuit High Input (Bank 1)';
      case 'P0344': return 'Camshaft Position Sensor A Circuit Intermittent (Bank 1)';
      case 'P0345': return 'Camshaft Position Sensor A Circuit Malfunction (Bank 2)';

      // ── Emission Controls ────────────────────────────────────────────
      case 'P0400': return 'Exhaust Gas Recirculation Flow Malfunction';
      case 'P0401': return 'Exhaust Gas Recirculation Flow Insufficient';
      case 'P0402': return 'Exhaust Gas Recirculation Flow Excessive';
      case 'P0404': return 'Exhaust Gas Recirculation Circuit Range/Performance';
      case 'P0405': return 'Exhaust Gas Recirculation Sensor A Circuit Low';
      case 'P0406': return 'Exhaust Gas Recirculation Sensor A Circuit High';
      case 'P0410': return 'Secondary Air Injection System Malfunction';
      case 'P0420': return 'Catalyst System Efficiency Below Threshold (Bank 1)';
      case 'P0421': return 'Warm Up Catalyst Efficiency Below Threshold (Bank 1)';
      case 'P0430': return 'Catalyst System Efficiency Below Threshold (Bank 2)';
      case 'P0440': return 'Evaporative Emission Control System Malfunction';
      case 'P0441': return 'Evaporative Emission Control System Incorrect Purge Flow';
      case 'P0442': return 'Evaporative Emission Control System Small Leak Detected';
      case 'P0443': return 'Evaporative Emission Control System Purge Valve Malfunction';
      case 'P0444': return 'Evaporative Emission Control System Purge Valve Open Circuit';
      case 'P0445': return 'Evaporative Emission Control System Purge Valve Shorted';
      case 'P0446': return 'Evaporative Emission Control System Vent Control Malfunction';
      case 'P0447': return 'Evaporative Emission Control System Vent Control Open Circuit';
      case 'P0448': return 'Evaporative Emission Control System Vent Control Shorted';
      case 'P0449': return 'Evaporative Emission Control System Vent Valve/Solenoid Malfunction';
      case 'P0450': return 'Evaporative Emission Control System Pressure Sensor Malfunction';
      case 'P0451': return 'Evaporative Emission Control System Pressure Sensor Range/Performance';
      case 'P0452': return 'Evaporative Emission Control System Pressure Sensor Low Input';
      case 'P0453': return 'Evaporative Emission Control System Pressure Sensor High Input';
      case 'P0455': return 'Evaporative Emission System Large Leak Detected';
      case 'P0456': return 'Evaporative Emission System Very Small Leak Detected';
      case 'P0457': return 'Evaporative Emission System Loose Fuel Cap';
      case 'P0458': return 'Evaporative Emission System Purge Valve Circuit Low';
      case 'P0459': return 'Evaporative Emission System Purge Valve Circuit High';
      case 'P0460': return 'Fuel Level Sensor Circuit Malfunction';
      case 'P0461': return 'Fuel Level Sensor Circuit Range/Performance';
      case 'P0462': return 'Fuel Level Sensor Circuit Low Input';
      case 'P0463': return 'Fuel Level Sensor Circuit High Input';

      // ── Vehicle Speed & Idle ─────────────────────────────────────────
      case 'P0500': return 'Vehicle Speed Sensor Malfunction';
      case 'P0501': return 'Vehicle Speed Sensor Range/Performance';
      case 'P0502': return 'Vehicle Speed Sensor Circuit Low Input';
      case 'P0503': return 'Vehicle Speed Sensor Intermittent/Erratic/High';
      case 'P0505': return 'Idle Control System Malfunction';
      case 'P0506': return 'Idle Control System RPM Lower Than Expected';
      case 'P0507': return 'Idle Control System RPM Higher Than Expected';

      // ── Transmission ─────────────────────────────────────────────────
      case 'P0560': return 'System Voltage Malfunction';
      case 'P0562': return 'System Voltage Low';
      case 'P0563': return 'System Voltage High';
      case 'P0600': return 'Serial Communication Link Malfunction';
      case 'P0601': return 'Internal Control Module Memory Check Sum Error';
      case 'P0602': return 'Control Module Programming Error';
      case 'P0603': return 'Internal Control Module Keep Alive Memory Error';
      case 'P0604': return 'Internal Control Module Random Access Memory Error';
      case 'P0605': return 'Internal Control Module Read Only Memory Error';
      case 'P0606': return 'PCM Processor Fault';
      case 'P0700': return 'Transmission Control System Malfunction';
      case 'P0701': return 'Transmission Control System Range/Performance';
      case 'P0702': return 'Transmission Control System Electrical Malfunction';
      case 'P0703': return 'Torque Converter/Brake Switch B Circuit Malfunction';
      case 'P0705': return 'Transmission Range Sensor Circuit Malfunction (PRNDL Input)';
      case 'P0706': return 'Transmission Range Sensor Circuit Range/Performance';
      case 'P0710': return 'Transmission Fluid Temperature Sensor Circuit Malfunction';
      case 'P0711': return 'Transmission Fluid Temperature Sensor Range/Performance';
      case 'P0712': return 'Transmission Fluid Temperature Sensor Circuit Low Input';
      case 'P0713': return 'Transmission Fluid Temperature Sensor Circuit High Input';
      case 'P0715': return 'Input/Turbine Speed Sensor Circuit Malfunction';
      case 'P0720': return 'Output Speed Sensor Circuit Malfunction';
      case 'P0725': return 'Engine Speed Input Circuit Malfunction';
      case 'P0730': return 'Incorrect Gear Ratio';
      case 'P0731': return 'Gear 1 Incorrect Ratio';
      case 'P0732': return 'Gear 2 Incorrect Ratio';
      case 'P0733': return 'Gear 3 Incorrect Ratio';
      case 'P0734': return 'Gear 4 Incorrect Ratio';
      case 'P0735': return 'Gear 5 Incorrect Ratio';
      case 'P0740': return 'Torque Converter Clutch Circuit Malfunction';
      case 'P0741': return 'Torque Converter Clutch Circuit Performance or Stuck Off';
      case 'P0742': return 'Torque Converter Clutch Circuit Stuck On';
      case 'P0743': return 'Torque Converter Clutch Circuit Electrical Malfunction';
      case 'P0750': return 'Shift Solenoid A Malfunction';
      case 'P0755': return 'Shift Solenoid B Malfunction';
      case 'P0760': return 'Shift Solenoid C Malfunction';
      case 'P0765': return 'Shift Solenoid D Malfunction';
      case 'P0770': return 'Shift Solenoid E Malfunction';

      // ── Charging & Battery ───────────────────────────────────────────
      case 'P0620': return 'Generator Control Circuit Malfunction';
      case 'P0621': return 'Generator Lamp L Control Circuit Malfunction';
      case 'P0622': return 'Generator Field F Control Circuit Malfunction';

      // ── Cooling System ───────────────────────────────────────────────
      case 'P0480': return 'Cooling Fan 1 Control Circuit Malfunction';
      case 'P0481': return 'Cooling Fan 2 Control Circuit Malfunction';
      case 'P0482': return 'Cooling Fan 3 Control Circuit Malfunction';
      case 'P0483': return 'Cooling Fan Rationality Check Malfunction';
      case 'P0484': return 'Cooling Fan Circuit Over Current';
      case 'P0485': return 'Cooling Fan Power/Ground Circuit Malfunction';

      // ── Body (B) Codes ───────────────────────────────────────────────
      case 'B0001': return 'Deployment Commanded (Airbag)';
      case 'B0002': return 'Driver Frontal Stage 1 Deployment Control';
      case 'B0010': return 'Right Curtain Deployment Control';
      case 'B0020': return 'Left Curtain Deployment Control';
      case 'B0051': return 'Airbag Diagnostic Monitor Internal Failure';
      case 'B1000': return 'ECU Malfunction';
      case 'B1001': return 'Option Configuration Error';

      // ── Chassis (C) Codes ────────────────────────────────────────────
      case 'C0035': return 'Left Front Wheel Speed Sensor Circuit Malfunction';
      case 'C0036': return 'Left Front Wheel Speed Sensor Circuit Range/Performance';
      case 'C0040': return 'Right Front Wheel Speed Sensor Circuit Malfunction';
      case 'C0041': return 'Right Front Wheel Speed Sensor Circuit Range/Performance';
      case 'C0045': return 'Left Rear Wheel Speed Sensor Circuit Malfunction';
      case 'C0046': return 'Left Rear Wheel Speed Sensor Circuit Range/Performance';
      case 'C0050': return 'Right Rear Wheel Speed Sensor Circuit Malfunction';
      case 'C0051': return 'Right Rear Wheel Speed Sensor Circuit Range/Performance';
      case 'C0110': return 'ABS Motor Circuit Malfunction';
      case 'C0121': return 'ABS Valve Relay Circuit Malfunction';
      case 'C0161': return 'ABS/TCS Brake Switch Circuit Malfunction';
      case 'C0265': return 'EBCM Relay Circuit Active';
      case 'C0266': return 'EBCM Relay Circuit Open/Shorted';
      case 'C0550': return 'Electronic Control Unit Malfunction';
      case 'C0800': return 'Device Power Circuit Low Voltage';

      // ── Network (U) Codes ────────────────────────────────────────────
      case 'U0001': return 'High Speed CAN Communication Bus Malfunction';
      case 'U0010': return 'Medium Speed CAN Communication Bus Malfunction';
      case 'U0073': return 'Control Module Communication Bus Off';
      case 'U0100': return 'Lost Communication with ECM/PCM';
      case 'U0101': return 'Lost Communication with TCM';
      case 'U0121': return 'Lost Communication with Anti-Lock Brake System Control Module';
      case 'U0122': return 'Lost Communication with Vehicle Dynamics Control Module';
      case 'U0155': return 'Lost Communication with Instrument Panel Cluster Control Module';
      case 'U0164': return 'Lost Communication with HVAC Control Module';
      case 'U0401': return 'Invalid Data Received from ECM/PCM';

      default:
        return 'Unknown fault code — consult a mechanic';
    }
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _pulseController.dispose();
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
