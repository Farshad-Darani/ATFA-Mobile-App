/// Plain-language names for OBD-II fault codes.
///
/// Lookup order: exact entry, generated families (O2 sensors, misfires, ...),
/// then a description of the code's system so no code is ever left blank.
String describeDtc(String code) {
  final c = code.trim().toUpperCase();
  return _known[c] ?? _fromFamily(c) ?? _fromCategory(c);
}

String? _fromFamily(String c) {
  final m = RegExp(r'^P(\d{4})$').firstMatch(c);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);

  // O2 sensors: per sensor five circuit faults, then the heater circuit.
  final inBank1 = n >= 130 && n <= 147;
  final inBank2 = n >= 150 && n <= 167;
  if (inBank1 || inBank2) {
    final first = inBank1 ? 130 : 150;
    final group = (n - first) ~/ 6;
    const types = [
      'Circuit Malfunction',
      'Circuit Low Voltage',
      'Circuit High Voltage',
      'Circuit Slow Response',
      'Circuit No Activity',
      'Heater Circuit Malfunction',
    ];
    final type = types[(n - first) % 6];
    return 'O2 Sensor $type (Bank ${inBank1 ? 1 : 2}, Sensor ${group + 1})';
  }

  if (n >= 301 && n <= 312) return 'Cylinder ${n - 300} Misfire Detected';
  if (n >= 201 && n <= 212) {
    return 'Injector Circuit Malfunction (Cylinder ${n - 200})';
  }
  if (n >= 351 && n <= 358) {
    final coil = String.fromCharCode('A'.codeUnitAt(0) + n - 351);
    return 'Ignition Coil $coil Primary/Secondary Circuit Malfunction';
  }
  return null;
}

String _fromCategory(String c) {
  if (!RegExp(r'^[PBCU][0-9A-F]{4}$').hasMatch(c)) {
    return 'Unrecognised fault code. Have a mechanic read it.';
  }
  final system = c[0];
  final kind = c[1];
  final manufacturer = system == 'P'
      ? (kind == '1' || kind == '3')
      : (kind == '1' || kind == '2');

  if (system == 'U' && !manufacturer) {
    final n = int.parse(c.substring(1), radix: 16);
    if (n >= 0x0100 && n <= 0x02FF) {
      return 'Lost communication with a control module';
    }
  }

  if (manufacturer) {
    const names = {
      'P': 'engine or transmission',
      'B': 'body',
      'C': 'chassis',
      'U': 'network',
    };
    return 'Manufacturer-specific ${names[system]} fault. The exact meaning '
        'depends on the car brand.';
  }

  switch (system) {
    case 'B':
      return 'Body system fault (airbags, climate, lighting or comfort). '
          'No detailed description yet.';
    case 'C':
      return 'Chassis fault (brakes, steering or suspension). '
          'No detailed description yet.';
    case 'U':
      return 'Vehicle network communication fault. '
          'No detailed description yet.';
  }

  const subsystems = {
    '0': 'Fuel or air system',
    '1': 'Fuel or air system',
    '2': 'Fuel or air system',
    '3': 'Ignition or misfire',
    '4': 'Emission control',
    '5': 'Idle or vehicle speed control',
    '6': 'Engine computer or its circuits',
    '7': 'Transmission',
    '8': 'Transmission',
    '9': 'Transmission',
    'A': 'Hybrid or electric drive',
  };
  final sub = subsystems[c[2]] ?? 'Engine';
  return '$sub fault. No detailed description yet.';
}

const Map<String, String> _known = {
  'P0100': 'Mass or Volume Air Flow Circuit Malfunction',
  'P0101': 'Mass Air Flow Circuit Range/Performance',
  'P0102': 'Mass Air Flow Circuit Low Input',
  'P0103': 'Mass Air Flow Circuit High Input',
  'P0104': 'Mass Air Flow Circuit Intermittent',
  'P0105': 'Manifold Absolute Pressure Circuit Malfunction',
  'P0106': 'MAP Circuit Range/Performance',
  'P0107': 'MAP Circuit Low Input',
  'P0108': 'MAP Circuit High Input',
  'P0110': 'Intake Air Temperature Circuit Malfunction',
  'P0111': 'Intake Air Temperature Circuit Range/Performance',
  'P0112': 'Intake Air Temperature Circuit Low Input',
  'P0113': 'Intake Air Temperature Circuit High Input',
  'P0115': 'Engine Coolant Temperature Circuit Malfunction',
  'P0116': 'Engine Coolant Temperature Circuit Range/Performance',
  'P0117': 'Engine Coolant Temperature Circuit Low Input',
  'P0118': 'Engine Coolant Temperature Circuit High Input',
  'P0120': 'Throttle Position Sensor A Circuit Malfunction',
  'P0121': 'Throttle Position Sensor A Range/Performance',
  'P0122': 'Throttle Position Sensor A Circuit Low Input',
  'P0123': 'Throttle Position Sensor A Circuit High Input',
  'P0125': 'Insufficient Coolant Temperature for Closed Loop Fuel Control',
  'P0128': 'Coolant Thermostat Below Regulating Temperature',
  'P0130': 'O2 Sensor Circuit Malfunction (Bank 1, Sensor 1)',
  'P0131': 'O2 Sensor Circuit Low Voltage (Bank 1, Sensor 1)',
  'P0132': 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 1)',
  'P0133': 'O2 Sensor Circuit Slow Response (Bank 1, Sensor 1)',
  'P0134': 'O2 Sensor Circuit No Activity (Bank 1, Sensor 1)',
  'P0135': 'O2 Sensor Heater Circuit Malfunction (Bank 1, Sensor 1)',
  'P0136': 'O2 Sensor Circuit Malfunction (Bank 1, Sensor 2)',
  'P0137': 'O2 Sensor Circuit Low Voltage (Bank 1, Sensor 2)',
  'P0138': 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 2)',
  'P0139': 'O2 Sensor Circuit Slow Response (Bank 1, Sensor 2)',
  'P0140': 'O2 Sensor Circuit No Activity (Bank 1, Sensor 2)',
  'P0141': 'O2 Sensor Heater Circuit Malfunction (Bank 1, Sensor 2)',
  'P0150': 'O2 Sensor Circuit Malfunction (Bank 2, Sensor 1)',
  'P0151': 'O2 Sensor Circuit Low Voltage (Bank 2, Sensor 1)',
  'P0152': 'O2 Sensor Circuit High Voltage (Bank 2, Sensor 1)',
  'P0153': 'O2 Sensor Circuit Slow Response (Bank 2, Sensor 1)',
  'P0155': 'O2 Sensor Heater Circuit Malfunction (Bank 2, Sensor 1)',
  'P0156': 'O2 Sensor Circuit Malfunction (Bank 2, Sensor 2)',
  'P0158': 'O2 Sensor Circuit High Voltage (Bank 2, Sensor 2)',
  'P0161': 'O2 Sensor Heater Circuit Malfunction (Bank 2, Sensor 2)',
  'P0170': 'Fuel Trim Malfunction (Bank 1)',
  'P0171': 'System Too Lean (Bank 1)',
  'P0172': 'System Too Rich (Bank 1)',
  'P0173': 'Fuel Trim Malfunction (Bank 2)',
  'P0174': 'System Too Lean (Bank 2)',
  'P0175': 'System Too Rich (Bank 2)',
  'P0190': 'Fuel Rail Pressure Sensor Circuit Malfunction',
  'P0191': 'Fuel Rail Pressure Sensor Circuit Range/Performance',
  'P0192': 'Fuel Rail Pressure Sensor Circuit Low Input',
  'P0193': 'Fuel Rail Pressure Sensor Circuit High Input',
  'P0300': 'Random/Multiple Cylinder Misfire Detected',
  'P0301': 'Cylinder 1 Misfire Detected',
  'P0302': 'Cylinder 2 Misfire Detected',
  'P0303': 'Cylinder 3 Misfire Detected',
  'P0304': 'Cylinder 4 Misfire Detected',
  'P0305': 'Cylinder 5 Misfire Detected',
  'P0306': 'Cylinder 6 Misfire Detected',
  'P0307': 'Cylinder 7 Misfire Detected',
  'P0308': 'Cylinder 8 Misfire Detected',
  'P0320': 'Ignition/Distributor Engine Speed Input Circuit Malfunction',
  'P0325': 'Knock Sensor 1 Circuit Malfunction (Bank 1)',
  'P0326': 'Knock Sensor 1 Circuit Range/Performance (Bank 1)',
  'P0327': 'Knock Sensor 1 Circuit Low Input (Bank 1)',
  'P0328': 'Knock Sensor 1 Circuit High Input (Bank 1)',
  'P0330': 'Knock Sensor 2 Circuit Malfunction (Bank 2)',
  'P0335': 'Crankshaft Position Sensor A Circuit Malfunction',
  'P0336': 'Crankshaft Position Sensor A Circuit Range/Performance',
  'P0340': 'Camshaft Position Sensor A Circuit Malfunction (Bank 1)',
  'P0341': 'Camshaft Position Sensor A Circuit Range/Performance (Bank 1)',
  'P0342': 'Camshaft Position Sensor A Circuit Low Input (Bank 1)',
  'P0343': 'Camshaft Position Sensor A Circuit High Input (Bank 1)',
  'P0344': 'Camshaft Position Sensor A Circuit Intermittent (Bank 1)',
  'P0345': 'Camshaft Position Sensor A Circuit Malfunction (Bank 2)',
  'P0400': 'Exhaust Gas Recirculation Flow Malfunction',
  'P0401': 'Exhaust Gas Recirculation Flow Insufficient',
  'P0402': 'Exhaust Gas Recirculation Flow Excessive',
  'P0404': 'Exhaust Gas Recirculation Circuit Range/Performance',
  'P0405': 'Exhaust Gas Recirculation Sensor A Circuit Low',
  'P0406': 'Exhaust Gas Recirculation Sensor A Circuit High',
  'P0410': 'Secondary Air Injection System Malfunction',
  'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1)',
  'P0421': 'Warm Up Catalyst Efficiency Below Threshold (Bank 1)',
  'P0430': 'Catalyst System Efficiency Below Threshold (Bank 2)',
  'P0440': 'Evaporative Emission Control System Malfunction',
  'P0441': 'Evaporative Emission Control System Incorrect Purge Flow',
  'P0442': 'Evaporative Emission Control System Small Leak Detected',
  'P0443': 'Evaporative Emission Control System Purge Valve Malfunction',
  'P0444': 'Evaporative Emission Control System Purge Valve Open Circuit',
  'P0445': 'Evaporative Emission Control System Purge Valve Shorted',
  'P0446': 'Evaporative Emission Control System Vent Control Malfunction',
  'P0447': 'Evaporative Emission Control System Vent Control Open Circuit',
  'P0448': 'Evaporative Emission Control System Vent Control Shorted',
  'P0449':
      'Evaporative Emission Control System Vent Valve/Solenoid Malfunction',
  'P0450': 'Evaporative Emission Control System Pressure Sensor Malfunction',
  'P0451':
      'Evaporative Emission Control System Pressure Sensor Range/Performance',
  'P0452': 'Evaporative Emission Control System Pressure Sensor Low Input',
  'P0453': 'Evaporative Emission Control System Pressure Sensor High Input',
  'P0455': 'Evaporative Emission System Large Leak Detected',
  'P0456': 'Evaporative Emission System Very Small Leak Detected',
  'P0457': 'Evaporative Emission System Loose Fuel Cap',
  'P0458': 'Evaporative Emission System Purge Valve Circuit Low',
  'P0459': 'Evaporative Emission System Purge Valve Circuit High',
  'P0460': 'Fuel Level Sensor Circuit Malfunction',
  'P0461': 'Fuel Level Sensor Circuit Range/Performance',
  'P0462': 'Fuel Level Sensor Circuit Low Input',
  'P0463': 'Fuel Level Sensor Circuit High Input',
  'P0500': 'Vehicle Speed Sensor Malfunction',
  'P0501': 'Vehicle Speed Sensor Range/Performance',
  'P0502': 'Vehicle Speed Sensor Circuit Low Input',
  'P0503': 'Vehicle Speed Sensor Intermittent/Erratic/High',
  'P0505': 'Idle Control System Malfunction',
  'P0506': 'Idle Control System RPM Lower Than Expected',
  'P0507': 'Idle Control System RPM Higher Than Expected',
  'P0560': 'System Voltage Malfunction',
  'P0562': 'System Voltage Low',
  'P0563': 'System Voltage High',
  'P0600': 'Serial Communication Link Malfunction',
  'P0601': 'Internal Control Module Memory Check Sum Error',
  'P0602': 'Control Module Programming Error',
  'P0603': 'Internal Control Module Keep Alive Memory Error',
  'P0604': 'Internal Control Module Random Access Memory Error',
  'P0605': 'Internal Control Module Read Only Memory Error',
  'P0606': 'PCM Processor Fault',
  'P0700': 'Transmission Control System Malfunction',
  'P0701': 'Transmission Control System Range/Performance',
  'P0702': 'Transmission Control System Electrical Malfunction',
  'P0703': 'Torque Converter/Brake Switch B Circuit Malfunction',
  'P0705': 'Transmission Range Sensor Circuit Malfunction (PRNDL Input)',
  'P0706': 'Transmission Range Sensor Circuit Range/Performance',
  'P0710': 'Transmission Fluid Temperature Sensor Circuit Malfunction',
  'P0711': 'Transmission Fluid Temperature Sensor Range/Performance',
  'P0712': 'Transmission Fluid Temperature Sensor Circuit Low Input',
  'P0713': 'Transmission Fluid Temperature Sensor Circuit High Input',
  'P0715': 'Input/Turbine Speed Sensor Circuit Malfunction',
  'P0720': 'Output Speed Sensor Circuit Malfunction',
  'P0725': 'Engine Speed Input Circuit Malfunction',
  'P0730': 'Incorrect Gear Ratio',
  'P0731': 'Gear 1 Incorrect Ratio',
  'P0732': 'Gear 2 Incorrect Ratio',
  'P0733': 'Gear 3 Incorrect Ratio',
  'P0734': 'Gear 4 Incorrect Ratio',
  'P0735': 'Gear 5 Incorrect Ratio',
  'P0740': 'Torque Converter Clutch Circuit Malfunction',
  'P0741': 'Torque Converter Clutch Circuit Performance or Stuck Off',
  'P0742': 'Torque Converter Clutch Circuit Stuck On',
  'P0743': 'Torque Converter Clutch Circuit Electrical Malfunction',
  'P0750': 'Shift Solenoid A Malfunction',
  'P0755': 'Shift Solenoid B Malfunction',
  'P0760': 'Shift Solenoid C Malfunction',
  'P0765': 'Shift Solenoid D Malfunction',
  'P0770': 'Shift Solenoid E Malfunction',
  'P0620': 'Generator Control Circuit Malfunction',
  'P0621': 'Generator Lamp L Control Circuit Malfunction',
  'P0622': 'Generator Field F Control Circuit Malfunction',
  'P0480': 'Cooling Fan 1 Control Circuit Malfunction',
  'P0481': 'Cooling Fan 2 Control Circuit Malfunction',
  'P0482': 'Cooling Fan 3 Control Circuit Malfunction',
  'P0483': 'Cooling Fan Rationality Check Malfunction',
  'P0484': 'Cooling Fan Circuit Over Current',
  'P0485': 'Cooling Fan Power/Ground Circuit Malfunction',
  'B0001': 'Deployment Commanded (Airbag)',
  'B0002': 'Driver Frontal Stage 1 Deployment Control',
  'B0010': 'Right Curtain Deployment Control',
  'B0020': 'Left Curtain Deployment Control',
  'B0051': 'Airbag Diagnostic Monitor Internal Failure',
  'B1000': 'ECU Malfunction',
  'B1001': 'Option Configuration Error',
  'C0035': 'Left Front Wheel Speed Sensor Circuit Malfunction',
  'C0036': 'Left Front Wheel Speed Sensor Circuit Range/Performance',
  'C0040': 'Right Front Wheel Speed Sensor Circuit Malfunction',
  'C0041': 'Right Front Wheel Speed Sensor Circuit Range/Performance',
  'C0045': 'Left Rear Wheel Speed Sensor Circuit Malfunction',
  'C0046': 'Left Rear Wheel Speed Sensor Circuit Range/Performance',
  'C0050': 'Right Rear Wheel Speed Sensor Circuit Malfunction',
  'C0051': 'Right Rear Wheel Speed Sensor Circuit Range/Performance',
  'C0110': 'ABS Motor Circuit Malfunction',
  'C0121': 'ABS Valve Relay Circuit Malfunction',
  'C0161': 'ABS/TCS Brake Switch Circuit Malfunction',
  'C0265': 'EBCM Relay Circuit Active',
  'C0266': 'EBCM Relay Circuit Open/Shorted',
  'C0550': 'Electronic Control Unit Malfunction',
  'C0800': 'Device Power Circuit Low Voltage',
  'U0001': 'High Speed CAN Communication Bus Malfunction',
  'U0010': 'Medium Speed CAN Communication Bus Malfunction',
  'U0073': 'Control Module Communication Bus Off',
  'U0100': 'Lost Communication with ECM/PCM',
  'U0101': 'Lost Communication with TCM',
  'U0121': 'Lost Communication with Anti-Lock Brake System Control Module',
  'U0122': 'Lost Communication with Vehicle Dynamics Control Module',
  'U0155': 'Lost Communication with Instrument Panel Cluster Control Module',
  'U0164': 'Lost Communication with HVAC Control Module',
  'U0401': 'Invalid Data Received from ECM/PCM',

  // ── Cam timing, fuel pressure, throttle ──────────────────────────────
  'P0010': 'Camshaft Position Actuator Circuit (Bank 1)',
  'P0011': 'Camshaft Timing Over-Advanced or System Performance (Bank 1)',
  'P0012': 'Camshaft Timing Over-Retarded (Bank 1)',
  'P0013': 'Exhaust Camshaft Position Actuator Circuit (Bank 1)',
  'P0014': 'Exhaust Camshaft Timing Over-Advanced (Bank 1)',
  'P0016': 'Crankshaft/Camshaft Position Correlation (Bank 1 Sensor A)',
  'P0017': 'Crankshaft/Camshaft Position Correlation (Bank 1 Sensor B)',
  'P0018': 'Crankshaft/Camshaft Position Correlation (Bank 2 Sensor A)',
  'P0019': 'Crankshaft/Camshaft Position Correlation (Bank 2 Sensor B)',
  'P0087': 'Fuel Rail/System Pressure Too Low',
  'P0088': 'Fuel Rail/System Pressure Too High',
  'P0089': 'Fuel Pressure Regulator 1 Performance',
  'P0090': 'Fuel Pressure Regulator 1 Control Circuit',
  'P0217': 'Engine Coolant Over Temperature Condition',
  'P0218': 'Transmission Over Temperature Condition',
  'P0219': 'Engine Overspeed Condition',
  'P0221': 'Throttle/Pedal Position Sensor B Range/Performance',
  'P0222': 'Throttle/Pedal Position Sensor B Circuit Low',
  'P0223': 'Throttle/Pedal Position Sensor B Circuit High',
  'P0230': 'Fuel Pump Primary Circuit Malfunction',
  'P0231': 'Fuel Pump Secondary Circuit Low',
  'P0232': 'Fuel Pump Secondary Circuit High',
  'P0234': 'Turbo/Supercharger Overboost Condition',
  'P0236': 'Turbocharger Boost Sensor A Range/Performance',
  'P0237': 'Turbocharger Boost Sensor A Circuit Low',
  'P0238': 'Turbocharger Boost Sensor A Circuit High',
  'P0243': 'Turbo/Supercharger Wastegate Solenoid A Malfunction',
  'P0245': 'Turbo/Supercharger Wastegate Solenoid A Low',
  'P0246': 'Turbo/Supercharger Wastegate Solenoid A High',
  'P0299': 'Turbo/Supercharger Underboost Condition',
  'P0365': 'Camshaft Position Sensor B Circuit Malfunction (Bank 1)',
  'P0366': 'Camshaft Position Sensor B Circuit Range/Performance (Bank 1)',

  // ── Emissions, idle, oil pressure, electrical ────────────────────────
  'P0411': 'Secondary Air Injection System Incorrect Flow Detected',
  'P0412': 'Secondary Air Injection System Switching Valve A Circuit',
  'P0422': 'Main Catalyst Efficiency Below Threshold (Bank 1)',
  'P0423': 'Heated Catalyst Efficiency Below Threshold (Bank 1)',
  'P0424': 'Heated Catalyst Temperature Below Threshold (Bank 1)',
  'P0431': 'Warm Up Catalyst Efficiency Below Threshold (Bank 2)',
  'P0471': 'Exhaust Pressure Sensor Range/Performance',
  'P0472': 'Exhaust Pressure Sensor Low',
  'P0473': 'Exhaust Pressure Sensor High',
  'P0504': 'Brake Switch A/B Correlation',
  'P0508': 'Idle Air Control System Circuit Low',
  'P0509': 'Idle Air Control System Circuit High',
  'P0513': 'Invalid Immobilizer Key',
  'P0520': 'Engine Oil Pressure Sensor/Switch Circuit',
  'P0521': 'Engine Oil Pressure Sensor Range/Performance',
  'P0522': 'Engine Oil Pressure Sensor Low Voltage',
  'P0523': 'Engine Oil Pressure Sensor High Voltage',
  'P0524': 'Engine Oil Pressure Too Low',
  'P0571': 'Cruise Control/Brake Switch A Circuit',
  'P0627': 'Fuel Pump Control Circuit/Open',
  'P0628': 'Fuel Pump Control Circuit Low',
  'P0629': 'Fuel Pump Control Circuit High',
  'P0641': 'Sensor Reference Voltage A Circuit/Open',
  'P0685': 'ECM/PCM Power Relay Control Circuit/Open',

  // ── Transmission ─────────────────────────────────────────────────────
  'P0850': 'Park/Neutral Switch Input Circuit',
  'P0868': 'Transmission Fluid Pressure Low',
  'P0894': 'Transmission Component Slipping',
  'P0897': 'Transmission Fluid Deteriorated',

  // ── Hybrid ───────────────────────────────────────────────────────────
  'P0A80': 'Replace Hybrid Battery Pack',
  'P0AA6': 'Hybrid Battery Voltage System Isolation Fault',

  // ── P2xxx ────────────────────────────────────────────────────────────
  'P2002': 'Diesel Particulate Filter Efficiency Below Threshold (Bank 1)',
  'P2096': 'Post Catalyst Fuel Trim System Too Lean (Bank 1)',
  'P2097': 'Post Catalyst Fuel Trim System Too Rich (Bank 1)',
  'P2101': 'Throttle Actuator Control Motor Circuit Range/Performance',
  'P2106': 'Throttle Actuator Control System Forced Limited Power',
  'P2110': 'Throttle Actuator Control System Forced Limited RPM',
  'P2119': 'Throttle Actuator Control Throttle Body Range/Performance',
  'P2135': 'Throttle/Pedal Position Sensor A/B Voltage Correlation',
  'P2176': 'Throttle Actuator Control System Idle Position Not Learned',
  'P2187': 'System Too Lean at Idle (Bank 1)',
  'P2188': 'System Too Rich at Idle (Bank 1)',
  'P2195': 'O2 Sensor Signal Stuck Lean (Bank 1, Sensor 1)',
  'P2196': 'O2 Sensor Signal Stuck Rich (Bank 1, Sensor 1)',
  'P2270': 'O2 Sensor Signal Stuck Lean (Bank 1, Sensor 2)',
  'P2271': 'O2 Sensor Signal Stuck Rich (Bank 1, Sensor 2)',
  'P2279': 'Intake Air System Leak',
  'P2452': 'Diesel Particulate Filter Pressure Sensor A Circuit',
  'P2453': 'Diesel Particulate Filter Pressure Sensor A Range/Performance',
  'P2463': 'Diesel Particulate Filter Soot Accumulation',

  // ── Network ──────────────────────────────────────────────────────────
  'U0129': 'Lost Communication with Brake System Control Module',
  'U0140': 'Lost Communication with Body Control Module',
  'U0146': 'Lost Communication with Gateway A',
  'U0151': 'Lost Communication with Restraints Control Module',
};
