import 'dart:math' as math;

import 'obd_parser.dart';

/// Fault-code (DTC) state read from the car.
class DtcStatus {
  const DtcStatus({
    required this.stored,
    required this.pending,
    required this.permanent,
    required this.milOn,
    required this.confirmedCount,
    required this.readAt,
  });

  /// Confirmed codes (Mode 03); these are what turn the check-engine light on.
  final List<String> stored;

  /// Codes seen once but not yet confirmed (Mode 07).
  final List<String> pending;

  /// Codes that stay until the car itself clears them (Mode 0A).
  final List<String> permanent;

  /// Check-engine light state; null when the car did not report it.
  final bool? milOn;

  /// Number of confirmed codes the car reports (PID 0101); null if unreported.
  final int? confirmedCount;

  final DateTime readAt;

  int get total => stored.length + pending.length + permanent.length;
}

/// Check-engine light and code count from PID 0101.
class MonitorStatus {
  const MonitorStatus({required this.milOn, required this.dtcCount});

  final bool milOn;
  final int dtcCount;
}

/// Reads the check-engine light and code count out of a PID 0101 reply.
MonitorStatus? parseMonitorStatus(String raw) {
  for (final line in replyLines(raw)) {
    if (line.startsWith('4101') && line.length >= 6) {
      final a = int.tryParse(line.substring(4, 6), radix: 16);
      if (a == null) continue;
      return MonitorStatus(milOn: (a & 0x80) != 0, dtcCount: a & 0x7F);
    }
  }
  return null;
}

/// Extracts fault codes from a Mode 03, 07 or 0A reply.
///
/// [sid] is the reply service id ('43', '47' or '4A'). CAN replies carry a
/// code-count byte after it; older protocols do not.
List<String> parseDtcResponse(
  String raw, {
  required String sid,
  required bool isCan,
}) {
  final messages = <String>[];
  final frame = RegExp(r'^([0-9A-F]):(.*)$');

  for (final line in replyLines(raw)) {
    final continuation = frame.firstMatch(line);
    if (continuation != null) {
      final index = continuation.group(1)!;
      final data = continuation.group(2)!;
      if (index == '0') {
        if (data.startsWith(sid)) messages.add(data);
      } else if (messages.isNotEmpty) {
        messages[messages.length - 1] += data;
      }
      continue;
    }
    // A bare 3-digit line is the byte count that precedes a multi-frame reply.
    if (RegExp(r'^[0-9A-F]{3}$').hasMatch(line)) continue;
    if (line.startsWith(sid)) messages.add(line);
  }

  final codes = <String>[];
  for (final message in messages) {
    var body = message.substring(sid.length);
    int? limit;
    if (isCan) {
      if (body.length < 2) continue;
      limit = int.tryParse(body.substring(0, 2), radix: 16);
      body = body.substring(2);
    }
    final groups = body.length ~/ 4;
    final take = limit == null ? groups : math.min(limit, groups);
    for (var i = 0; i < take; i++) {
      final code = decodeDtc(body.substring(i * 4, i * 4 + 4));
      if (code != null && code != 'P0000' && !codes.contains(code)) {
        codes.add(code);
      }
    }
  }
  return codes;
}

/// Turns two bytes (4 hex digits) into a code such as P0133.
String? decodeDtc(String hexCode) {
  if (hexCode.length != 4) return null;
  final byte1 = int.tryParse(hexCode.substring(0, 2), radix: 16);
  final byte2 = int.tryParse(hexCode.substring(2, 4), radix: 16);
  if (byte1 == null || byte2 == null) return null;

  const prefixes = ['P', 'C', 'B', 'U'];
  final prefix = prefixes[(byte1 >> 6) & 0x03];
  final digit1 = (byte1 >> 4) & 0x03;
  final digit2 = byte1 & 0x0F;
  final digit3 = (byte2 >> 4) & 0x0F;
  final digit4 = byte2 & 0x0F;

  String hex(int v) => v.toRadixString(16).toUpperCase();
  return '$prefix$digit1${hex(digit2)}${hex(digit3)}${hex(digit4)}';
}

/// Whether a reply to ATDPN ("A6", "6", ...) names a CAN protocol.
bool isCanProtocolReply(String raw) {
  for (final line in replyLines(raw)) {
    if (line.startsWith('ATDPN')) continue;
    final digit = line.replaceFirst(RegExp(r'^A'), '');
    if (digit.isEmpty) continue;
    return '6789'.contains(digit[0]);
  }
  // Most cars from 2008 on are CAN.
  return true;
}
