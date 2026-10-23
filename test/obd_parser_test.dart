import 'package:flutter_test/flutter_test.dart';
import 'package:atfa/services/obd_parser.dart';

void main() {
  group('sensor parsers', () {
    test('decode the values seen from the adapter', () {
      expect(parseRpm('41 0C 48 6B \r\n>'), 4634);
      expect(parseSpeed('41 0D 81'), 129);
      expect(parseCoolantTemp('41 05 3B'), 19);
      expect(parseIntakeAirTemp('41 0F C9'), 161);
      expect(parseThrottle('41 11 A6'), closeTo(65.1, 0.1));
      expect(parseEngineLoad('41 04 1E'), closeTo(11.76, 0.01));
    });

    test('ignore the echoed command and find the reply line', () {
      expect(parseRpm('010C\r41 0C 1A F8\r\r>'), 1726);
    });

    test('additional sensors', () {
      expect(parseFuelLevel('41 2F 80'), closeTo(50.2, 0.1));
      expect(parseShortTermFuelTrim('41 06 80'), 0);
      expect(parseLongTermFuelTrim('41 07 90'), closeTo(12.5, 0.01));
      expect(parseLongTermFuelTrim('41 07 70'), closeTo(-12.5, 0.01));
      expect(parseMafRate('41 10 01 F4'), 5.0);
      expect(parseManifoldPressure('41 0B 63'), 99);
      expect(parseTimingAdvance('41 0E 8C'), 6.0);
      expect(parseOilTemp('41 5C 82'), 90);
      expect(parseAmbientTemp('41 46 3C'), 20);
      expect(parseOilTemp('NO DATA'), isNull);
    });

    test('return null for a missing or wrong reply', () {
      expect(parseRpm('NO DATA\r\r>'), isNull);
      expect(parseRpm('010C'), isNull);
      expect(parseSpeed('41 0C 48 6B'), isNull);
      expect(parseCoolantTemp(''), isNull);
    });

    test('control module voltage and ATRV', () {
      expect(parseControlModuleVoltage('41 42 38 A4'), closeTo(14.5, 0.01));
      expect(parseAtrv('ATRV\r12.2V\r\r>'), 12.2);
      expect(parseAtrv('3.1V'), isNull);
      expect(parseAtrv('?'), isNull);
    });
  });

  group('parseSupportedPids', () {
    test('reads the first block', () {
      final result = parseSupportedPids('41 00 BE 1F A8 13\r\r>', 0x00);
      expect(result, isNotNull);
      expect(
        result!.pids,
        containsAll([0x01, 0x04, 0x05, 0x0C, 0x0D, 0x0F, 0x11]),
      );
      expect(result.pids.contains(0x02), isFalse);
      expect(result.pids.contains(0x0B), isFalse);
      expect(result.hasNext, isTrue);
    });

    test('offsets later blocks and stops when there is no next block', () {
      final result = parseSupportedPids('41 20 80 00 00 00\r>', 0x20);
      expect(result!.pids, {0x21});
      expect(result.hasNext, isFalse);
    });

    test('returns null without a reply', () {
      expect(parseSupportedPids('NO DATA\r>', 0x00), isNull);
    });
  });
}
