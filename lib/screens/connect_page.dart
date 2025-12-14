import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/bluetooth_service.dart' as bt_service;
import '../widgets/device_tile.dart';
import '../widgets/permission_dialog.dart';
import '../config/app_theme.dart';
import 'contact_support_page.dart';

class ConnectPage extends StatefulWidget {
  final VoidCallback? onNavigateToMore;
  final Function(int)? onNavigateToTab;

  const ConnectPage({super.key, this.onNavigateToMore, this.onNavigateToTab});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final bt_service.BluetoothService _bluetoothService =
      bt_service.BluetoothService();
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _bluetoothEnabled = false;
  BluetoothDevice? _connectedDevice;
  bool _isExpanded = false;
  bool _showTips = false;

  // Carousel state
  final PageController _tipsPageController = PageController();
  int _currentTipIndex = 0;
  Timer? _tipsTimer;

  final List<String> _connectionTips = [
    'Make sure your vehicle\'s ignition is ON',
    'OBD-II port is usually under the dashboard',
    'Ensure your OBD-II adapter is properly plugged in',
  ];

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  void _startTipsCarousel() {
    _tipsTimer?.cancel();
    _tipsTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_showTips) {
        timer.cancel();
        return;
      }

      if (_currentTipIndex < _connectionTips.length - 1) {
        _currentTipIndex++;
      } else {
        _currentTipIndex = 0;
      }

      if (_tipsPageController.hasClients) {
        _tipsPageController.animateToPage(
          _currentTipIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _toggleTips() {
    setState(() {
      _showTips = !_showTips;
      if (_showTips) {
        _startTipsCarousel();
      } else {
        _tipsTimer?.cancel();
      }
    });
  }

  Future<void> _initializeBluetooth() async {
    await _checkBluetoothState();
    await _requestPermissions();
  }

  Future<void> _checkBluetoothState() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      setState(() {
        _bluetoothEnabled = state == BluetoothAdapterState.on;
      });
    } catch (e) {
      _showErrorSnackBar('Error checking Bluetooth state: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (status.isDenied) {
        _showPermissionDialog(permission);
        return;
      }
    }
  }

  void _showPermissionDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => PermissionDialog(
        permission: permission,
        onRetry: _requestPermissions,
      ),
    );
  }

  Future<void> _startScan() async {
    // Check Bluetooth state before scanning
    await _checkBluetoothState();

    if (!_bluetoothEnabled) {
      _showErrorSnackBar(
        'Bluetooth is disabled. Please enable Bluetooth to connect to OBD-II devices.',
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final deviceName = result.device.platformName.trim().toLowerCase();
          if (!_discoveredDevices.contains(result.device) &&
              deviceName == "obdii") {
            setState(() {
              _discoveredDevices.add(result.device);
            });
          }
        }
      });

      // Stop scanning after timeout
      await Future.delayed(const Duration(seconds: 15));
      await _stopScan();
    } catch (e) {
      _showErrorSnackBar('Error during scan: $e');
      await _stopScan();
    }
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors when stopping scan
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _bluetoothService.connectToDevice(device);

      setState(() {
        _connectedDevice = device;
      });

      Navigator.of(context).pop(); // Close loading dialog
      _showSuccessSnackBar('Connected to ${device.platformName}');
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to connect: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _bluetoothService.disconnect();
        setState(() {
          _connectedDevice = null;
        });
        _showSuccessSnackBar('Disconnected from device');
      } catch (e) {
        _showErrorSnackBar('Error disconnecting: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: AppTheme.secondaryBlue,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    }
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 16, color: AppTheme.successGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to OBD-II')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _connectedDevice != null
                    ? Colors.grey[900]
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _connectedDevice != null
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 40,
                    color: _connectedDevice != null
                        ? Colors.white
                        : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _connectedDevice != null
                        ? 'Connected to ${_connectedDevice!.platformName}'
                        : 'No Device Connected',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _connectedDevice != null ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan Button
            ElevatedButton.icon(
              onPressed: (_isScanning || _connectedDevice != null)
                  ? null
                  : _startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primarySlate,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Device'),
            ),
            const SizedBox(height: 16),

            // Device List
            Expanded(
              child: _discoveredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning
                                ? 'Searching for device...'
                                : 'No device found.\nTap "Scan for Device" to start.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        return DeviceTile(
                          device: device,
                          isConnected: _connectedDevice == device,
                          isExpanded: _isExpanded && _connectedDevice == device,
                          onTap: () => _connectToDevice(device),
                          onDisconnect: () {
                            setState(() {
                              _isExpanded = false;
                            });
                            _disconnectDevice();
                          },
                          onToggleExpand: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Need Help Button and Tips (when disconnected)
            if (_connectedDevice == null)
              Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _toggleTips,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : (_showTips
                                ? AppTheme.secondarySlate
                                : AppTheme.primarySlate),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.5)
                            : (_showTips
                                  ? AppTheme.secondarySlate
                                  : AppTheme.primarySlate.withValues(
                                      alpha: 0.5,
                                    )),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: Icon(
                      _showTips ? Icons.expand_less : Icons.help_outline,
                      size: 20,
                    ),
                    label: Text(_showTips ? 'Hide Tips' : 'Need Help?'),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showTips
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          color: AppTheme.secondaryBlue,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Connection Tips',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 60,
                                      child: PageView.builder(
                                        controller: _tipsPageController,
                                        onPageChanged: (index) {
                                          setState(() {
                                            _currentTipIndex = index;
                                          });
                                        },
                                        itemCount: _connectionTips.length,
                                        itemBuilder: (context, index) {
                                          return Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Text(
                                                _connectionTips[index],
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(height: 1.4),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        _connectionTips.length,
                                        (index) => Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: _currentTipIndex == index
                                              ? 24
                                              : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentTipIndex == index
                                                ? AppTheme.secondaryBlue
                                                : Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Divider(
                                        color: Colors.grey[300],
                                        thickness: 1,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ContactSupportPage(
                                                    onNavigateToTab:
                                                        widget
                                                            .onNavigateToTab ??
                                                        (int index) {},
                                                  ),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.secondarySlate,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.support_agent,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Still can\'t connect? Get Support',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopScan();
    _tipsTimer?.cancel();
    _tipsPageController.dispose();
    super.dispose();
  }
}
