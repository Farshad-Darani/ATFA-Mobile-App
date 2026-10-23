import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dtc_parser.dart';
import 'obd_parser.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  bool _isInitialized = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  // For collecting OBD responses
  String _responseBuffer = '';
  final _responseController = StreamController<String>.broadcast();

  // Prevent overlapping data requests
  bool _isGettingData = false;

  /// Latest check-engine light and fault codes; null until the first read.
  final ValueNotifier<DtcStatus?> dtcStatus = ValueNotifier(null);
  bool? _isCan;
  int? _lastDtcCount;
  DateTime? _lastDtcRead;
  static const Duration _dtcRefreshEvery = Duration(seconds: 60);

  // Slow-changing sensors are read a couple per cycle in turn (everything on the
  // first pass); the rest reuse the last value. Battery and fault codes run every
  // _slowEvery cycles.
  static const int _slowEvery = 5;
  static const int _slowPerCycle = 1;
  int _pollCycle = 0;
  int _slowCursor = 0;
  final Map<String, dynamic> _slowReadings = {};

  // Per-notification and per-command tracing is too noisy for the polling hot path.
  static const bool _verboseTrace = false;
  void _trace(String message) {
    if (kDebugMode && _verboseTrace) print(message);
  }

  // Last successfully fetched data — available to any widget without a new BLE request
  Map<String, dynamic> _lastData = {};
  DateTime? _lastDataTime;
  Map<String, dynamic> get lastData => Map<String, dynamic>.from(_lastData);

  /// True only when connected AND data was updated in the last 3 seconds
  bool get isDataStreaming =>
      isConnected &&
      _lastDataTime != null &&
      DateTime.now().difference(_lastDataTime!).inSeconds < 3;

  /// Notifier updated immediately when the user presses pause/resume in LiveDataPage.
  /// Listen to this instead of polling for instant strip state changes.
  final ValueNotifier<bool> isPaused = ValueNotifier(false);

  /// True once the adapter is connected and initialised; pages listen to react instantly.
  final ValueNotifier<bool> connectionState = ValueNotifier(false);

  void _syncConnectionState() => connectionState.value = isConnected;

  void setPaused(bool value) => isPaused.value = value;

  // Disconnection callback
  void Function()? onDeviceDisconnected;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null && _isInitialized;

  // Debug method to check detailed connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'hasDevice': _connectedDevice != null,
      'deviceName': _connectedDevice?.platformName ?? 'None',
      'isInitialized': _isInitialized,
      'hasWriteCharacteristic': _writeCharacteristic != null,
      'hasReadCharacteristic': _readCharacteristic != null,
      'isConnected': isConnected,
    };
  }

  // Common OBD-II service and characteristic UUIDs for ELM327
  static const String obdServiceUuid = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String obdCharacteristicUuid =
      "0000fff1-0000-1000-8000-00805f9b34fb";

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print('🔗 Connecting to device: ${device.platformName}');
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      print('✅ Bluetooth connection established');

      // Listen for disconnection
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        print('📡 Connection state changed: $state');
        if (state == BluetoothConnectionState.disconnected) {
          print('⚠️ Device disconnected unexpectedly!');
          _handleDisconnection();
        }
      });

      // Discover services and characteristics
      print('🔍 Discovering services...');
      final services = await device.discoverServices();
      print('📋 Found ${services.length} services');

      for (final service in services) {
        print('🔧 Service: ${service.uuid}');
        for (final characteristic in service.characteristics) {
          print(
            '📡 Characteristic: ${characteristic.uuid}, Properties: Write=${characteristic.properties.write}, Read=${characteristic.properties.read}, Notify=${characteristic.properties.notify}',
          );

          // For your OBDII device, look for fff1 and fff2 characteristics
          if (characteristic.uuid.toString().toLowerCase().contains('fff1')) {
            _writeCharacteristic = characteristic;
            print('✅ Found write characteristic: ${characteristic.uuid}');

            // Enable notifications on fff1 if available (common for OBD dongles)
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                final response = String.fromCharCodes(value);
                _trace('📨 Notification received on fff1: $response');
                _responseBuffer += response;
                _responseController.add(response);
              });
              print('✅ Notifications enabled on fff1');
            }
          } else if (characteristic.uuid.toString().toLowerCase().contains(
            'fff2',
          )) {
            _readCharacteristic = characteristic;
            print('✅ Found read characteristic: ${characteristic.uuid}');

            // Also enable notifications on fff2 if available
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                final response = String.fromCharCodes(value);
                _trace('📨 Notification received on fff2: $response');
                _responseBuffer += response;
                _responseController.add(response);
              });
              print('✅ Notifications enabled on fff2');
            }
          }

          // Fallback: use any characteristic with write capability for write
          if (_writeCharacteristic == null && characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            print(
              '✅ Using fallback write characteristic: ${characteristic.uuid}',
            );
          }

          // Fallback: use any characteristic with read/notify capability for read
          if (_readCharacteristic == null &&
              (characteristic.properties.read ||
                  characteristic.properties.notify)) {
            _readCharacteristic = characteristic;
            print(
              '✅ Using fallback read characteristic: ${characteristic.uuid}',
            );
            // Note: Notifications already set up for fff1/fff2 above, no need to duplicate
          }
        }
      }

      // Initialize ELM327
      if (_writeCharacteristic != null) {
        print('🚗 Initializing ELM327...');
        await _initializeELM327();
        print('🎉 ELM327 initialization complete. Status: $_isInitialized');
      } else {
        print('❌ No suitable write characteristic found');
      }

      _syncConnectionState();
      return true;
    } catch (e) {
      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _isInitialized = false;
      _syncConnectionState();
      rethrow;
    }
  }

  Future<void> _initializeELM327() async {
    try {
      print('🔧 Sending ATZ (reset)...');
      // Reset ELM327
      await _sendCommand('ATZ');
      await Future.delayed(const Duration(milliseconds: 2000));

      print('🔧 Sending ATE0 (echo off)...');
      // Turn off echo
      await _sendCommand('ATE0');
      await Future.delayed(const Duration(milliseconds: 500));

      print('🔧 Sending ATSP0 (auto protocol)...');
      // Set protocol to automatic
      await _sendCommand('ATSP0');
      await Future.delayed(const Duration(milliseconds: 500));

      // Aggressive adaptive timing shortens the wait for each reply.
      await _sendCommand('ATAT2');

      _isInitialized = true;
      print('✅ ELM327 initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize ELM327: $e');
      _isInitialized = false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
      await _connectedDevice!.disconnect();
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    print('🔌 Cleaning up connection...');
    _connectedDevice = null;
    _writeCharacteristic = null;
    _readCharacteristic = null;
    _isInitialized = false;
    _responseBuffer = '';
    isPaused.value = false; // Reset paused state on disconnect
    _slowReadings.clear();
    _pollCycle = 0;
    _slowCursor = 0;
    _isCan = null;
    _supportedPids = null;
    _supportAttempts = 0;
    _lastDtcCount = null;
    _lastDtcRead = null;
    dtcStatus.value = null;
    _syncConnectionState();

    // Notify listeners (UI) about disconnection
    if (onDeviceDisconnected != null) {
      onDeviceDisconnected!();
    }
    print('✅ Disconnection handled');
  }

  static bool _isObdRequest(String command) =>
      RegExp(r'^[0-9A-F]{2}', caseSensitive: false).hasMatch(command);

  // A request for mode N is answered with mode N + 0x40 (03 -> 43, 0101 -> 41).
  static String _replySid(String command) =>
      (int.parse(command.substring(0, 2), radix: 16) + 0x40)
          .toRadixString(16)
          .toUpperCase()
          .padLeft(2, '0');

  Future<String> _sendCommand(String command, {bool raw = false}) async {
    if (_writeCharacteristic == null) {
      throw Exception('No write characteristic available');
    }

    try {
      // Wait for response through notifications
      final completer = Completer<String>();
      Timer? timeout;
      late StreamSubscription subscription;

      // Clear buffer RIGHT BEFORE starting listener (to discard any trailing data from previous command)
      _responseBuffer = '';

      // Start listening BEFORE sending command
      subscription = _responseController.stream.listen((data) {
        // Complete when we have a response ending with '>'
        if (_responseBuffer.contains('>')) {
          // For OBD requests, require the matching reply (mode + 0x40)
          // For init commands (AT), accept any response
          final isOBDCommand = _isObdRequest(command);
          final hasValidResponse =
              !isOBDCommand ||
              _responseBuffer.contains(_replySid(command)) ||
              _responseBuffer.contains('UNABLE') ||
              _responseBuffer.contains('NO DATA');

          if (hasValidResponse && !completer.isCompleted) {
            final response = _responseBuffer.trim();
            _trace('✅ Complete response received: $response');
            completer.complete(response);
            timeout?.cancel();
            subscription.cancel();
          }
        }
      });

      // NOW send command after listener is ready
      final commandBytes = '$command\r'.codeUnits;
      await _writeCharacteristic!.write(commandBytes, withoutResponse: false);
      _trace('📤 Sent command: $command');

      // Set a timeout
      timeout = Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          // A half-received OBD reply would parse as 0, so it counts as a failed read.
          final isOBD = _isObdRequest(command);
          if (_responseBuffer.isNotEmpty && !isOBD) {
            print('⏱️ Timeout - returning partial response: $_responseBuffer');
            completer.complete(_responseBuffer.trim());
          } else {
            print('⏱️ Timeout - no response received');
            completer.completeError('Timeout waiting for response');
          }
        }
      });

      final response = await completer.future;
      subscription.cancel();
      timeout.cancel();

      // The '>' prompt marks the end of a reply, so no settling delay is needed.

      // Extract only the relevant OBD response line (41/43 line)
      final cleanedResponse = _extractOBDResponse(response);
      _trace('Command: $command, Raw: $response, Cleaned: $cleanedResponse');
      return raw ? response : cleanedResponse;
    } catch (e) {
      print('Failed to send command $command: $e');
      throw Exception('Failed to send command: $e');
    }
  }

  Future<Map<String, dynamic>> getRealTimeData() async {
    // Prevent overlapping calls
    if (_isGettingData) {
      _trace('⚠️ Data request already in progress, skipping...');
      return {};
    }

    _isGettingData = true;

    try {
      _trace('🔄 getRealTimeData called. ${getConnectionStatus()}');

      if (!isConnected) {
        print('📱 Not connected - returning simulated data');
        return getSimulatedData();
      }

      final cycleTimer = Stopwatch()..start();
      final data = <String, dynamic>{};

      if (_supportedPids == null && _supportAttempts < 3) {
        _supportAttempts++;
        await _discoverSupportedPids();
      }

      // Fast sensors are read every cycle, slow ones a few at a time.
      for (final sensor in _sensors) {
        if (sensor.fast) data[sensor.key] = await _readSensor(sensor);
      }
      final slow = _sensors.where((s) => !s.fast && _supports(s.pid)).toList();
      final slowCount = _slowReadings.isEmpty
          ? slow.length
          : (slow.length < _slowPerCycle ? slow.length : _slowPerCycle);
      for (var i = 0; i < slowCount; i++) {
        final sensor = slow[_slowCursor % slow.length];
        _slowCursor++;
        _slowReadings[sensor.key] = await _readSensor(sensor);
      }
      if (_pollCycle % _slowEvery == 0) {
        _slowReadings['batteryVoltage'] = await _readBatteryVoltage();
        await _refreshDtcsIfNeeded();
      }
      _pollCycle++;
      data.addAll(_slowReadings);

      final dtc = dtcStatus.value;
      data['errorCodes'] = List<String>.from(dtc?.stored ?? const <String>[]);
      data['milOn'] = dtc?.milOn;
      if (kDebugMode) print('⏱️ cycle ${cycleTimer.elapsedMilliseconds} ms');

      _lastData = Map<String, dynamic>.from(data);
      _lastDataTime = DateTime.now();
      return data;
    } catch (e) {
      print('❌ Error getting real-time data: $e');
      print('🔄 Falling back to simulated data');
      final sim = getSimulatedData();
      if (_lastData.isEmpty) _lastData = Map<String, dynamic>.from(sim);
      return sim;
    } finally {
      _isGettingData = false;
    }
  }

  static final List<_Sensor> _sensors = [
    _Sensor('rpm', 0x0C, parseRpm, fast: true),
    _Sensor('speed', 0x0D, parseSpeed, fast: true),
    _Sensor('throttlePosition', 0x11, parseThrottle, fast: true),
    _Sensor('engineLoad', 0x04, parseEngineLoad, fast: true),
    _Sensor('coolantTemp', 0x05, parseCoolantTemp),
    _Sensor('intakeAirTemp', 0x0F, parseIntakeAirTemp),
    _Sensor('fuelLevel', 0x2F, parseFuelLevel),
    _Sensor('shortTermFuelTrim', 0x06, parseShortTermFuelTrim),
    _Sensor('longTermFuelTrim', 0x07, parseLongTermFuelTrim),
    _Sensor('mafRate', 0x10, parseMafRate),
    _Sensor('manifoldPressure', 0x0B, parseManifoldPressure),
    _Sensor('timingAdvance', 0x0E, parseTimingAdvance),
    _Sensor('oilTemp', 0x5C, parseOilTemp),
    _Sensor('ambientTemp', 0x46, parseAmbientTemp),
  ];

  Set<int>? _supportedPids;
  int _supportAttempts = 0;

  /// PIDs the car says it supports; null until known or if it never answered.
  Set<int>? get supportedPids =>
      _supportedPids == null ? null : Set.unmodifiable(_supportedPids!);

  // Unknown support counts as supported so a silent adapter still gets tried.
  bool _supports(int pid) =>
      _supportedPids == null || _supportedPids!.contains(pid);

  static String _pidCommand(int pid) =>
      '01${pid.toRadixString(16).toUpperCase().padLeft(2, '0')}';

  Future<void> _discoverSupportedPids() async {
    final found = <int>{};
    var answered = false;
    for (var base = 0x00; base <= 0x60; base += 0x20) {
      final block = parseSupportedPids(await _tryRaw(_pidCommand(base)), base);
      if (block == null) break;
      answered = true;
      found.addAll(block.pids);
      if (!block.hasNext) break;
    }
    _supportedPids = answered ? found : null;
    if (kDebugMode) {
      print(
        '\u{1F50E} Supported PIDs: ${found.map((p) => p.toRadixString(16)).toList()}',
      );
    }
  }

  // Null for unsupported sensors; a failed read keeps the last good value.
  Future<num?> _readSensor(_Sensor sensor) async {
    if (!_supports(sensor.pid)) return null;
    try {
      final reply = await _sendCommand(_pidCommand(sensor.pid), raw: true);
      return sensor.parse(reply) ?? (_lastData[sensor.key] as num?);
    } catch (e) {
      print('Failed to read ${sensor.key}: $e');
      return _lastData[sensor.key] as num?;
    }
  }

  // ATRV reads the adapter's own voltage; fall back to PID 0142 if it is unusable.
  Future<double?> _readBatteryVoltage() async {
    try {
      final atrv = parseAtrv(await _sendCommand('ATRV', raw: true));
      if (atrv != null) return atrv;
      if (_supports(0x42)) {
        final pid = parseControlModuleVoltage(
          await _sendCommand(_pidCommand(0x42), raw: true),
        );
        if (pid != null) return pid;
      }
    } catch (e) {
      print('Failed to get voltage: $e');
    }
    return (_slowReadings['batteryVoltage'] as num?)?.toDouble();
  }

  // Helper function to extract OBD response from raw data
  String _extractOBDResponse(String rawResponse) {
    // Remove common artifacts: >, newlines, carriage returns, spaces
    // Then find the line that starts with 41 (OBD response code)
    final lines = rawResponse.split(RegExp(r'[\r\n]'));
    for (final line in lines) {
      final cleaned = line.trim().replaceAll('>', '').trim();
      if (cleaned.startsWith('41') || cleaned.startsWith('43')) {
        return cleaned;
      }
    }
    return rawResponse; // Fallback to original
  }

  Future<String> _tryRaw(String command) async {
    try {
      return await _sendCommand(command, raw: true);
    } catch (_) {
      return '';
    }
  }

  // The light and code count are cheap to poll; the full lists are re-read only
  // when they change or every minute. Runs inside a data cycle.
  Future<void> _refreshDtcsIfNeeded() async {
    final monitor = parseMonitorStatus(await _tryRaw('0101'));
    final stale =
        _lastDtcRead == null ||
        DateTime.now().difference(_lastDtcRead!) > _dtcRefreshEvery;
    if (stale ||
        monitor?.dtcCount != _lastDtcCount ||
        monitor?.milOn != dtcStatus.value?.milOn) {
      await _readDtcLists(monitor);
    }
  }

  // Needs the read lock: call from a data cycle or through _runExclusive.
  Future<void> _readDtcLists([MonitorStatus? known]) async {
    final monitor = known ?? parseMonitorStatus(await _tryRaw('0101'));
    _isCan ??= isCanProtocolReply(await _tryRaw('ATDPN'));
    final isCan = _isCan!;

    final stored = parseDtcResponse(
      await _tryRaw('03'),
      sid: '43',
      isCan: isCan,
    );
    final pending = parseDtcResponse(
      await _tryRaw('07'),
      sid: '47',
      isCan: isCan,
    );
    final permanent = parseDtcResponse(
      await _tryRaw('0A'),
      sid: '4A',
      isCan: isCan,
    );

    _lastDtcCount = monitor?.dtcCount;
    _lastDtcRead = DateTime.now();
    dtcStatus.value = DtcStatus(
      stored: stored,
      pending: pending,
      permanent: permanent,
      milOn: monitor?.milOn,
      confirmedCount: monitor?.dtcCount,
      readAt: _lastDtcRead!,
    );
    if (kDebugMode) {
      print(
        '\u{1F527} DTC mil=${monitor?.milOn} stored=$stored pending=$pending permanent=$permanent',
      );
    }
  }

  // Waits for any running data cycle so commands never interleave on the link.
  Future<T?> _runExclusive<T>(Future<T> Function() action) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (_isGettingData) {
      if (DateTime.now().isAfter(deadline)) return null;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isGettingData = true;
    try {
      return await action();
    } finally {
      _isGettingData = false;
    }
  }

  /// Re-reads the light state and all fault-code lists now.
  Future<void> refreshDtcs() async {
    if (!isConnected) return;
    await _runExclusive(() => _readDtcLists());
  }

  /// Clears stored codes and turns the light off (Mode 04).
  /// Also resets the car's readiness tests. Returns true when the car confirmed.
  Future<bool> clearDtcs() async {
    if (!isConnected) return false;
    final acknowledged = await _runExclusive(() async {
      final reply = await _tryRaw('04');
      await _readDtcLists();
      return reply.replaceAll(' ', '').contains('44');
    });
    return acknowledged ?? false;
  }

  // Simulated OBD data for testing when not connected
  Map<String, dynamic> getSimulatedData() {
    return {
      'rpm': 1500 + (DateTime.now().millisecondsSinceEpoch % 1000),
      'speed': 65 + (DateTime.now().millisecondsSinceEpoch % 20),
      'coolantTemp': 85 + (DateTime.now().millisecondsSinceEpoch % 10),
      'throttlePosition': 25 + (DateTime.now().millisecondsSinceEpoch % 30),
      'batteryVoltage':
          12.4 + (DateTime.now().millisecondsSinceEpoch % 100) / 100,
      'engineLoad': 30 + (DateTime.now().millisecondsSinceEpoch % 40),
      'intakeAirTemp': 25 + (DateTime.now().millisecondsSinceEpoch % 15),
      'errorCodes': ['P0300', 'P0171'], // Example error codes
    };
  }
}

/// A Mode 01 sensor: where its value lives and how to decode it.
class _Sensor {
  const _Sensor(this.key, this.pid, this.parse, {this.fast = false});

  final String key;
  final int pid;
  final num? Function(String reply) parse;

  /// Fast sensors are read every cycle; the rest every few cycles.
  final bool fast;
}
