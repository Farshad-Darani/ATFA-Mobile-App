import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({
    super.key,
    required this.permission,
    required this.onRetry,
  });

  final Permission permission;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permission Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPermissionIcon(),
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _getPermissionMessage(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  IconData _getPermissionIcon() {
    switch (permission) {
      case Permission.bluetoothScan:
      case Permission.bluetoothConnect:
        return Icons.bluetooth;
      case Permission.locationWhenInUse:
      case Permission.location:
        return Icons.location_on;
      default:
        return Icons.security;
    }
  }

  String _getPermissionMessage() {
    switch (permission) {
      case Permission.bluetoothScan:
        return 'ATFA needs Bluetooth scan permission to discover OBD-II devices near you.';
      case Permission.bluetoothConnect:
        return 'ATFA needs Bluetooth connect permission to establish connection with OBD-II devices.';
      case Permission.locationWhenInUse:
      case Permission.location:
        return 'ATFA needs location permission for Bluetooth Low Energy device discovery. This is required by Android for BLE scanning.';
      default:
        return 'ATFA needs this permission to function properly.';
    }
  }
}
