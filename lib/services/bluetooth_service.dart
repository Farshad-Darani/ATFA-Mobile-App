import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

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
                print('📨 Notification received on fff1: $response');
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
                print('📨 Notification received on fff2: $response');
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

      return true;
    } catch (e) {
      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _isInitialized = false;
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

      _isInitialized = true;
      print('✅ ELM327 initialized successfully');
      
      // Check error codes once during initialization
      try {
        print('🔍 Getting error codes...');
        final errorCodes = await _getErrorCodes();
        print('✅ Error codes: $errorCodes');
      } catch (e) {
        print('Failed to get error codes: $e');
      }
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
    
    // Notify listeners (UI) about disconnection
    if (onDeviceDisconnected != null) {
      onDeviceDisconnected!();
    }
    print('✅ Disconnection handled');
  }

  Future<String> _sendCommand(String command) async {
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
          // For OBD data commands (01XX), require 41/43 response
          // For init commands (AT), accept any response
          final isOBDCommand = command.startsWith('01') || command.startsWith('03');
          final hasValidResponse = !isOBDCommand || 
                                   _responseBuffer.contains('41') || 
                                   _responseBuffer.contains('43') ||
                                   _responseBuffer.contains('UNABLE') ||
                                   _responseBuffer.contains('NO DATA');
          
          if (hasValidResponse && !completer.isCompleted) {
            final response = _responseBuffer.trim();
            print('✅ Complete response received: $response');
            completer.complete(response);
            timeout?.cancel();
            subscription.cancel();
          }
        }
      });
      
      // NOW send command after listener is ready
      final commandBytes = '$command\r'.codeUnits;
      await _writeCharacteristic!.write(commandBytes, withoutResponse: false);
      print('📤 Sent command: $command');

      // Set a timeout
      timeout = Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          if (_responseBuffer.isNotEmpty) {
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
      
      // Wait longer for all straggling notifications to finish and settle
      await Future.delayed(Duration(milliseconds: 150));
      
      // Extract only the relevant OBD response line (41/43 line)
      final cleanedResponse = _extractOBDResponse(response);
      print('Command: $command, Raw: $response, Cleaned: $cleanedResponse');
      return cleanedResponse;
    } catch (e) {
      print('Failed to send command $command: $e');
      throw Exception('Failed to send command: $e');
    }
  }

  Future<Map<String, dynamic>> getRealTimeData() async {
    // Prevent overlapping calls
    if (_isGettingData) {
      print('⚠️ Data request already in progress, skipping...');
      return {};
    }
    
    _isGettingData = true;
    
    try {
      print(
        '🔄 getRealTimeData called. Connection status: ${getConnectionStatus()}',
      );

      if (!isConnected) {
        print('📱 Not connected - returning simulated data');
        return getSimulatedData();
      }

      print('🚗 Connected! Attempting to get real OBD data...');
      final data = <String, dynamic>{};

      // Get Engine RPM (PID 010C)
      try {
        print('📊 Getting RPM...');
        final rpmResponse = await _sendCommand('010C');
        data['rpm'] = _parseRPM(rpmResponse);
        print('✅ RPM: ${data['rpm']}');
      } catch (e) {
        print('❌ Failed to get RPM: $e');
        data['rpm'] = 0;
      }
      await Future.delayed(Duration(milliseconds: 400)); // Delay between commands

      // Get Vehicle Speed (PID 010D)
      try {
        final speedResponse = await _sendCommand('010D');
        data['speed'] = _parseSpeed(speedResponse);
      } catch (e) {
        print('Failed to get speed: $e');
        data['speed'] = 0;
      }
      await Future.delayed(Duration(milliseconds: 400));

      // Get Engine Coolant Temperature (PID 0105)
      try {
        final tempResponse = await _sendCommand('0105');
        data['coolantTemp'] = _parseCoolantTemp(tempResponse);
      } catch (e) {
        print('Failed to get coolant temp: $e');
        data['coolantTemp'] = 85;
      }
      await Future.delayed(Duration(milliseconds: 400));

      // Get Throttle Position (PID 0111)
      try {
        final throttleResponse = await _sendCommand('0111');
        data['throttlePosition'] = _parseThrottlePosition(throttleResponse);
      } catch (e) {
        print('Failed to get throttle position: $e');
        data['throttlePosition'] = 0;
      }
      await Future.delayed(Duration(milliseconds: 400));

      // Get Engine Load (PID 0104)
      try {
        final loadResponse = await _sendCommand('0104');
        data['engineLoad'] = _parseEngineLoad(loadResponse);
      } catch (e) {
        print('Failed to get engine load: $e');
        data['engineLoad'] = 30;
      }
      await Future.delayed(Duration(milliseconds: 400));

      // Get Battery Voltage — try ATRV (ELM327 direct read) first, fall back to PID 0142
      try {
        final atrvResponse = await _sendCommand('ATRV');
        final atrvVoltage = _parseATRV(atrvResponse);
        if (atrvVoltage != null) {
          data['batteryVoltage'] = atrvVoltage;
        } else {
          final voltageResponse = await _sendCommand('0142');
          data['batteryVoltage'] = _parseVoltage(voltageResponse);
        }
      } catch (e) {
        print('Failed to get voltage: $e');
        data['batteryVoltage'] = 12.4;
      }
      await Future.delayed(Duration(milliseconds: 400));

      // Get Intake Air Temperature (PID 010F)
      try {
        final iatResponse = await _sendCommand('010F');
        data['intakeAirTemp'] = _parseIAT(iatResponse);
      } catch (e) {
        print('Failed to get intake air temp: $e');
        data['intakeAirTemp'] = 20;
      }

      // Skip error codes in real-time updates (check only on first connect)
      data['errorCodes'] = <String>[];

      return data;
    } catch (e) {
      print('❌ Error getting real-time data: $e');
      print('🔄 Falling back to simulated data');
      return getSimulatedData();
    } finally {
      _isGettingData = false;
    }
  }

  // Force real data attempt (bypass some checks for debugging)
  Future<Map<String, dynamic>> forceRealDataAttempt() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    print('🔧 Force attempting real data...');
    final data = <String, dynamic>{};

    try {
      if (_writeCharacteristic != null) {
        final rpmResponse = await _sendCommand('010C');
        data['rpm'] = _parseRPM(rpmResponse);
        data['status'] = 'Real data retrieved successfully!';
      } else {
        throw Exception('No write characteristic available');
      }
    } catch (e) {
      data['status'] = 'Failed to get real data: $e';
      data['rpm'] = 0;
    }

    return data;
  }

  // Test connection without initialization
  Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{};

    results['hasDevice'] = _connectedDevice != null;
    results['deviceName'] = _connectedDevice?.platformName ?? 'None';

    if (_connectedDevice != null) {
      try {
        // Check if device is still connected
        final isConnected = await _connectedDevice!.connectionState.first;
        results['bluetoothConnected'] =
            isConnected == BluetoothConnectionState.connected;

        // Check services
        if (isConnected == BluetoothConnectionState.connected) {
          final services = await _connectedDevice!.discoverServices();
          results['servicesCount'] = services.length;
          results['hasWriteCharacteristic'] = _writeCharacteristic != null;
          results['hasReadCharacteristic'] = _readCharacteristic != null;
          results['isInitialized'] = _isInitialized;

          // Try to get characteristics info
          var charInfo = <String>[];
          for (final service in services) {
            for (final char in service.characteristics) {
              charInfo.add(
                '${char.uuid} (R:${char.properties.read}, W:${char.properties.write})',
              );
            }
          }
          results['characteristics'] = charInfo;
        }
      } catch (e) {
        results['error'] = 'Connection test failed: $e';
      }
    }

    return results;
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

  int _parseRPM(String response) {
    // Expected format: "41 0C XX XX" where XX XX is the RPM data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 8 && parts.startsWith('410C')) {
      final a = int.parse(parts.substring(4, 6), radix: 16);
      final b = int.parse(parts.substring(6, 8), radix: 16);
      return ((a * 256) + b) ~/ 4;
    }
    return 0;
  }

  int _parseSpeed(String response) {
    // Expected format: "41 0D XX" where XX is the speed data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 6 && parts.startsWith('410D')) {
      return int.parse(parts.substring(4, 6), radix: 16);
    }
    return 0;
  }

  int _parseCoolantTemp(String response) {
    // Expected format: "41 05 XX" where XX is the temperature data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 6 && parts.startsWith('4105')) {
      final temp = int.parse(parts.substring(4, 6), radix: 16);
      return temp - 40; // Convert to Celsius
    }
    return 85;
  }

  double _parseThrottlePosition(String response) {
    // Expected format: "41 11 XX" where XX is the throttle position data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 6 && parts.startsWith('4111')) {
      final throttle = int.parse(parts.substring(4, 6), radix: 16);
      return (throttle * 100.0) / 255.0; // Convert to percentage
    }
    return 0.0;
  }

  double _parseEngineLoad(String response) {
    // Expected format: "41 04 XX" where XX is the engine load data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 6 && parts.startsWith('4104')) {
      final load = int.parse(parts.substring(4, 6), radix: 16);
      return (load * 100.0) / 255.0; // Convert to percentage
    }
    return 30.0;
  }

  // Parse ATRV response — ELM327 returns e.g. "12.4V" or "12.40V"
  double? _parseATRV(String response) {
    final match = RegExp(r'(\d+\.\d+)\s*[Vv]').firstMatch(response);
    if (match != null) {
      final v = double.tryParse(match.group(1)!);
      // Sanity check: valid car voltage is roughly 9–16 V
      if (v != null && v >= 9.0 && v <= 16.0) return v;
    }
    return null;
  }

  double _parseVoltage(String response) {
    // Expected format: "41 42 XX XX" where XX XX is the voltage data
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 8 && parts.startsWith('4142')) {
      final a = int.parse(parts.substring(4, 6), radix: 16);
      final b = int.parse(parts.substring(6, 8), radix: 16);
      return ((a * 256) + b) / 1000.0; // Convert to volts
    }
    return 12.4;
  }

  int _parseIAT(String response) {
    // Expected format: "41 0F XX" — same formula as coolant temp
    final cleanResponse = _extractOBDResponse(response);
    final parts = cleanResponse.replaceAll(' ', '');
    if (parts.length >= 6 && parts.startsWith('410F')) {
      return int.parse(parts.substring(4, 6), radix: 16) - 40;
    }
    return 20;
  }

  Future<List<String>> _getErrorCodes() async {
    try {
      // Mode 03: Request stored DTCs
      final response = await _sendCommand('03');
      return _parseDTCs(response);
    } catch (e) {
      print('Error getting DTCs: $e');
      return [];
    }
  }

  List<String> _parseDTCs(String response) {
    List<String> dtcs = [];

    // Remove spaces and convert to uppercase
    final cleanResponse = response.replaceAll(' ', '').toUpperCase();

    // Expected format: "43" followed by number of codes, then 2-byte codes
    // Example: "43 02 01 33 02 44" means 2 codes: P0133, P0244

    if (!cleanResponse.startsWith('43')) {
      return dtcs; // No codes or invalid response
    }

    // Skip "43" and get the count byte (if present)
    if (cleanResponse.length < 4) {
      return dtcs; // Response too short
    }

    // Parse DTC codes (each DTC is 4 hex digits = 2 bytes)
    // Start from position 4 (after "43" and count byte)
    for (int i = 4; i < cleanResponse.length - 3; i += 4) {
      try {
        final code = cleanResponse.substring(i, i + 4);
        final dtc = _decodeDTC(code);
        if (dtc != null && dtc != 'P0000') {
          // Ignore P0000 (no error)
          dtcs.add(dtc);
        }
      } catch (e) {
        // Skip invalid codes
        continue;
      }
    }

    return dtcs;
  }

  String? _decodeDTC(String hexCode) {
    if (hexCode.length != 4) return null;

    try {
      // Parse the 2 bytes
      final byte1 = int.parse(hexCode.substring(0, 2), radix: 16);
      final byte2 = int.parse(hexCode.substring(2, 4), radix: 16);

      // First 2 bits determine the DTC type
      final firstBits = (byte1 >> 6) & 0x03;
      final prefix = [
        'P',
        'C',
        'B',
        'U',
      ][firstBits]; // Powertrain, Chassis, Body, Network

      // Next 2 bits are the first digit
      final digit1 = (byte1 >> 4) & 0x03;

      // Last 4 bits of first byte are the second digit
      final digit2 = byte1 & 0x0F;

      // Second byte contains the last 2 digits
      final digit3 = (byte2 >> 4) & 0x0F;
      final digit4 = byte2 & 0x0F;

      return '$prefix$digit1${digit2.toRadixString(16).toUpperCase()}${digit3.toRadixString(16).toUpperCase()}${digit4.toRadixString(16).toUpperCase()}';
    } catch (e) {
      return null;
    }
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
