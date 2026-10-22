import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/app_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isConnecting = false,
    this.enabled = true,
  });

  final BluetoothDevice device;
  final VoidCallback onTap;
  final bool isConnecting;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown Device';

    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.grey[600],
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        // The connecting row stays fully styled while other rows dim.
        enabled: enabled || isConnecting,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primarySlate,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bluetooth, color: Colors.white, size: 24),
        ),
        title: Text(deviceName, style: Theme.of(context).textTheme.titleMedium),
        trailing: isConnecting
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.white70 : AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Connecting\u2026', style: hintStyle),
                ],
              )
            : Text('Tap to connect', style: hintStyle),
        onTap: enabled && !isConnecting ? onTap : null,
      ),
    );
  }
}
