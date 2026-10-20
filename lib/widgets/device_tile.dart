import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/app_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onTap});

  final BluetoothDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown Device';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primarySlate,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getDeviceIcon(deviceName), color: Colors.white, size: 24),
        ),
        title: Text(deviceName, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          'Tap to connect',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();

    if (name.contains('elm') || name.contains('obd')) {
      return Icons.car_rental;
    } else if (name.contains('scanner') || name.contains('diagnostic')) {
      return Icons.scanner;
    } else if (name.contains('adapter')) {
      return Icons.settings_input_antenna;
    } else {
      return Icons.bluetooth;
    }
  }
}
