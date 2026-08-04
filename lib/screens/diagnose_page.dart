import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../config/app_theme.dart';
import 'auth/sign_up_page.dart';
import 'auth/sign_in_page.dart';
import '../widgets/vehicle_offline_prompt.dart';

// ── Q&A pair for follow-up chat ───────────────────────────────────────────────
class _QAPair {
  final String question;
  final String answer;
  _QAPair({required this.question, required this.answer});
}

// ── Limit-reached bottom sheet ────────────────────────────────────────────────
class _LimitReachedSheet extends StatelessWidget {
  final bool isAnonymous;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  const _LimitReachedSheet({
    required this.isAnonymous,
    required this.onSignUp,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAnonymous ? Icons.person_add_outlined : Icons.workspace_premium_outlined,
              color: AppTheme.accentOrange,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAnonymous ? 'Free analyses used up' : 'Monthly limit reached',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primarySlate,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAnonymous
                ? 'You\'ve used your 2 free AI analyses.\nCreate a free account to get 4 every month — no credit card needed.'
                : 'You\'ve used all 4 analyses this month.\nUpgrade to Pro for unlimited access every month.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 24),
          if (isAnonymous) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Free Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primarySlate,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.primarySlate),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sign In', style: TextStyle(fontSize: 16)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Upgrade to Pro — \$6.99/mo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Resets next month · Cancel anytime',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
}

class DiagnosePage extends StatefulWidget {
  final VoidCallback? onNavigateToConnect;

  const DiagnosePage({super.key, this.onNavigateToConnect});

  @override
  State<DiagnosePage> createState() => _DiagnosePageState();
}

enum _AnalysisPhase { initial, confirming, monitoring }

class _DiagnosePageState extends State<DiagnosePage>
    with AutomaticKeepAliveClientMixin {
  final _aiService = AiService();
  final _btService = bt_service.BluetoothService();

  static const String _savedInsightKey = 'diagnose_last_insight_v1';
  static const String _savedInsightAtKey = 'diagnose_last_insight_at_v1';

  DashboardInsights? _insights;
  DashboardInsights? _savedInsights;
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastRefresh;
  DateTime? _savedInsightsAt;
  Map<String, dynamic> _vehicleData = {};
  int _retryCount = 0;
  String _loadingMessage = 'Analyzing your vehicle...';

  final List<_QAPair> _chatHistory = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatSheetScrollController = ScrollController();
  final _chatFocusNode = FocusNode();
  bool _isChatLoading = false;
  Timer? _stripTimer;
  Timer? _autoRetryTimer;
  Timer? _confirmTimer;
  Timer? _phaseBannerTimer;
  int _autoRetrySecondsLeft = 0;
  _AnalysisPhase _analysisPhase = _AnalysisPhase.initial;
  int _successfulAnalyses = 0;
  bool _showPhaseBanner = true;
  bool _showRefreshFooter = false;
  bool _isPullRefreshing = false;
  bool _showPullRefreshIcon = false;
  bool _isPullRefreshArmed = false;
  Timer? _pullRefreshHintHideTimer;
  bool _showHeaderSyncHint = false;
  Timer? _headerSyncHintTimer;
  Future<void>? _activeLoadFuture;

  // Keep short in-memory context for better follow-up analysis quality.
  final List<Map<String, dynamic>> _sampleBuffer = [];
  final List<DashboardInsights> _analysisHistory = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncRefreshFooterVisibility);
    _btService.isPaused.addListener(_handlePauseStateChanged);
    unawaited(_loadSavedInsights());
    _loadInsights();
    _showPhaseBannerTemporarily();
    // Refresh strip every 2s so live/paused state stays in sync
    _stripTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted) return;
        if (_isStreamPaused) {
          if (_isLoading) {
            setState(() => _isLoading = false);
          }
          return;
        }
        if (!_hasVehicleConnection && (_insights != null || _hasLoaded || _isLoading)) {
          _clearInsightsForDisconnectedState();
          return;
        }
        _recordSample();
        setState(() {});
        // Trigger first load automatically once live data arrives.
        if (!_hasLoaded && !_isLoading && _activeLoadFuture == null &&
            _hasLiveVehicleSnapshot) {
          _loadInsights();
          return;
        }
        // Auto-refresh every 90s silently while monitoring.
        if (_hasLoaded && !_isLoading && _lastRefresh != null &&
            !_isStreamPaused &&
            _hasLiveVehicleSnapshot &&
            DateTime.now().difference(_lastRefresh!).inSeconds >= 90) {
          _loadInsights(force: true);
        }
      },
    );
  }

  void _syncRefreshFooterVisibility() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 80;
    if (shouldShow != _showRefreshFooter && mounted) {
      setState(() => _showRefreshFooter = shouldShow);
    }

    // Pull-to-refresh hint should only appear at top of list.
    if (_scrollController.offset > 2 && _showPullRefreshIcon && mounted) {
      setState(() {
        _showPullRefreshIcon = false;
        _isPullRefreshArmed = false;
      });
    }
  }

  bool get _hasVehicleConnection => _btService.isConnected;

  bool get _isStreamPaused => _btService.isPaused.value;

  bool get _hasLiveVehicleSnapshot =>
      _hasVehicleConnection && _btService.lastData.isNotEmpty;

  void _handlePauseStateChanged() {
    if (!mounted) return;
    if (_isStreamPaused) {
      _cancelAutoRetry();
      _headerSyncHintTimer?.cancel();
      setState(() {
        _isLoading = false;
        _showHeaderSyncHint = false;
      });
      return;
    }

    setState(() {});
    if (_hasVehicleConnection) {
      _loadInsights(force: true);
    }
  }

  void _clearInsightsForDisconnectedState() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasLoaded = false;
      _insights = null;
      _vehicleData = {};
      _loadingMessage = 'Connect to a vehicle to start diagnosis.';
      _showHeaderSyncHint = false;
    });
  }

  void _triggerHeaderSyncHint() {
    _headerSyncHintTimer?.cancel();
    if (mounted) {
      setState(() {
        _showHeaderSyncHint = true;
      });
    } else {
      _showHeaderSyncHint = true;
    }

    _headerSyncHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_showHeaderSyncHint) return;
      setState(() => _showHeaderSyncHint = false);
    });
  }

  Future<void> _loadSavedInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_savedInsightKey);
    if (encoded == null || encoded.isEmpty) return;

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final savedAt = prefs.getString(_savedInsightAtKey);
      final insight = DashboardInsights(
        status: (decoded['status'] as String?)?.trim() ?? '',
        risk: (decoded['risk'] as String?)?.trim() ?? '',
        driving: (decoded['driving'] as String?)?.trim() ?? '',
        action: (decoded['action'] as String?)?.trim() ?? '',
        mechanicNote: (decoded['mechanicNote'] as String?)?.trim() ?? '',
        progressComparedToLast:
            (decoded['progressComparedToLast'] as String?)?.trim() ?? '',
        urgency: (decoded['urgency'] as String?)?.trim().toLowerCase() ?? 'normal',
        isError: false,
      );

      if (!mounted) return;
      setState(() {
        _savedInsights = insight;
        _savedInsightsAt = savedAt == null ? null : DateTime.tryParse(savedAt);
      });
    } catch (_) {
      // Ignore malformed cached data and fall back to the offline prompt.
    }
  }

  Future<void> _persistLastInsight(DashboardInsights insight) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString(
      _savedInsightKey,
      jsonEncode({
        'status': insight.status,
        'risk': insight.risk,
        'driving': insight.driving,
        'action': insight.action,
        'mechanicNote': insight.mechanicNote,
        'progressComparedToLast': insight.progressComparedToLast,
        'urgency': insight.urgency,
      }),
    );
    await prefs.setString(_savedInsightAtKey, now);

    if (!mounted) return;
    setState(() {
      _savedInsights = insight;
      _savedInsightsAt = DateTime.tryParse(now);
    });
  }

  Future<void> _loadInsights({bool force = false}) async {
    if (_isStreamPaused) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Live data is paused. Showing last update.';
        });
      }
      return;
    }
    if (_activeLoadFuture != null) {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Already refreshing...';
          _showRefreshFooter = true;
        });
      }
      return _activeLoadFuture!;
    }
    if (_hasLoaded && !force) return;
    _retryCount = 0;
    final future = _attemptLoad();
    _activeLoadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_activeLoadFuture, future)) {
        _activeLoadFuture = null;
      }
    }
  }

  Future<void> _handlePullToRefresh() async {
    if (!mounted) return;
    setState(() => _isPullRefreshing = true);
    try {
      await _loadInsights(force: true);
    } finally {
      if (mounted) {
        setState(() => _isPullRefreshing = false);
      }
    }
  }

  Future<void> _runDiagnosisNow() async {
    if (!_hasVehicleConnection || _isLoading) return;

    if (_isStreamPaused) {
      _btService.setPaused(false);
    }

    if (mounted) {
      setState(() => _loadingMessage = 'Collecting live samples...');
    }

    try {
      await _btService.getRealTimeData();
    } catch (_) {
      // _loadInsights handles retries and fallback states.
    }

    await _loadInsights(force: true);
  }

  void _handlePullRefreshStatusChanged(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    final bool atTop = !_scrollController.hasClients || _scrollController.offset <= 2;
    if (!atTop) {
      if (_showPullRefreshIcon || _isPullRefreshArmed) {
        setState(() {
          _showPullRefreshIcon = false;
          _isPullRefreshArmed = false;
        });
      }
      return;
    }

    final isPulling =
        status == RefreshIndicatorStatus.drag ||
        status == RefreshIndicatorStatus.armed;
    final isArmed = status == RefreshIndicatorStatus.armed;

    _pullRefreshHintHideTimer?.cancel();

    if (isPulling) {
      if (_showPullRefreshIcon == true && _isPullRefreshArmed == isArmed) {
        return;
      }
      setState(() {
        _showPullRefreshIcon = true;
        _isPullRefreshArmed = isArmed;
      });
      return;
    }

    if (_isPullRefreshArmed) {
      setState(() => _isPullRefreshArmed = false);
    }

    if (!_showPullRefreshIcon) return;

    _pullRefreshHintHideTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_showPullRefreshIcon) return;
      setState(() => _showPullRefreshIcon = false);
    });
  }

  Future<void> _attemptLoad() async {
    if (!mounted) return;
    _cancelAutoRetry();

    if (!_hasVehicleConnection) {
      _clearInsightsForDisconnectedState();
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _phaseLoadingMessage();
    });
    if (_insights != null && !_insights!.isError) {
      _triggerHeaderSyncHint();
    }

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
    if (cached.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = false;
          _insights = null;
          _loadingMessage = 'Waiting for live vehicle data...';
        });
      }
      return;
    }

    _vehicleData = cached;
    _recordSample();

    if (mounted) setState(() => _loadingMessage = _phaseLoadingMessage());

    final analysisPayload = _buildAnalysisPayload();
    final insights = await _aiService.getDashboardInsights(analysisPayload);

    // Limit reached — don't retry, show the appropriate modal instead
    if (insights.isLimitReached) {
      if (mounted) {
        setState(() {
          _insights = insights;
          _isLoading = false;
          _hasLoaded = false;
        });
        _showLimitModal(insights.isAnonymousLimit);
      }
      return;
    }

    if (insights.isError && _retryCount < 2) {
      _retryCount++;
      if (mounted) setState(() => _loadingMessage = 'Retrying... ($_retryCount/3)');
      await Future.delayed(const Duration(seconds: 3));
      return _attemptLoad();
    }

    if (!mounted) return;

    final existingStable = _insights != null && !_insights!.isError;
    if (insights.isError) {
      setState(() {
        _isLoading = false;
        if (existingStable) {
          // Keep currently visible diagnosis while background retry runs.
          _hasLoaded = true;
        } else if (_savedInsights != null) {
          // Fall back to the last saved successful diagnosis.
          _insights = _savedInsights;
          _hasLoaded = true;
        } else {
          _insights = insights;
          _hasLoaded = false;
        }
      });
      if (existingStable || _savedInsights != null) {
        _triggerHeaderSyncHint();
      }
      _scheduleAutoRetry();
      return;
    }

    setState(() {
      _insights = insights;
      _isLoading = false;
      _hasLoaded = true;
      _lastRefresh = DateTime.now();
    });
    _rememberAnalysis(insights);
    _advanceAnalysisPhaseAfterSuccess();
    unawaited(_persistLastInsight(insights));
    _cancelAutoRetry();
  }

  String _phaseLoadingMessage() {
    if (_btService.lastData.isEmpty && _btService.isConnected) {
      return 'Waiting for vehicle data...';
    }
    switch (_analysisPhase) {
      case _AnalysisPhase.initial:
        return 'Reading your vehicle status...';
      case _AnalysisPhase.confirming:
        return 'Re-checking to confirm...';
      case _AnalysisPhase.monitoring:
        return 'Monitoring for changes...';
    }
  }

  void _recordSample() {
    final live = _btService.lastData;
    if (live.isEmpty || live['rpm'] == null) return;

    final sample = Map<String, dynamic>.from(live)
      ..['sampledAt'] = DateTime.now().toIso8601String();
    _sampleBuffer.add(sample);

    // Keep roughly the last 2 minutes of 2-second samples.
    if (_sampleBuffer.length > 60) {
      _sampleBuffer.removeRange(0, _sampleBuffer.length - 60);
    }
  }

  Map<String, dynamic> _buildAnalysisPayload() {
    final payload = Map<String, dynamic>.from(_vehicleData);
    payload['analysisStage'] = _analysisPhase.name;
    payload['trendSummary'] = _buildTrendSummary();
    if (_analysisHistory.isNotEmpty) {
      payload['previousAssessment'] = _compactInsight(_analysisHistory.first);
      payload['recentAssessmentHistory'] = _analysisHistory
          .take(3)
          .map(_compactInsight)
          .join(' | ');
    } else if (_savedInsights != null) {
      payload['previousAssessment'] = _compactInsight(_savedInsights!);
      payload['previousAssessmentAge'] = _formatSavedInsightTime();
    }
    return payload;
  }

  String _buildTrendSummary() {
    if (_sampleBuffer.length < 2) return 'Not enough samples yet for trend analysis.';

    num? firstNum(String key) => _sampleBuffer.first[key] as num?;
    num? lastNum(String key) => _sampleBuffer.last[key] as num?;
    num avg(String key) {
      final values = _sampleBuffer.map((s) => s[key]).whereType<num>().toList();
      if (values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final rpmStart = firstNum('rpm') ?? 0;
    final rpmEnd = lastNum('rpm') ?? 0;
    final tempStart = firstNum('coolantTemp') ?? 0;
    final tempEnd = lastNum('coolantTemp') ?? 0;
    final voltStart = firstNum('batteryVoltage') ?? 0;
    final voltEnd = lastNum('batteryVoltage') ?? 0;

    String trend(num start, num end) {
      final delta = end - start;
      if (delta.abs() < 0.5) return 'stable';
      return delta > 0 ? 'rising' : 'falling';
    }

    return 'Trend window (${_sampleBuffer.length} samples): '
        'RPM ${trend(rpmStart, rpmEnd)} (avg ${avg('rpm').toStringAsFixed(0)}), '
        'coolant ${trend(tempStart, tempEnd)} (avg ${avg('coolantTemp').toStringAsFixed(1)}°C), '
        'battery ${trend(voltStart, voltEnd)} (avg ${avg('batteryVoltage').toStringAsFixed(2)}V).';
  }

  String _compactInsight(DashboardInsights insight) {
    return 'status=${insight.status}; risk=${insight.risk}; action=${insight.action}; '
        'mechanicNote=${insight.mechanicNote}; compare=${insight.progressComparedToLast}; urgency=${insight.urgency}';
  }

  void _rememberAnalysis(DashboardInsights insight) {
    _analysisHistory.insert(0, insight);
    if (_analysisHistory.length > 5) {
      _analysisHistory.removeRange(5, _analysisHistory.length);
    }
  }

  void _advanceAnalysisPhaseAfterSuccess() {
    _successfulAnalyses++;
    if (_successfulAnalyses == 1) {
      _analysisPhase = _AnalysisPhase.confirming;
      _showPhaseBannerTemporarily();
      _scheduleConfirmationPass();
      return;
    }
    _analysisPhase = _AnalysisPhase.monitoring;
    _showPhaseBannerTemporarily();
  }

  void _showPhaseBannerTemporarily() {
    _phaseBannerTimer?.cancel();
    if (mounted) {
      setState(() => _showPhaseBanner = true);
    } else {
      _showPhaseBanner = true;
    }

    _phaseBannerTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _showPhaseBanner = false);
    });
  }

  void _scheduleConfirmationPass() {
    _confirmTimer?.cancel();
    _confirmTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _isLoading) return;
      _loadInsights(force: true);
    });
  }

  void _scheduleAutoRetry() {
    _cancelAutoRetry();
    _autoRetrySecondsLeft = 6;
    if (mounted) setState(() {});

    _autoRetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isLoading) return;

      if (_autoRetrySecondsLeft <= 1) {
        timer.cancel();
        _autoRetrySecondsLeft = 0;
        _loadInsights(force: true);
      } else {
        setState(() => _autoRetrySecondsLeft--);
      }
    });
  }

  void _cancelAutoRetry() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
    _autoRetrySecondsLeft = 0;
  }

  // ── Limit-reached modals ────────────────────────────────────────────────────
  void _showLimitModal(bool isAnonymous) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LimitReachedSheet(
        isAnonymous: isAnonymous,
        onSignUp: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
        },
        onSignIn: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage()));
        },
      ),
    );
  }

  Future<void> _sendQuestionFromSheet(StateSetter sheetSetState) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isChatLoading) return;

    if (!_hasLiveVehicleSnapshot || _insights == null || _insights!.isError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to live vehicle data before asking follow-up questions.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _inputController.clear();
    setState(() => _isChatLoading = true);
    sheetSetState(() {});
    _scrollChatSheetToBottom();

    final cached = _btService.lastData;
    final data = cached.isNotEmpty ? cached : _vehicleData;
    final answer = await _aiService.sendMessage(text, Map<String, dynamic>.from(data));

    if (mounted) {
      setState(() {
        _chatHistory.add(_QAPair(question: text, answer: answer));
        _isChatLoading = false;
      });
      sheetSetState(() {});
      _scrollChatSheetToBottom();
    }
  }

  void _scrollChatSheetToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatSheetScrollController.hasClients) {
        _chatSheetScrollController.animateTo(
          _chatSheetScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openFollowUpSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.76,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                    child: Row(
                      children: [
                        Text(
                          'FOLLOW-UP CHAT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: _chatSheetScrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: [
                        if (_chatHistory.isNotEmpty || _isChatLoading) ...[
                          ..._chatHistory.map((pair) => _buildQAPair(pair)),
                          if (_isChatLoading) _buildTypingBubble(),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.pageBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.20)),
                            ),
                            child: Text(
                              'Ask anything about your diagnostics and we will explain it in plain language.',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      math.max(
                            MediaQuery.of(context).viewInsets.bottom,
                            MediaQuery.of(context).viewPadding.bottom,
                          ) +
                          14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            focusNode: _chatFocusNode,
                            enabled: !_isChatLoading,
                            textCapitalization: TextCapitalization.sentences,
                            onTapOutside: (_) => FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              hintText: 'Ask a follow-up question...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
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
                            onSubmitted: (_) => _sendQuestionFromSheet(sheetSetState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isChatLoading
                              ? null
                              : () => _sendQuestionFromSheet(sheetSetState),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatRefreshTime() {
    if (_lastRefresh == null) return '';
    final diff = DateTime.now().difference(_lastRefresh!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _formatSavedInsightTime() {
    if (_savedInsightsAt == null) return 'Saved on this device';
    final diff = DateTime.now().difference(_savedInsightsAt!);
    if (diff.inSeconds < 60) return 'Saved just now';
    if (diff.inMinutes < 60) return 'Saved ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Saved ${diff.inHours}h ago';
    return 'Saved ${diff.inDays}d ago';
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
      return const Color(0xFFFBBF24); // warm yellow for low-risk
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
    final isPausedNow = _isStreamPaused;
    final hasStableInsights = _insights != null && !_insights!.isError;
    final showLoadingCards = (_isLoading || (!_hasLoaded && _hasLiveVehicleSnapshot && !isPausedNow))
        && (!hasStableInsights || _isPullRefreshing);
    final vehicleUnavailable = !_hasVehicleConnection;
    final connectedWithoutLiveData =
      _hasVehicleConnection && !_hasLiveVehicleSnapshot && !isPausedNow;
    final canShowFollowUp = hasStableInsights && _hasLoaded;
    final hasSavedOfflineSummary = (vehicleUnavailable || isPausedNow) && _savedInsights != null;
    final hasSavedConnectedSummary = connectedWithoutLiveData && _savedInsights != null;
    final showInlineReconnectState = !isPausedNow && _showHeaderSyncHint;

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
                color: AppTheme.accentOrange.withValues(alpha: 0.18),
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
            child: Stack(
              children: [
                RefreshIndicator.noSpinner(
                  onRefresh: _handlePullToRefresh,
                  onStatusChange: _handlePullRefreshStatusChanged,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    child: _showPhaseBanner
                        ? Padding(
                            key: const ValueKey('phase_banner_visible'),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPhaseBanner(),
                          )
                        : const SizedBox(
                            key: ValueKey('phase_banner_hidden'),
                          ),
                  ),
                  if (!showLoadingCards && !hasStableInsights) ...[
                    if (hasSavedOfflineSummary)
                      _buildSavedSummaryState()
                    else if (hasSavedConnectedSummary)
                      _buildSavedSummaryState()
                    else if (connectedWithoutLiveData)
                      const SizedBox.shrink()
                    else if (vehicleUnavailable)
                      _buildConnectionRequiredState()
                    else
                      _buildErrorState(),
                  ] else ...[
                    if (isPausedNow) ...[
                      _buildPausedNotice(),
                      const SizedBox(height: 12),
                    ],
                    _buildAnimatedInsightSlot(
                      slotId: 'status',
                      isLoading: showLoadingCards,
                      loadedContentKey:
                          '${_insights?.status ?? ''}|${_insights?.driving ?? ''}|${_insights?.urgency ?? ''}',
                      loadingBuilder: () => _LoadingInsightCard(
                        icon: Icons.shield_outlined,
                        label: 'VEHICLE STATUS',
                        accentColor: AppTheme.primaryBlue,
                        message: _loadingMessage,
                        phaseOffset: 0.0,
                      ),
                      loadedBuilder: () => _InsightCard(
                        icon: Icons.shield_outlined,
                        label: 'VEHICLE STATUS',
                        body: _insights!.driving.isEmpty
                            ? _insights!.status
                            : '${_insights!.status}\n\nDriving note: ${_insights!.driving}',
                        accentColor: AppTheme.primaryBlue,
                        badgeText: _insights!.urgency.toUpperCase(),
                        badgeColor: _urgencyColor(_insights!.urgency),
                        muted: isPausedNow,
                        animateHeaderSync: showInlineReconnectState,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedInsightSlot(
                      slotId: 'risk',
                      isLoading: showLoadingCards,
                      loadedContentKey: _insights?.risk ?? '',
                      loadingBuilder: () => const _LoadingInsightCard(
                        icon: Icons.warning_amber_outlined,
                        label: 'RISK ASSESSMENT',
                        accentColor: Color(0xFFF59E0B),
                        message: 'Cross-checking risk signals',
                        phaseOffset: 0.18,
                      ),
                      loadedBuilder: () => _InsightCard(
                        icon: Icons.warning_amber_outlined,
                        label: 'RISK ASSESSMENT',
                        body: _insights!.risk,
                        accentColor: _riskAccentColor(_insights!.risk),
                        muted: isPausedNow,
                        animateHeaderSync: showInlineReconnectState,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedInsightSlot(
                      slotId: 'action',
                      isLoading: showLoadingCards,
                      loadedContentKey: _insights?.action ?? '',
                      loadingBuilder: () => const _LoadingInsightCard(
                        icon: Icons.task_alt_outlined,
                        label: 'RECOMMENDED ACTION',
                        accentColor: AppTheme.successGreen,
                        message: 'Preparing recommendation',
                        phaseOffset: 0.36,
                      ),
                      loadedBuilder: () => _InsightCard(
                        icon: Icons.task_alt_outlined,
                        label: 'RECOMMENDED ACTION',
                        body: _insights!.action,
                        accentColor: AppTheme.successGreen,
                        muted: isPausedNow,
                        animateHeaderSync: showInlineReconnectState,
                      ),
                    ),
                    if ((_insights?.mechanicNote ?? '').isNotEmpty ||
                        (_insights?.progressComparedToLast ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildMechanicNoteCard(
                        _insights!,
                        muted: isPausedNow,
                      ),
                    ],
                    if (_showRefreshFooter) ...[
                      const SizedBox(height: 4),
                      _buildRefreshFooter(isRefreshing: _isLoading && hasStableInsights),
                    ],
                  ],
                  if (canShowFollowUp) ...[
                    const SizedBox(height: 20),
                    _buildFollowUpPromptCard(),
                    const SizedBox(height: 24),
                  ],
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset: _showPullRefreshIcon
                          ? Offset.zero
                          : const Offset(0, -0.55),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 230),
                        opacity: _showPullRefreshIcon ? 1 : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          scale: _showPullRefreshIcon ? 1 : 0.92,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            turns: _isPullRefreshArmed ? 0.04 : 0,
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: (_isPullRefreshArmed
                                          ? AppTheme.accentOrange
                                          : AppTheme.primarySlate)
                                      .withValues(alpha: 0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.07),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: _isPullRefreshArmed
                                    ? AppTheme.accentOrange
                                    : AppTheme.primarySlate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vehicle status card (mirrors connect page color pattern) ─────────────────
  Widget _buildVehicleCard(bool paused) {
    final connected = _btService.isConnected;
    final hasLiveSnapshot = _hasLiveVehicleSnapshot;
    final streaming = connected && !paused;
    final readyToRun = connected && !paused && !_hasLiveVehicleSnapshot;
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
      chipColor = Colors.white.withValues(alpha: 0.85);
      statusLabel = hasLiveSnapshot ? 'LIVE DATA' : 'CONNECTED';
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
        color: cardColor.withValues(alpha: streaming ? 0.94 : 0.88),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: streaming
                ? AppTheme.accentOrange.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
            _readingChip(Icons.speed, '$rpm rpm', color: chipColor),
            const SizedBox(width: 8),
            if (temp != null) _readingChip(Icons.thermostat_outlined, '$temp°C', color: chipColor),
            if (battery != null) ...[
              const SizedBox(width: 8),
              _readingChip(Icons.battery_5_bar_outlined, '${battery}V', color: chipColor),
            ],
          ] else if (!connected) ...[
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onNavigateToConnect,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.bluetooth_searching_rounded, size: 15),
              label: const Text(
                'Connect',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ] else if (readyToRun) ...[
            const Spacer(),
            TextButton.icon(
              onPressed: _isLoading ? null : _runDiagnosisNow,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: Text(
                _isLoading ? 'Running...' : 'Run',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ] else if (connected && paused && rpm != null) ...[
            // Greyed-out last known values
            const Spacer(),
            Opacity(
              opacity: 0.4,
              child: _readingChip(Icons.speed, '$rpm rpm'),
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

  Widget _buildAnimatedInsightSlot({
    required String slotId,
    required bool isLoading,
    String? loadedContentKey,
    required Widget Function() loadingBuilder,
    required Widget Function() loadedBuilder,
  }) {
    final child = isLoading ? loadingBuilder() : loadedBuilder();

    return AnimatedSize(
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 780),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(
            '${slotId}_${isLoading ? 'loading' : 'loaded'}_${loadedContentKey ?? ''}',
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Subtle "updated X ago · Refresh" footer ──────────────────────────────────
  Widget _buildRefreshFooter({bool isRefreshing = false}) {
    if (_lastRefresh == null) return const SizedBox.shrink();
    if (!_showRefreshFooter || isRefreshing) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.center,
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

  Widget _buildPhaseBanner() {
    final bool isRefreshingNow = _isLoading && (_insights != null && !_insights!.isError);
    final String title;
    final String subtitle;
    final IconData icon;
    final Color accent;

    if (_analysisPhase == _AnalysisPhase.initial || _successfulAnalyses == 0) {
      title = 'Initial Assessment';
      subtitle = _isLoading ? 'Reading live data and generating first result.' : 'First pass complete.';
      icon = Icons.bolt_outlined;
      accent = AppTheme.primaryBlue;
    } else if (_analysisPhase == _AnalysisPhase.confirming) {
      title = 'Confirmation Pass';
      subtitle = isRefreshingNow
          ? 'Re-checking with additional samples...'
          : 'A second pass runs automatically to improve certainty.';
      icon = Icons.verified_outlined;
      accent = const Color(0xFFF59E0B);
    } else {
      title = 'Continuous Monitoring';
      subtitle = isRefreshingNow
          ? 'Refreshing with latest ECU changes...'
          : 'Watching for changes and refreshing every ~90s.';
      icon = Icons.monitor_heart_outlined;
      accent = AppTheme.successGreen;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.2,
                    color: Colors.grey[600],
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

  Widget _buildErrorState() {
    final bool isAutoRetrying = _autoRetrySecondsLeft > 0;
    final String title = isAutoRetrying
        ? 'Reconnecting to analysis...'
        : 'Could not load analysis right now';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (isAutoRetrying) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Retrying automatically in $_autoRetrySecondsLeft s',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                  ),
                ],
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () => _loadInsights(force: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry now'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionRequiredState() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: VehicleOfflinePrompt(
          title: 'Vehicle is offline',
          message: 'Turn on Bluetooth and connect your vehicle before running AI diagnosis.',
          actionLabel: 'Go to Connect',
          onAction: widget.onNavigateToConnect,
        ),
      ),
    );
  }

  Widget _buildPausedNotice() {
    final String subtitle = _lastRefresh == null
        ? 'Live data paused. Showing the last known diagnosis.'
        : 'Live data paused. Last update ${_formatRefreshTime()}.';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primarySlate.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12.3, color: Colors.grey[700], height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSummaryState() {
    final summary = _savedInsights!;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primarySlate.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySlate.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 22,
                      color: AppTheme.primarySlate.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last known diagnosis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatSavedInsightTime(),
                          style: TextStyle(
                            fontSize: 12.2,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InsightCard(
              icon: Icons.shield_outlined,
              label: 'VEHICLE STATUS',
              body: summary.driving.isEmpty
                  ? summary.status
                  : '${summary.status}\n\nDriving note: ${summary.driving}',
              accentColor: AppTheme.primaryBlue,
              badgeText: 'SAVED',
              badgeColor: Colors.blueGrey,
              muted: true,
            ),
            const SizedBox(height: 12),
            _InsightCard(
              icon: Icons.warning_amber_outlined,
              label: 'RISK ASSESSMENT',
              body: summary.risk,
              accentColor: _riskAccentColor(summary.risk),
              muted: true,
            ),
            const SizedBox(height: 12),
            _InsightCard(
              icon: Icons.task_alt_outlined,
              label: 'RECOMMENDED ACTION',
              body: summary.action,
              accentColor: AppTheme.successGreen,
              muted: true,
            ),
            if (summary.mechanicNote.isNotEmpty ||
                summary.progressComparedToLast.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMechanicNoteCard(summary, isSaved: true, muted: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicNoteCard(
    DashboardInsights insight, {
    bool isSaved = false,
    bool muted = false,
  }) {
    final compare = insight.progressComparedToLast.trim();
    final note = insight.mechanicNote.trim();
    final headline = compare.isNotEmpty ? compare : note;
    final details = compare.isNotEmpty ? note : '';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF6F8FB) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: muted
              ? Colors.grey.withValues(alpha: 0.28)
              : AppTheme.primarySlate.withValues(alpha: 0.09),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: muted
                  ? Colors.blueGrey.withValues(alpha: 0.12)
                  : AppTheme.primarySlate.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.handyman_outlined,
              size: 16,
              color: muted
                  ? Colors.blueGrey.withValues(alpha: 0.85)
                  : AppTheme.primarySlate.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSaved ? 'MECHANIC NOTE (SAVED)' : 'MECHANIC NOTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppTheme.primarySlate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12.8,
                      height: 1.4,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpPromptCard() {
    return InkWell(
      onTap: () {
        _openFollowUpSheet();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primarySlate,
              AppTheme.primarySlate.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primarySlate.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ask a follow-up question...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.8,
                ),
              ),
            ),
          ],
        ),
      ),
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
                        color: Colors.black.withValues(alpha: 0.05),
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
                color: Colors.black.withValues(alpha: 0.05),
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

  @override
  void dispose() {
    _stripTimer?.cancel();
    _autoRetryTimer?.cancel();
    _confirmTimer?.cancel();
    _phaseBannerTimer?.cancel();
    _pullRefreshHintHideTimer?.cancel();
    _headerSyncHintTimer?.cancel();
    _scrollController.removeListener(_syncRefreshFooterVisibility);
    _btService.isPaused.removeListener(_handlePauseStateChanged);
    _chatFocusNode.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _chatSheetScrollController.dispose();
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
  final bool muted;
  final bool animateHeaderSync;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.body,
    required this.accentColor,
    this.badgeText,
    this.badgeColor,
    this.muted = false,
    this.animateHeaderSync = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgStart = muted
      ? const Color(0xFFE5E7EB)
      : Color.lerp(AppTheme.primarySlate, accentColor, 0.14)!;
    final Color bgEnd = muted
      ? const Color(0xFFCBD5E1)
      : Color.lerp(AppTheme.primarySlate, accentColor, 0.30)!;
    final Color textColor = muted ? const Color(0xFF334155) : Colors.white;
    final Color secondaryTextColor = muted
      ? const Color(0xFF475569)
      : Colors.white.withValues(alpha: 0.78);
    final Color iconChipColor = muted
      ? Colors.white.withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.14);
    final Color iconColor = muted ? const Color(0xFF475569) : Colors.white;
    final Color resolvedBadgeColor = muted
      ? Colors.blueGrey.withValues(alpha: 0.2)
      : (badgeColor ?? Colors.white.withValues(alpha: 0.15));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: muted ? Colors.grey.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: muted
                ? Colors.blueGrey.withValues(alpha: 0.12)
                : accentColor.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconChipColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                _AnimatedHeaderLabel(
                  label: label,
                  color: secondaryTextColor,
                  animate: animateHeaderSync,
                ),
                if (badgeText != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: resolvedBadgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: muted ? const Color(0xFF334155) : Colors.white,
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
              style: TextStyle(
                fontSize: 13.5,
                color: muted ? textColor : Colors.white.withValues(alpha: 0.94),
                height: 1.62,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHeaderLabel extends StatefulWidget {
  final String label;
  final Color color;
  final bool animate;

  const _AnimatedHeaderLabel({
    required this.label,
    required this.color,
    required this.animate,
  });

  @override
  State<_AnimatedHeaderLabel> createState() => _AnimatedHeaderLabelState();
}

class _AnimatedHeaderLabelState extends State<_AnimatedHeaderLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      color: widget.color,
    );

    if (!widget.animate) {
      return Text(widget.label, style: baseStyle);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final dx = math.sin(t * math.pi * 2) * 0.9;
        final alpha = (0.72 + (t * 0.28)).clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(dx, 0),
              child: Text(
                widget.label,
                style: baseStyle.copyWith(
                  color: widget.color.withValues(alpha: alpha),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _HeaderTrailingDots(
              progress: _ctrl.value,
              color: widget.color,
            ),
          ],
        );
      },
    );
  }
}

class _HeaderTrailingDots extends StatelessWidget {
  final double progress;
  final Color color;

  const _HeaderTrailingDots({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = (progress + i / 3) % 1.0;
        final opacity =
            (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.25, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.2),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 3.6,
              height: 3.6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.95),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Loading card that matches final card style ───────────────────────────────
class _LoadingInsightCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final String message;
  final double phaseOffset;

  const _LoadingInsightCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.message,
    this.phaseOffset = 0,
  });

  @override
  State<_LoadingInsightCard> createState() => _LoadingInsightCardState();
}

class _LoadingInsightCardState extends State<_LoadingInsightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = (_ctrl.value + widget.phaseOffset) % 1.0;
        final wave = (math.sin(t * math.pi * 2) + 1) / 2;
        final shadowBoost = 0.16 + (wave * 0.14);
        final iconLift = -1.5 + (wave * 3);
        final iconTilt = -0.05 + (wave * 0.10);
        final pulseAlpha = 0.10 + (wave * 0.12);

        final Color bgStart = Color.lerp(AppTheme.primarySlate, widget.accentColor, 0.14)!;
        final Color bgEnd = Color.lerp(AppTheme.primarySlate, widget.accentColor, 0.30)!;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgEnd],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: shadowBoost),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: pulseAlpha),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Transform.translate(
                          offset: Offset(0, iconLift),
                          child: Transform.rotate(
                            angle: iconTilt,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(widget.icon, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_rounded,
                          size: 16,
                          color: AppTheme.accentOrange,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 12.8,
                            color: Colors.white.withValues(alpha: 0.94),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const _AnalyzingDots(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyzingDots extends StatefulWidget {
  const _AnalyzingDots();

  @override
  State<_AnalyzingDots> createState() => _AnalyzingDotsState();
}

class _AnalyzingDotsState extends State<_AnalyzingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
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
                (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.15, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.6),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4.8,
                  height: 4.8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentOrange,
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

