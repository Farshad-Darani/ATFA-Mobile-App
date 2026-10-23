import 'package:flutter_test/flutter_test.dart';
import 'package:atfa/services/dtc_parser.dart';

void main() {
  group('decodeDtc', () {
    test('decodes powertrain and network codes', () {
      expect(decodeDtc('0133'), 'P0133');
      expect(decodeDtc('0300'), 'P0300');
      expect(decodeDtc('4123'), 'C0123');
      expect(decodeDtc('C100'), 'U0100');
      expect(decodeDtc('9234'), 'B1234');
    });
  });

  group('parseMonitorStatus', () {
    test('reads light on with two codes', () {
      final status = parseMonitorStatus('41 01 82 07 E5 00\r\n>');
      expect(status?.milOn, isTrue);
      expect(status?.dtcCount, 2);
    });

    test('reads light off with no codes', () {
      final status = parseMonitorStatus('0101\r41 01 00 07 E5 00\r\r>');
      expect(status?.milOn, isFalse);
      expect(status?.dtcCount, 0);
    });

    test('returns null when there is no reply', () {
      expect(parseMonitorStatus('NO DATA\r\r>'), isNull);
    });
  });

  group('parseDtcResponse', () {
    test('CAN single frame with a count byte', () {
      final codes = parseDtcResponse(
        '43 02 01 33 02 44 00\r\r>',
        sid: '43',
        isCan: true,
      );
      expect(codes, ['P0133', 'P0244']);
    });

    test('CAN reply with no codes', () {
      expect(
        parseDtcResponse('43 00 00 00 00 00 00\r>', sid: '43', isCan: true),
        isEmpty,
      );
    });

    test('CAN multi-frame reply', () {
      final codes = parseDtcResponse(
        '00A\r0: 43 04 01 33 03 00\r1: 01 71 02 44 00 00\r\r>',
        sid: '43',
        isCan: true,
      );
      expect(codes, ['P0133', 'P0300', 'P0171', 'P0244']);
    });

    test('legacy protocol has no count byte and may split across lines', () {
      final codes = parseDtcResponse(
        '43 01 33 03 00 00 00\r43 01 71 00 00 00 00\r\r>',
        sid: '43',
        isCan: false,
      );
      expect(codes, ['P0133', 'P0300', 'P0171']);
    });

    test('ignores echo, searching and no-data lines', () {
      expect(
        parseDtcResponse(
          '07\rSEARCHING...\rNO DATA\r\r>',
          sid: '47',
          isCan: true,
        ),
        isEmpty,
      );
    });

    test('combines several ECUs without duplicates', () {
      final codes = parseDtcResponse(
        '43 01 03 00 00 00 00\r43 02 03 00 01 71 00\r\r>',
        sid: '43',
        isCan: true,
      );
      expect(codes, ['P0300', 'P0171']);
    });

    test('pending codes use the 47 service id', () {
      expect(
        parseDtcResponse('47 01 01 71 00 00 00\r>', sid: '47', isCan: true),
        ['P0171'],
      );
    });
  });

  group('isCanProtocolReply', () {
    test('recognises CAN and legacy protocols', () {
      expect(isCanProtocolReply('A6\r>'), isTrue);
      expect(isCanProtocolReply('6\r>'), isTrue);
      expect(isCanProtocolReply('ATDPN\rA3\r>'), isFalse);
      expect(isCanProtocolReply('A1\r>'), isFalse);
    });
  });
}
