import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../config/app_theme.dart';

// ── Q&A pair for follow-up chat ───────────────────────────────────────────────
class _QAPair {
  final String question;
  final String answer;
  _QAPair({required this.question, required this.answer});
}

class DiagnosePage extends StatefulWidget {
  const DiagnosePage({super.key});

  @override
  State<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends State<DiagnosePage>
    with AutomaticKeepAliveClientMixin {
  final _aiService = AiService();
  final _btService = bt_service.BluetoothService();

  DashboardInsights? _insights;
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastRefresh;
  Map<String, dynamic> _vehicleData = {};
  int _retryCount = 0;
  String _loadingMessage = 'Analyzing your vehicle...';

  final List<_QAPair> _chatHistory = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isChatLoading = false;
  Timer? _stripTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
    // Refresh strip every 2s so live/paused state stays in sync
    _stripTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted) return;
        setState(() {});
        // Auto-refresh every 2 minutes silently
        if (_hasLoaded && !_isLoading && _lastRefresh != null &&
            DateTime.now().difference(_lastRefresh!).inSeconds >= 120) {
          _loadInsights(force: true);
        }
      },
    );
  }

  Future<void> _loadInsights({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force) return;
    _retryCount = 0;
    if (force && mounted) setState(() { _insights = null; });
    await _attemptLoad();
  }

  Future<void> _attemptLoad() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = _btService.lastData.isEmpty && _btService.isConnected
          ? 'Waiting for vehicle data...'
          : 'Analyzing your vehicle...';
    });

    // If connected but no data cached yet, wait up to 3×3s for first data
    if (_btService.lastData.isEmpty && _btService.isConnected && _retryCount < 3) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (_btService.lastData.isEmpty) {
        _retryCount++;
        if (mounted) setState(() => _loadingMessage = 'Connecting to vehicle... ($_retryCount/3)');
        return _attemptLoad();
      }
    }

    final cached = _btService.lastData;
    _vehicleData = cached.isNotEmpty
        ? cached
        : Map<String, dynamic>.from(_btService.getSimulatedData());

    if (mounted) setState(() => _loadingMessage = 'Analyzing your vehicle...');

    final insights = await _aiService.getDashboardInsights(_vehicleData);

    if (insights.isError && _retryCount < 2) {
      _retryCount++;
      if (mounted) setState(() => _loadingMessage = 'Retrying... ($_retryCount/3)');
      await Future.delayed(const Duration(seconds: 3));
      return _attemptLoad();
    }

    if (mounted) {
      setState(() {
        _insights = insights;
        _isLoading = false;
        _hasLoaded = !insights.isError;
        if (!insights.isError) _lastRefresh = DateTime.now();
      });
    }
  }

  Future<void> _sendQuestion() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isChatLoading) return;

    _inputController.clear();
    setState(() => _isChatLoading = true);
    _scrollToBottom();

    // Same pattern: use cached data rather than a competing BLE request
    final cached = _btService.lastData;
    final data = cached.isNotEmpty ? cached : _vehicleData;
    final answer = await _aiService.sendMessage(text, Map<String, dynamic>.from(data));

    if (mounted) {
      setState(() {
        _chatHistory.add(_QAPair(question: text, answer: answer));
        _isChatLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatRefreshTime() {
    if (_lastRefresh == null) return '';
    final diff = DateTime.now().difference(_lastRefresh!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return AppTheme.errorRed;
      case 'warning':
        return const Color(0xFFF59E0B); // amber — more readable than warningYellow
      default:
        return AppTheme.successGreen;
    }
  }

  Color _riskAccentColor(String riskText) {
    final lower = riskText.toLowerCase();
    if (lower.contains('no immediate') ||
        lower.contains('no risk') ||
        lower.contains('no action') ||
        lower.contains('normal')) {
      return AppTheme.successGreen;
    }
    if (lower.contains('critical') ||
        lower.contains('danger') ||
        lower.contains('urgent') ||
        lower.contains('fail')) {
      return AppTheme.errorRed;
    }
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.accentOrange,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('AI Diagnose'),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Sticky vehicle card — stays visible while insight cards scroll
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ValueListenableBuilder<bool>(
              valueListenable: _btService.isPaused,
              builder: (context, paused, _) => _buildVehicleCard(paused),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                if (_isLoading) ...[
                  _buildSkeletonCards(),
                ] else if (_insights != null && !_insights!.isError) ...[
                  _InsightCard(
                    icon: Icons.shield_outlined,
                    label: 'VEHICLE STATUS',
                    body: _insights!.status,
                    accentColor: _urgencyColor(_insights!.urgency),
                    badgeText: _insights!.urgency.toUpperCase(),
                    badgeColor: _urgencyColor(_insights!.urgency),
                  ),
                  const SizedBox(height: 12),
                  _InsightCard(
                    icon: Icons.warning_amber_outlined,
                    label: 'RISK ASSESSMENT',
                    body: _insights!.risk,
                    accentColor: _riskAccentColor(_insights!.risk),
                  ),
                  const SizedBox(height: 12),
                  _InsightCard(
                    icon: Icons.speed_outlined,
                    label: 'DRIVING ANALYSIS',
                    body: _insights!.driving,
                    accentColor: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  _InsightCard(
                    icon: Icons.task_alt_outlined,
                    label: 'RECOMMENDED ACTION',
                    body: _insights!.action,
                    accentColor: AppTheme.accentOrange,
                  ),
                  const SizedBox(height: 4),
                  _buildRefreshFooter(),
                ] else ...[
                  _buildErrorState(),
                ],
                const SizedBox(height: 28),
                _buildChatSection(),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Vehicle status card (mirrors connect page color pattern) ─────────────────
  Widget _buildVehicleCard(bool paused) {
    final connected = _btService.isConnected;
    final streaming = connected && !paused;
    final rpm = _vehicleData['rpm'];
    final temp = _vehicleData['coolantTemp'];
    final battery = _vehicleData['batteryVoltage'];

    // Orange fill when live (mirrors connect page), white when paused/offline
    final Color cardColor;
    final Color labelColor;
    final Color chipColor;
    final String statusLabel;

    if (streaming) {
      cardColor = AppTheme.accentOrange;
      labelColor = Colors.white;
      chipColor = Colors.white.withOpacity(0.85);
      statusLabel = 'LIVE DATA';
    } else if (connected && paused) {
      cardColor = Colors.white;
      labelColor = Colors.grey.shade400;
      chipColor = Colors.grey.shade400;
      statusLabel = 'PAUSED';
    } else {
      cardColor = Colors.white;
      labelColor = Colors.grey.shade400;
      chipColor = Colors.grey.shade400;
      statusLabel = 'NO VEHICLE CONNECTED';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: streaming
                ? AppTheme.accentOrange.withOpacity(0.3)
                : Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: labelColor),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: labelColor,
            ),
          ),
          // Live readings
          if (streaming && rpm != null) ...[
            const Spacer(),
            _readingChip(Icons.speed, '${rpm} rpm', color: chipColor),
            const SizedBox(width: 8),
            if (temp != null) _readingChip(Icons.thermostat_outlined, '${temp}°C', color: chipColor),
            if (battery != null) ...[
              const SizedBox(width: 8),
              _readingChip(Icons.battery_5_bar_outlined, '${battery}V', color: chipColor),
            ],
          ] else if (connected && paused && rpm != null) ...[
            // Greyed-out last known values
            const Spacer(),
            Opacity(
              opacity: 0.4,
              child: _readingChip(Icons.speed, '${rpm} rpm'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readingChip(IconData icon, String value, {Color? color}) {
    final c = color ?? const Color(0xFF94A3B8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }

  // ── Skeleton loading ─────────────────────────────────────────────────────────
  Widget _buildSkeletonCards() {
    return Column(
      children: [
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const _Shimmer(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _loadingMessage,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
            ),
          ],
        ),
      ],
    );
  }

  // ── Subtle "updated X ago · Refresh" footer ──────────────────────────────────
  Widget _buildRefreshFooter() {
    if (_lastRefresh == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => _loadInsights(force: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(
            'Updated ${_formatRefreshTime()} · Refresh',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Could not load analysis',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _loadInsights(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Follow-up chat section ───────────────────────────────────────────────────
  Widget _buildChatSection() {
    return Column(
      children: [
        // Divider with label
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ASK A FOLLOW-UP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: Colors.grey[400],
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        if (_chatHistory.isNotEmpty || _isChatLoading) ...[
          const SizedBox(height: 16),
          ..._chatHistory.map((pair) => _buildQAPair(pair)),
          if (_isChatLoading) _buildTypingBubble(),
        ],
      ],
    );
  }

  Widget _buildQAPair(_QAPair pair) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User question — right aligned
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.primarySlate,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                pair.question,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // AI answer — left aligned
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8, top: 2),
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppTheme.primarySlate,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.accentOrange,
                  size: 12,
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    pair.answer,
                    style: const TextStyle(
                      color: AppTheme.darkGrey,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 2),
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: AppTheme.primarySlate,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: AppTheme.accentOrange,
            size: 12,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const _TypingDots(),
        ),
      ],
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isChatLoading,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask a follow-up question...',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 13.5),
                filled: true,
                fillColor: AppTheme.pageBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendQuestion(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isChatLoading ? null : _sendQuestion,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isChatLoading
                    ? Colors.grey[300]
                    : AppTheme.primarySlate,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 18,
                color: _isChatLoading ? Colors.grey[500] : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stripTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ── Reusable insight card ─────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String body;
  final Color accentColor;
  final String? badgeText;
  final Color? badgeColor;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.body,
    required this.accentColor,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Colors.grey[500],
                  ),
                ),
                if (badgeText != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? accentColor).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor ?? accentColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body.isEmpty ? '—' : body,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.darkGrey,
                height: 1.62,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer skeleton for loading state ───────────────────────────────────────
class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.06 + _anim.value * 0.08;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _box(32, 32, radius: 8, opacity: opacity),
                  const SizedBox(width: 10),
                  _box(90, 11, radius: 4, opacity: opacity),
                ],
              ),
              const SizedBox(height: 12),
              _box(double.infinity, 11, radius: 4, opacity: opacity),
              const SizedBox(height: 6),
              _box(200, 11, radius: 4, opacity: opacity),
            ],
          ),
        );
      },
    );
  }

  Widget _box(double w, double h,
      {double radius = 4, required double opacity}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ── Animated typing dots ──────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i / 3) % 1.0;
            final opacity =
                (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

