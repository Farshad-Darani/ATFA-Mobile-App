# ATFA - Intelligent Automobile Diagnostic System

ATFA (Intelligent Automobile Diagnostic System) is a comprehensive Flutter mobile application designed to help vehicle owners monitor their car's health and performance in real-time through OBD-II Bluetooth connectivity.

## Features

### 🔗 Connect Page
- **Bluetooth Discovery**: Automatically scans for available OBD-II devices
- **Permission Management**: Handles Bluetooth and location permissions seamlessly
- **Device Connection**: Simple tap-to-connect interface with connection status indicators
- **Cross-Platform Support**: Works on both Android and iOS devices

### 📊 Live Data Page
- **Real-Time Monitoring**: Displays live vehicle data with 1-second updates
- **Interactive Gauges**: Beautiful circular gauges for RPM and Speed
- **Data Cards**: Clean cards showing:
  - Engine Coolant Temperature
  - Throttle Position
  - Battery Voltage
  - Engine Load
  - Fuel Level
  - Diagnostic Error Codes
- **Error Code Analysis**: Detailed error code descriptions and explanations
- **Simulated Data**: Works with simulated data when no device is connected

### ℹ️ More/About Page
- **Company Information**: Details about ATFA and its mission
- **How It Works**: Step-by-step explanation of the diagnostic process
- **Contact & Support**: Direct links to website, email, and phone support
- **Legal Information**: Privacy policy, terms of service, and open source licenses

## Technology Stack

- **Framework**: Flutter 3.x with Dart
- **Bluetooth**: `flutter_blue_plus` for BLE connectivity
- **Permissions**: `permission_handler` for Android/iOS permissions
- **UI/UX**: Material 3 design with custom color scheme
- **Architecture**: Modular structure with separate services and widgets

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── config/
│   └── app_theme.dart          # App theme and color configuration
├── screens/
│   ├── main_navigation.dart    # Bottom navigation controller
│   ├── connect_page.dart       # Bluetooth connection interface
│   ├── live_data_page.dart     # Real-time data dashboard
│   └── more_page.dart          # About and information page
├── services/
│   └── bluetooth_service.dart  # Bluetooth connection and data management
└── widgets/
    ├── device_tile.dart        # Bluetooth device list item
    ├── data_card.dart          # Data display card component
    ├── gauge_widget.dart       # Circular gauge component
    └── permission_dialog.dart  # Permission request dialog
```

## Getting Started

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart 3.0 or higher
- Android Studio / Xcode for device testing
- OBD-II Bluetooth adapter (ELM327 or compatible) for real testing

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd atfa
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### Building for Release

**Android APK**
```bash
flutter build apk --release
```

**iOS IPA**
```bash
flutter build ios --release
```

## OBD-II Integration

### Supported Commands

The app is designed to work with standard OBD-II PIDs (Parameter IDs):

- **01 0C**: Engine RPM
- **01 0D**: Vehicle Speed
- **01 05**: Engine Coolant Temperature
- **01 11**: Throttle Position
- **01 42**: Control Module Voltage
- **01 04**: Calculated Engine Load
- **03**: Request Diagnostic Trouble Codes

### Compatible Devices

- ELM327 Bluetooth OBD-II adapters
- OBDLink MX+ 
- BlueDriver
- Most Bluetooth Low Energy OBD-II dongles

## Permissions

### Android
- `BLUETOOTH` - Basic Bluetooth functionality
- `BLUETOOTH_ADMIN` - Bluetooth device management
- `BLUETOOTH_SCAN` - Android 12+ BLE scanning
- `BLUETOOTH_CONNECT` - Android 12+ device connection
- `ACCESS_FINE_LOCATION` - Required for BLE device discovery
- `INTERNET` - For future cloud features

### iOS
- `NSBluetoothAlwaysUsageDescription` - Bluetooth access
- `NSLocationWhenInUseUsageDescription` - Location for BLE scanning

## Development

### Code Style
- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Comment complex logic and algorithms
- Maintain modular architecture

### Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Debugging
```bash
# Run in debug mode
flutter run --debug

# Run with hot reload
flutter run --hot
```

## Roadmap

- [ ] **Real OBD-II Integration**: Connect to actual vehicle diagnostics
- [ ] **Data Logging**: Save diagnostic sessions for analysis
- [ ] **Trip Tracking**: Monitor fuel efficiency and driving patterns
- [ ] **Cloud Sync**: Backup data across devices
- [ ] **Advanced Diagnostics**: More comprehensive error analysis
- [ ] **Vehicle Profiles**: Support for multiple vehicles
- [ ] **Performance Metrics**: Acceleration, braking, and efficiency scoring

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For questions or support, please open an issue on GitHub or contact:
- **Email**: d1.farshad@gmail.com
- **Email**: support@atfagildar.ca
- **Website**: [www.atfagildar.ca](https://www.atfagildar.ca)

## License

This project is licensed under a Proprietary License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- OBD-II community for diagnostic standards
- Open source contributors for essential packages

---

**ATFA** - Making vehicle diagnostics accessible to everyone. 🚗💙
