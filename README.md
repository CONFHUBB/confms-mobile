# ConfMS Mobile

A Flutter mobile application for Conference Management System.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9.2 or higher)
- For Android: Android Studio with Android SDK
- For iOS: Xcode and CocoaPods (macOS only)

## Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd confms_mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. For iOS (macOS only):
```bash
cd ios && pod install && cd ..
```

4. Verify setup:
```bash
flutter doctor
```

## Running the App

```bash
# Run on any connected device
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

## Building

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Project Structure

```
lib/
├── main.dart           # Entry point
├── app.dart            # App configuration
├── core/               # Constants, routes, theme
├── models/             # Data models
├── screens/            # UI screens
├── services/           # API services
└── widgets/            # Reusable widgets
```

## Development

```bash
# Run tests
flutter test

# Format code
dart format .

# Analyze code
flutter analyze
```
