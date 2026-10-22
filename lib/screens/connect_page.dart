import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../widgets/device_tile.dart';
import '../config/app_theme.dart';
import 'contact_support_page.dart';

enum _ConnectIssue {
  bluetoothOff,
  accessDenied,
  unsupported,
  noDeviceFound,
  connectionLost,
  connectFailed,
  scanFailed,
}

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
  BluetoothDevice? _connectedDevice;
  bool _showTips = false;

  // Bluetooth is only touched after the user taps Scan, so no prompts at launch.
  static const String _introSeenKey = 'bluetooth_intro_seen';
  // Name filter stays as-is while testing with generic adapters.
  static const String _adapterName = 'obdii';
  static const Duration _scanDuration = Duration(seconds: 15);

  _ConnectIssue? _issue;
  bool _scanWhenReady = false;
  BluetoothDevice? _connectingDevice;
  bool get _connecting => _connectingDevice != null;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _scanTimer;
  Timer? _autoConnectTimer;

  // keepPage: false so reopening the tips always starts at the first one.
  final PageController _tipsPageController = PageController(keepPage: false);
  int _currentTipIndex = 0;

  final List<String> _connectionTips = [
    'Plug the adapter into the OBD-II port, usually under the dashboard',
    'Turn the ignition on',
    'Keep your phone close to the adapter',
  ];

  @override
  void initState() {
    super.initState();
    
    // Set up automatic disconnection handler
    _bluetoothService.onDeviceDisconnected = _handleUnexpectedDisconnect;
  }

  void _handleUnexpectedDisconnect() {
    if (!mounted) return;
    setState(() {
      _connectedDevice = null;
      _issue = _ConnectIssue.connectionLost;
    });
  }

  void _toggleTips() {
    setState(() {
      _showTips = !_showTips;
      if (_showTips) _currentTipIndex = 0;
    });
  }

  void _listenToAdapter() {
    _adapterSub ??= FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;

      if (state == BluetoothAdapterState.on) {
        setState(() {
          if (_issue == _ConnectIssue.bluetoothOff ||
              _issue == _ConnectIssue.accessDenied) {
            _issue = null;
          }
        });
        if (_scanWhenReady) {
          _scanWhenReady = false;
          _startScan();
        }
      } else if (state == BluetoothAdapterState.unauthorized) {
        setState(() => _issue = _ConnectIssue.accessDenied);
      } else if (state == BluetoothAdapterState.off && _isScanning) {
        _scanWhenReady = true;
        _stopScan();
        setState(() => _issue = _ConnectIssue.bluetoothOff);
      }
    });
  }

  Future<bool> _confirmBluetoothIntro() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_introSeenKey) ?? false) return true;
    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bluetooth, size: 40, color: AppTheme.primarySlate),
        title: const Text('Allow Bluetooth'),
        content: const Text(
          'Atfa uses Bluetooth to find and talk to your OBD-II adapter. Your phone will ask for permission next.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return false;

    await prefs.setBool(_introSeenKey, true);
    return true;
  }

  // Waits out the system permission prompt, which keeps the state unknown.
  Future<BluetoothAdapterState> _currentAdapterState() async {
    try {
      return await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      return BluetoothAdapterState.unknown;
    }
  }

  Future<void> _turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // User declined; the card stays visible.
    }
  }

  Future<void> _startScan() async {
    if (_isScanning || _connecting) return;

    if (!await _confirmBluetoothIntro() || !mounted) return;

    if (!await FlutterBluePlus.isSupported) {
      if (mounted) setState(() => _issue = _ConnectIssue.unsupported);
      return;
    }

    _listenToAdapter();
    final state = await _currentAdapterState();
    if (!mounted) return;

    switch (state) {
      case BluetoothAdapterState.on:
        break;
      case BluetoothAdapterState.unauthorized:
        setState(() => _issue = _ConnectIssue.accessDenied);
        return;
      case BluetoothAdapterState.unavailable:
        setState(() => _issue = _ConnectIssue.unsupported);
        return;
      case BluetoothAdapterState.unknown:
      case BluetoothAdapterState.turningOn:
        // The adapter listener starts the scan once Bluetooth reports on.
        _scanWhenReady = true;
        return;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        _scanWhenReady = true;
        setState(() => _issue = _ConnectIssue.bluetoothOff);
        return;
    }

    setState(() {
      _isScanning = true;
      _issue = null;
      _scanWhenReady = false;
      _discoveredDevices.clear();
    });

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);

    try {
      await FlutterBluePlus.startScan(
        timeout: _scanDuration,
        androidUsesFineLocation: true,
      );
      _scanTimer = Timer(_scanDuration, () => _stopScan(finished: true));
    } catch (e) {
      await _stopScan();
      if (!mounted) return;
      final denied = e.toString().toLowerCase().contains('permission');
      setState(() {
        _issue = denied ? _ConnectIssue.accessDenied : _ConnectIssue.scanFailed;
      });
    }
  }

  void _onScanResults(List<ScanResult> results) {
    var added = false;
    for (final result in results) {
      final name = result.device.platformName.trim().toLowerCase();
      if (name == _adapterName && !_discoveredDevices.contains(result.device)) {
        _discoveredDevices.add(result.device);
        added = true;
      }
    }
    if (!added || !mounted) return;

    setState(() {});

    // A single match is connected automatically once nothing else shows up.
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer(const Duration(seconds: 2), () {
      if (_discoveredDevices.length == 1 && _connectedDevice == null) {
        _connectToDevice(_discoveredDevices.first);
      }
    });
  }

  Future<void> _stopScan({bool finished = false}) async {
    _scanTimer?.cancel();
    _autoConnectTimer?.cancel();
    await _scanSub?.cancel();
    _scanSub = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors when stopping scan
    }

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      if (finished &&
          _discoveredDevices.isEmpty &&
          _connectedDevice == null &&
          _issue == null) {
        _issue = _ConnectIssue.noDeviceFound;
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connecting) return;
    setState(() {
      _issue = null;
      _connectingDevice = device;
    });

    try {
      await _stopScan();
      if (!mounted) return;

      await _bluetoothService.connectToDevice(device);
      if (!mounted) return;
      setState(() => _connectedDevice = device);
      _showSuccessSnackBar('Connected to ${device.platformName}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _issue = _ConnectIssue.connectFailed);
    } finally {
      if (mounted) setState(() => _connectingDevice = null);
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        // Suppress the onDeviceDisconnected callback during manual disconnect
        // so we don't show two snackbars
        _bluetoothService.onDeviceDisconnected = null;
        await _bluetoothService.disconnect();
        // Re-register the callback for future unexpected disconnections
        _bluetoothService.onDeviceDisconnected = _handleUnexpectedDisconnect;
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
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primarySlate,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Widget _buildIssueCard() {
    final isAndroid = Platform.isAndroid;
    final view = switch (_issue!) {
      _ConnectIssue.bluetoothOff => _IssueView(
        icon: Icons.bluetooth_disabled,
        title: 'Bluetooth is off',
        message: isAndroid
            ? 'Turn on Bluetooth to find your adapter.'
            : 'Turn on Bluetooth in Control Center or Settings. Scanning starts automatically.',
        actionLabel: isAndroid ? 'Turn On Bluetooth' : null,
        onAction: isAndroid ? _turnOnBluetooth : null,
      ),
      _ConnectIssue.accessDenied => _IssueView(
        icon: Icons.lock_outline,
        title: 'Bluetooth access is off',
        message:
            'Allow Bluetooth for Atfa in Settings so it can find your adapter.',
        actionLabel: 'Open Settings',
        onAction: openAppSettings,
        secondaryLabel: 'Try Again',
        onSecondary: _startScan,
      ),
      _ConnectIssue.unsupported => const _IssueView(
        icon: Icons.error_outline,
        title: 'Bluetooth LE not available',
        message: 'This device can\'t connect to the adapter.',
      ),
      _ConnectIssue.noDeviceFound => _IssueView(
        icon: Icons.search_off,
        title: 'No adapter found',
        message: 'Check that:',
        details: const [
          'The adapter is plugged into the OBD-II port',
          'The ignition is on',
          'Your phone is close to the adapter',
        ],
        actionLabel: 'Scan Again',
        onAction: _startScan,
      ),
      _ConnectIssue.connectionLost => _IssueView(
        icon: Icons.link_off,
        title: 'Connection lost',
        message:
            'The adapter disconnected. Make sure it is still plugged in and the ignition is on.',
        actionLabel: 'Reconnect',
        onAction: _startScan,
      ),
      _ConnectIssue.connectFailed => _IssueView(
        icon: Icons.link_off,
        title: 'Couldn\'t connect',
        message:
            'Unplug the adapter, plug it back in, then try again.',
        actionLabel: 'Try Again',
        onAction: _startScan,
      ),
      _ConnectIssue.scanFailed => _IssueView(
        icon: Icons.bluetooth_searching,
        title: 'Couldn\'t start scanning',
        message: 'Something went wrong. Please try again.',
        actionLabel: 'Try Again',
        onAction: _startScan,
      ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(view.icon, size: 56, color: AppTheme.secondarySlate),
            const SizedBox(height: 16),
            Text(
              view.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              view.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            for (final detail in view.details) ...[
              const SizedBox(height: 8),
              _buildTipItem(detail),
            ],
            if (view.actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: view.onAction,
                child: Text(view.actionLabel!),
              ),
            ],
            if (view.secondaryLabel != null)
              TextButton(
                onPressed: view.onSecondary,
                child: Text(view.secondaryLabel!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppTheme.secondarySlate,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primarySlate),
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

  Widget _buildStatusCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = _connectedDevice != null;
    final accent = connected ? AppTheme.successGreen : Colors.grey[500]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? AppTheme.successGreen.withValues(alpha: 0.12)
            : (isDark ? Colors.grey[900] : Colors.white),
        border: Border.all(
          color: connected
              ? AppTheme.successGreen
              : Colors.grey.withValues(alpha: 0.25),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Connected' : 'Not connected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? _connectedDevice!.platformName
                      : 'No adapter connected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // One orange primary per state; Disconnect stays secondary.
  Widget _buildActions() {
    if (_connectedDevice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => widget.onNavigateToTab?.call(1),
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.speed),
            label: const Text('View Live Data'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _disconnectDevice,
            style: AppTheme.secondaryButtonStyle(Theme.of(context).brightness),
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: (_isScanning || _connecting) ? null : _startScan,
      style: AppTheme.primaryButtonStyle,
      icon: _isScanning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primarySlate),
              ),
            )
          : const Icon(Icons.bluetooth_searching),
      label: Text(_isScanning ? 'Scanning...' : 'Scan for Device'),
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
            _buildStatusCard(),
            const SizedBox(height: 16),

            _buildActions(),
            const SizedBox(height: 16),

            // Device List (hidden once connected; the status card names the device)
            Expanded(
              child: _connectedDevice != null
                  ? const SizedBox.shrink()
                  : _issue != null
                  ? _buildIssueCard()
                  : _discoveredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.bluetooth_searching
                                : Icons.directions_car_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _isScanning
                                  ? 'Looking for your adapter…'
                                  : 'Plug your adapter into the car and turn the ignition on, then tap Scan.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600], height: 1.4),
                            ),
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
                          isConnecting: _connectingDevice == device,
                          enabled: !_connecting,
                          onTap: () => _connectToDevice(device),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Need Help Button and Tips (when disconnected)
            if (_connectedDevice == null)
              Column(
                children: [
                  TextButton.icon(
                    onPressed: _toggleTips,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.secondarySlate,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: Icon(
                      _showTips
                          ? Icons.keyboard_arrow_down
                          : Icons.lightbulb_outline,
                      size: 20,
                    ),
                    label: Text(_showTips ? 'Hide tips' : 'Need help?'),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showTips
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 72,
                                      child: PageView.builder(
                                        controller: _tipsPageController,
                                        onPageChanged: (index) =>
                                            setState(() => _currentTipIndex = index),
                                        itemCount: _connectionTips.length,
                                        itemBuilder: (context, index) => Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
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
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        _connectionTips.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: _currentTipIndex == index ? 24 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentTipIndex == index
                                                ? AppTheme.accentOrange
                                                : Colors.grey.withValues(
                                                    alpha: 0.35,
                                                  ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 4),
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
    _scanTimer?.cancel();
    _autoConnectTimer?.cancel();
    _scanSub?.cancel();
    _adapterSub?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    _tipsPageController.dispose();
    _bluetoothService.onDeviceDisconnected = null;
    super.dispose();
  }
}

class _IssueView {
  final IconData icon;
  final String title;
  final String message;
  final List<String> details;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _IssueView({
    required this.icon,
    required this.title,
    required this.message,
    this.details = const [],
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });
}
