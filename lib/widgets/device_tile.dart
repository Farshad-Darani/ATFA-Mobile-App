import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/app_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.onTap,
    this.isExpanded = false,
    this.onDisconnect,
    this.onToggleExpand,
  });

  final BluetoothDevice device;
  final bool isConnected;
  final VoidCallback onTap;
  final bool isExpanded;
  final VoidCallback? onDisconnect;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isConnected 
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : const Color(0xFF1E293B).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isConnected 
                    ? Icons.bluetooth_connected
                    : _getDeviceIcon(deviceName),
                color: isConnected 
                    ? AppTheme.primaryBlue
                    : Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              deviceName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: isConnected
                ? Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            trailing: isConnected
                ? const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryBlue,
                  )
                : const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
            onTap: isConnected ? onToggleExpand : onTap,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded && isConnected
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: onDisconnect,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.secondarySlate,
                            side: const BorderSide(color: AppTheme.secondarySlate),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect Device'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
