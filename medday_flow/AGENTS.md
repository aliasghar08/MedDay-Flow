# Antigravity Agent Constitution — MedDay Flow

## Environment & Commands
- **Project Root**: `medday_flow/` (`daily_planner/` symlinked)
- **Framework**: Flutter (Dart ^3.7.2)
- **Primary Platforms**: iOS (HealthKit, Biometrics), Android (AlarmManager, Exact Alarms)

## Emulator & Simulator Workflows
1. **Discover Devices**:
   - `flutter devices` (lists running targets)
   - `flutter emulators` (lists all configured virtual devices)
   - `xcrun simctl list devices | grep -E "iPhone|iPad"`

2. **Booting Simulators**:
   - 6.7"/6.9" iPhone Display: `xcrun simctl boot "iPhone 18 Pro Max"` (or launch Simulator.app)
   - 13" iPad Display: `xcrun simctl boot "iPad Pro 13-inch (M5)"`

3. **Running the App**:
   - `flutter run -d <device_id>`
   - Use Agentic Hot Reload: send `r` to stdin on code updates, `R` on state changes.

4. **App Store Screenshot Automation**:
   - When generating App Store assets, take native uncompressed simulator captures:
     `xcrun simctl io booted screenshot ~/Desktop/screenshots/<screen_name>.png`
   - Ensure the resolution strictly matches Apple's required dimensions:
     - 6.7" iPhone: 1290 × 2796 px (or 6.9" 1320 × 2868 px)
     - 13" iPad: 2048 × 2732 px

## Safeguards & Rules
- Do not modify `ios/Runner.xcodeproj` or `Podfile` unless addressing specific build errors.
- Never force unwrap platform channel arguments in `AppDelegate.swift`.
- Keep biometrics and passkeys `false` / opt-in by default.
