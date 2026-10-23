import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/bluetooth_service.dart' as bt;
import '../services/dtc_parser.dart';

/// Grid tile summarising the check-engine light and fault codes.
class EngineCodesCard extends StatelessWidget {
  const EngineCodesCard({super.key, required this.onTap, this.muted = false});

  final VoidCallback onTap;

  /// Paused or saved data: the count goes grey but a raised alert stays visible.
  final bool muted;

  static const _secondary = AppTheme.secondarySlate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DtcStatus?>(
      valueListenable: bt.BluetoothService().dtcStatus,
      builder: (context, status, _) => _buildCard(context, status),
    );
  }

  Widget _buildCard(BuildContext context, DtcStatus? status) {
    final theme = Theme.of(context);
    final stored = status?.stored.length ?? 0;
    final pending = status?.pending.length ?? 0;
    final milOn = status?.milOn == true;
    final attention = status != null && (milOn || stored > 0 || pending > 0);

    final Color accent;
    final String label;
    if (status == null) {
      accent = _secondary;
      label = 'Checking\u2026';
    } else if (milOn) {
      accent = AppTheme.errorRedLight;
      label = 'Light on';
    } else if (stored > 0) {
      accent = AppTheme.warningYellow;
      label = 'Stored';
    } else if (pending > 0) {
      accent = AppTheme.warningYellow;
      label = '$pending pending';
    } else {
      accent = _secondary;
      label = 'All clear';
    }

    final countColor = muted
        ? _secondary
        : ((milOn || stored > 0) ? accent : Colors.white);

    return Card(
      elevation: 4,
      color: AppTheme.primarySlate,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: !muted && attention
              ? accent
              : Colors.white.withValues(alpha: 0.08),
          width: !muted && attention ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.car_repair,
                        size: 18,
                        // Stays coloured when paused so stored faults are never hidden.
                        color: attention ? accent : _secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Engine Codes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status == null ? '\u2014' : '$stored',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: countColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (!muted && attention)
                                  ? accent
                                  : _secondary,
                              fontWeight: attention
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: _secondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
