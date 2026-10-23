import 'package:flutter_test/flutter_test.dart';
import 'package:atfa/services/dtc_descriptions.dart';

void main() {
  group('describeDtc', () {
    test('uses the exact entry when there is one', () {
      expect(describeDtc('P0171'), 'System Too Lean (Bank 1)');
      expect(describeDtc('p0171'), 'System Too Lean (Bank 1)');
    });

    test('builds O2 sensor, misfire, injector and coil descriptions', () {
      expect(
        describeDtc('P0142'),
        'O2 Sensor Circuit Malfunction (Bank 1, Sensor 3)',
      );
      expect(
        describeDtc('P0167'),
        'O2 Sensor Heater Circuit Malfunction (Bank 2, Sensor 3)',
      );
      expect(describeDtc('P0310'), 'Cylinder 10 Misfire Detected');
      expect(describeDtc('P0204'), contains('Cylinder 4'));
      expect(describeDtc('P0353'), startsWith('Ignition Coil C'));
    });

    test('falls back to the system for codes without an entry', () {
      expect(describeDtc('P0999'), startsWith('Transmission fault'));
      expect(describeDtc('P1234'), contains('Manufacturer-specific'));
      expect(describeDtc('U0199'), 'Lost communication with a control module');
      expect(describeDtc('C0999'), startsWith('Chassis'));
      expect(describeDtc('B0999'), startsWith('Body'));
    });

    test('never returns an empty string', () {
      expect(describeDtc(''), isNotEmpty);
      expect(describeDtc('XYZ'), isNotEmpty);
    });
  });
}
