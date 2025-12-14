import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../widgets/diagnostic_data_card.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/vehicle_health_summary.dart';
import '../config/app_theme.dart';

class LiveDataPage extends StatefulWidget {
  final VoidCallback? onNavigateToConnect;

  const LiveDataPage({super.key, this.onNavigateToConnect});

  @override
  State<LiveDataPage> createState() => _LiveDataPageState();
}

class _LiveDataPageState extends State<LiveDataPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final bt_service.BluetoothService _bluetoothService =
      bt_service.BluetoothService();
  Timer? _dataTimer;
  Map<String, dynamic> _currentData = {};
  bool _isDataStreaming = false;
  bool _isPaused = false;
  DateTime? _lastUpdateTime;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotationController;
  int _refreshRate = 1; // Default 1 second
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
      _refreshRate = prefs.getInt('refreshRate') ?? 1;
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

    _dataTimer = Timer.periodic(Duration(seconds: _refreshRate), (timer) {
      _updateDataFromDevice();
    });

    // Get initial data immediately
    _updateDataFromDevice();
  }

  void _updateDataFromDevice() {
    if (!_bluetoothService.isConnected) {
      _stopDataStream();
      setState(() {
        _currentData = {};
        _lastUpdateTime = null;
      });
      return;
    }

    _bluetoothService
        .getRealTimeData()
        .then((data) {
          if (mounted && data.isNotEmpty) {
            setState(() {
              _currentData = data;
              _lastUpdateTime = DateTime.now();
            });
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
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeDataStream() {
    setState(() {
      _isPaused = false;
    });
    _dataTimer = Timer.periodic(Duration(seconds: _refreshRate), (timer) {
      _updateDataFromDevice();
    });
    _updateDataFromDevice();
  }

  void _stopDataStream() {
    _dataTimer?.cancel();
    setState(() {
      _isDataStreaming = false;
      _isPaused = false;
    });
  }

  void _refreshData() {
    if (_bluetoothService.isConnected) {
      _updateDataFromDevice();
    }
  }

  void _showConnectFirstMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please connect to a device first',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isConnected = _bluetoothService.isConnected;

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
                    ? Colors.grey[900]
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
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
                              color: AppTheme.secondaryBlue,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: isConnected
                          ? AppTheme.secondaryBlue
                          : Colors.grey[600],
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Live' : 'Offline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  // Button area with fixed width and height, centered
                  SizedBox(
                    width: 220,
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
                                key: const ValueKey('start'),
                                onPressed: () {
                                  if (isConnected) {
                                    _startDataStream();
                                  } else {
                                    _showConnectFirstMessage();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isConnected
                                      ? AppTheme.primarySlate
                                      : Colors.grey[400],
                                  foregroundColor: isConnected
                                      ? Colors.white
                                      : Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('Start Diagnostics'),
                              )
                            : _currentData.isEmpty
                            ? SizedBox(
                                key: const ValueKey('loading'),
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  strokeWidth: 5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primarySlate,
                                  ),
                                ),
                              )
                            : Row(
                                key: const ValueKey('controls'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _isPaused
                                        ? _resumeDataStream
                                        : _pauseDataStream,
                                    icon: Icon(
                                      _isPaused
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                      size: 32,
                                      color: AppTheme.secondaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  IconButton(
                                    onPressed: _refreshData,
                                    icon: const Icon(
                                      Icons.refresh,
                                      size: 32,
                                      color: AppTheme.secondaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data Display
            Expanded(
              child: _currentData.isEmpty
                  ? _buildNoDataView()
                  : _buildDiagnosticDataView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView() {
    final isConnected = _bluetoothService.isConnected;
    final isWaiting = _isDataStreaming && isConnected;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rotating icon when waiting for data
          if (isWaiting)
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
              isConnected
                  ? Icons.analytics_outlined
                  : Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey[400],
            ),
          const SizedBox(height: 16),
          // Animated dots when waiting
          if (isWaiting)
            _AnimatedDotsText(
              text: 'Waiting for vehicle data',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            )
          else
            Text(
              !isConnected
                  ? 'Connect to a device to view live data'
                  : 'Press "Start Diagnostics" to begin',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          if (!isConnected) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onNavigateToConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primarySlate,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Go to Connect'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticDataView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vehicle Health Summary Card
          VehicleHealthSummary(data: _currentData),
          const SizedBox(height: 16),

          // Main gauges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: GaugeWidget(
                  title: 'RPM',
                  value: (_currentData['rpm'] ?? 0).toDouble(),
                  maxValue: 6000,
                  unit: 'rpm',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: GaugeWidget(
                  title: 'Speed',
                  value: _convertSpeed((_currentData['speed'] ?? 0).toDouble()),
                  maxValue: _useKmh ? 160 : 100,
                  unit: _getSpeedUnit(),
                  color: Colors.blue,
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
                title: 'Fuel Level',
                value: (_currentData['fuelLevel'] ?? 0).toDouble(),
                parameter: 'fuelLevel',
                icon: Icons.local_gas_station,
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
      case 'P0300':
        return 'Random/Multiple Cylinder Misfire Detected';
      case 'P0171':
        return 'System Too Lean (Bank 1)';
      case 'P0420':
        return 'Catalyst System Efficiency Below Threshold';
      case 'P0101':
        return 'Mass or Volume Air Flow Circuit Range/Performance Problem';
      default:
        return 'Generic error code';
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
