import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/bluetooth_service.dart' as bt;
import '../services/dtc_parser.dart';

/// Bottom sheet listing the check-engine light state and every fault code.
Future<void> showEngineCodesSheet(
  BuildContext context, {
  required String Function(String code) describe,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.primarySlate,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _EngineCodesSheet(describe: describe, controller: controller),
    ),
  );
}

class _EngineCodesSheet extends StatefulWidget {
  const _EngineCodesSheet({required this.describe, required this.controller});

  final String Function(String code) describe;
  final ScrollController controller;

  @override
  State<_EngineCodesSheet> createState() => _EngineCodesSheetState();
}

class _EngineCodesSheetState extends State<_EngineCodesSheet> {
  static const _secondary = AppTheme.secondarySlate;

  final _service = bt.BluetoothService();
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final status = _service.dtcStatus.value;
    final stale =
        status == null ||
        DateTime.now().difference(status.readAt) > const Duration(seconds: 20);
    if (stale) WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    await _service.refreshDtcs();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear codes?'),
        content: const Text(
          'This turns off the check engine light and erases the stored codes. '
          'It also resets your car\'s readiness tests, so an emissions '
          'inspection may not pass until you have driven for a while.\n\n'
          'If the problem is not fixed, the codes will come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Clear codes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _notice = null;
    });
    final ok = await _service.clearDtcs();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = ok
          ? 'Codes cleared.'
          : 'The car did not accept the request. Turn the ignition on with the '
                'engine off, then try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<DtcStatus?>(
      valueListenable: _service.dtcStatus,
      builder: (context, status, _) {
        return ListView(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Engine Codes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _refresh,
                  tooltip: 'Check again',
                  icon: const Icon(Icons.refresh_rounded),
                  color: Colors.white70,
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: _secondary,
                  backgroundColor: Colors.white12,
                ),
              )
            else
              const SizedBox(height: 14),
            if (status == null)
              Text(
                'Asking the car for its fault codes\u2026',
                style: theme.textTheme.bodyMedium?.copyWith(color: _secondary),
              )
            else ...[
              _buildBanner(theme, status),
              if (_notice != null) _buildNotice(theme, _notice!),
              _section(
                theme,
                'Active codes',
                'Confirmed faults. These turn the light on.',
                status.stored,
                status.milOn == true
                    ? AppTheme.errorRedLight
                    : AppTheme.warningYellow,
              ),
              _section(
                theme,
                'Pending codes',
                'Seen once but not confirmed yet. They may clear on their own.',
                status.pending,
                AppTheme.warningYellow,
              ),
              _section(
                theme,
                'Permanent codes',
                'Stay until the car itself confirms the fault is fixed.',
                status.permanent,
                AppTheme.errorRedLight,
              ),
              if (status.stored.isNotEmpty || status.milOn == true) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear codes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRedLight,
                    side: const BorderSide(color: AppTheme.errorRedLight),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                if (status.permanent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Permanent codes cannot be cleared here. The car removes '
                      'them once the fault is fixed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _secondary,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text(
                'Descriptions are general guidance. Have a mechanic confirm '
                'the cause before any repair.',
                style: theme.textTheme.bodySmall?.copyWith(color: _secondary),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBanner(ThemeData theme, DtcStatus status) {
    final IconData icon;
    final Color color;
    final String title;
    final String text;

    if (status.milOn == true) {
      icon = Icons.warning_amber_rounded;
      color = AppTheme.errorRedLight;
      title = 'Check engine light is on';
      text =
          '${_plural(status.stored.length, 'confirmed code')}. Have the car '
          'checked soon. If the light is flashing, stop driving.';
    } else if (status.total > 0) {
      icon = Icons.info_outline_rounded;
      color = AppTheme.warningYellow;
      title = 'Light is off, but codes were found';
      text = 'The car has stored or pending codes. Keep an eye on them.';
    } else if (status.milOn == false) {
      icon = Icons.check_circle_outline_rounded;
      color = AppTheme.successGreenLight;
      title = 'No fault codes';
      text =
          'The check engine light is off and the car reports no stored, '
          'pending or permanent codes.';
    } else {
      icon = Icons.help_outline_rounded;
      color = _secondary;
      title = 'No codes reported';
      text = 'This car did not report the check engine light state.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(ThemeData theme, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _section(
    ThemeData theme,
    String title,
    String subtitle,
    List<String> codes,
    Color color,
  ) {
    if (codes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: _secondary),
          ),
          const SizedBox(height: 10),
          for (final code in codes) _codeTile(theme, code, color),
        ],
      ),
    );
  }

  Widget _codeTile(ThemeData theme, String code, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.describe(code),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}
