/// Pure parsers for OBD-II Mode 01 replies from an ELM327-style adapter.

/// Splits an adapter reply into trimmed, space-free, upper-case lines.
List<String> replyLines(String raw) => raw
    .split(RegExp(r'[\r\n]+'))
    .map((l) => l.replaceAll('>', '').replaceAll(' ', '').trim().toUpperCase())
    .where((l) => l.isNotEmpty)
    .toList();

/// Data bytes of the first reply to Mode 01 [pid], or null if there is none.
List<int>? pidBytes(String raw, int pid) {
  final prefix = '41${pid.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  for (final line in replyLines(raw)) {
    if (!line.startsWith(prefix)) continue;
    final hex = line.substring(prefix.length);
    final bytes = <int>[];
    for (var i = 0; i + 2 <= hex.length; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (b == null) return null;
      bytes.add(b);
    }
    return bytes;
  }
  return null;
}

int? parseRpm(String raw) {
  final b = pidBytes(raw, 0x0C);
  if (b == null || b.length < 2) return null;
  return ((b[0] << 8) | b[1]) ~/ 4;
}

int? parseSpeed(String raw) {
  final b = pidBytes(raw, 0x0D);
  if (b == null || b.isEmpty) return null;
  return b[0];
}

int? parseCoolantTemp(String raw) {
  final b = pidBytes(raw, 0x05);
  if (b == null || b.isEmpty) return null;
  return b[0] - 40;
}

int? parseIntakeAirTemp(String raw) {
  final b = pidBytes(raw, 0x0F);
  if (b == null || b.isEmpty) return null;
  return b[0] - 40;
}

double? parseThrottle(String raw) {
  final b = pidBytes(raw, 0x11);
  if (b == null || b.isEmpty) return null;
  return b[0] * 100.0 / 255.0;
}

double? parseEngineLoad(String raw) {
  final b = pidBytes(raw, 0x04);
  if (b == null || b.isEmpty) return null;
  return b[0] * 100.0 / 255.0;
}

double? parseFuelLevel(String raw) {
  final b = pidBytes(raw, 0x2F);
  if (b == null || b.isEmpty) return null;
  return b[0] * 100.0 / 255.0;
}

/// Fuel trims run from -100 % to +99.2 %.
double? _fuelTrim(String raw, int pid) {
  final b = pidBytes(raw, pid);
  if (b == null || b.isEmpty) return null;
  return (b[0] - 128) * 100.0 / 128.0;
}

double? parseShortTermFuelTrim(String raw) => _fuelTrim(raw, 0x06);

double? parseLongTermFuelTrim(String raw) => _fuelTrim(raw, 0x07);

/// Mass air flow in g/s.
double? parseMafRate(String raw) {
  final b = pidBytes(raw, 0x10);
  if (b == null || b.length < 2) return null;
  return ((b[0] << 8) | b[1]) / 100.0;
}

/// Intake manifold absolute pressure in kPa.
int? parseManifoldPressure(String raw) {
  final b = pidBytes(raw, 0x0B);
  if (b == null || b.isEmpty) return null;
  return b[0];
}

/// Ignition timing advance in degrees before top dead centre.
double? parseTimingAdvance(String raw) {
  final b = pidBytes(raw, 0x0E);
  if (b == null || b.isEmpty) return null;
  return b[0] / 2.0 - 64.0;
}

int? parseOilTemp(String raw) {
  final b = pidBytes(raw, 0x5C);
  if (b == null || b.isEmpty) return null;
  return b[0] - 40;
}

int? parseAmbientTemp(String raw) {
  final b = pidBytes(raw, 0x46);
  if (b == null || b.isEmpty) return null;
  return b[0] - 40;
}

/// Control module voltage (PID 0142), used when ATRV is unusable.
double? parseControlModuleVoltage(String raw) {
  final b = pidBytes(raw, 0x42);
  if (b == null || b.length < 2) return null;
  return ((b[0] << 8) | b[1]) / 1000.0;
}

/// Adapter voltage from ATRV ("12.4V"); null outside a plausible car range.
double? parseAtrv(String raw) {
  final match = RegExp(r'(\d+\.\d+)\s*[Vv]').firstMatch(raw);
  if (match == null) return null;
  final v = double.tryParse(match.group(1)!);
  if (v != null && v >= 9.0 && v <= 16.0) return v;
  return null;
}

/// Which PIDs one "supported PIDs" block (0100, 0120, ...) reports.
class SupportedPids {
  const SupportedPids(this.pids, this.hasNext);

  final Set<int> pids;

  /// True when the car also supports the next block (base + 0x20).
  final bool hasNext;
}

SupportedPids? parseSupportedPids(String raw, int base) {
  final prefix = '41${base.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  final pids = <int>{};
  var any = false;
  var hasNext = false;

  for (final line in replyLines(raw)) {
    if (!line.startsWith(prefix)) continue;
    final bytes = pidBytes(line, base);
    if (bytes == null || bytes.length < 4) continue;
    any = true;
    final mask =
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    for (var i = 1; i <= 32; i++) {
      if (((mask >> (32 - i)) & 1) == 1) pids.add(base + i);
    }
    if ((mask & 1) == 1) hasNext = true;
  }
  return any ? SupportedPids(pids, hasNext) : null;
}
