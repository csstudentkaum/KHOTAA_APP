# KHOTAA APP

A Flutter mobile application for diabetic foot health monitoring with Firebase backend.

## Project Status

**SETUP COMPLETE** - Ready for development

This project is fully configured with Flutter and Firebase. The directory structure and all placeholder screens are in place. Development team can now begin implementation.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Project Structure](#project-structure)
- [Firebase Configuration](#firebase-configuration)
- [Running the App](#running-the-app)
- [Development Guidelines](#development-guidelines)

---

## Project Overview

KHOTAA APP is a healthcare mobile application designed for:
- **Patients**: Monitor diabetic foot health using smart insole sensors
- **Doctors**: Review patient data and provide consultations

### Key Features (To Be Implemented)
- Real-time sensor data from smart insoles
- AI-powered foot health analysis
- Medical image upload and AI analysis
- Doctor-patient consultations
- Appointment scheduling and payments

---

## Tech Stack

- **Framework**: Flutter 3.35.3 (Dart 3.9.2)
- **Backend**: Firebase
  - Firebase Core
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
- **Platforms**: Android & iOS

---

## Prerequisites

Before cloning this project, ensure you have:

### Required Tools
- Flutter SDK (3.19+)
- Dart SDK (3.x - bundled with Flutter)
- Git
- Android Studio (for Android development)
- Xcode (for iOS development - macOS only)
- VS Code or Android Studio

### Verify Installation
```bash
flutter doctor
```

All critical checks should pass

---

## Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/csstudentkaum/KHOTAA_APP.git
cd KHOTAA_APP
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Verify Firebase Configuration
The following files should already exist:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`
- `.firebaserc`

### 4. Build and Run

#### For Android:
```bash
flutter run
```

#### For iOS:
```bash
flutter run -d "iPhone 15 Pro"
```

Or open iOS Simulator first:
```bash
open -a Simulator
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point with Firebase initialization
├── firebase_options.dart        # Firebase configuration (auto-generated)
│
├── app/
│   ├── app_theme.dart          # App-wide theme configuration
│   └── routes.dart             # Route definitions
│
├── features/
│   ├── auth/                   # Authentication feature
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   │
│   ├── patient/                # Patient-specific features
│   │   ├── patient_shell.dart           # Bottom tabs holder
│   │   ├── connect_insole_screen.dart   # Connect smart insole
│   │   ├── home_screen.dart             # Patient home
│   │   ├── dashboard_screen.dart        # Health dashboard
│   │   ├── ai_doctor_screen.dart        # AI doctor consultation
│   │   ├── image_upload_screen.dart     # Upload medical images
│   │   ├── image_analysis_screen.dart   # View AI analysis
│   │   ├── doctors_list_screen.dart     # Browse doctors
│   │   ├── appointment_screen.dart      # Book appointments
│   │   ├── payment_screen.dart          # Payment processing
│   │   ├── payment_success_screen.dart  # Payment confirmation
│   │   ├── chat_screen.dart             # Chat with doctor
│   │   └── profile_screen.dart          # Patient profile
│   │
│   └── doctor/                 # Doctor-specific features
│       ├── doctor_shell.dart            # Bottom tabs holder
│       ├── dashboard_screen.dart        # Doctor dashboard
│       ├── patient_list_screen.dart     # List of patients
│       ├── patient_details_screen.dart  # Patient health details
│       └── chat_screen.dart             # Chat with patient
│
├── models/                     # Data models (to be implemented)
├── services/
│   └── firebase/              # Firebase service layer (to be implemented)
├── state/                     # State management (to be implemented)
└── shared/
    └── widgets/               # Reusable widgets (to be implemented)
```

---

## Firebase Configuration

### Firebase Project Details
- **Project ID**: `khotaa-app`
- **Project Name**: KHOTAA APP
- **Region**: asia-south1 (Mumbai)

### Registered Apps
- **Android**: `com.khotaa.app`
  - App ID: `1:702053481596:android:244de0dcb6300ebce9ddf9`
  
- **iOS**: `com.khotaa.app`
  - App ID: `1:702053481596:ios:4240804f63920034e9ddf9`

### Firebase Services Configured
- Cloud Firestore
- Firebase Storage
- Firebase Authentication (ready to use)

### Firebase Console
Access your Firebase project: [https://console.firebase.google.com/project/khotaa-app/overview](https://console.firebase.google.com/project/khotaa-app/overview)

---

## Running the App

### Check Available Devices
```bash
flutter devices
```

### Run on Specific Device
```bash
flutter run -d <device-id>
```

### Run in Debug Mode (Default)
```bash
flutter run
```

### Run in Release Mode
```bash
flutter run --release
```

### Build APK (Android)
```bash
flutter build apk
```

### Build iOS App
```bash
flutter build ios
```

---

## Development Guidelines

### DO NOT
- Commit secrets or API keys
- Modify Firebase configuration files manually
- Remove placeholder TODO comments before implementation

### DO
- Follow Flutter best practices
- Use proper state management (to be decided by team)
- Write tests for new features
- Keep Firebase rules secure
- Use environment variables for sensitive data

### Code Style
- Follow Dart style guide
- Use `flutter analyze` before committing
- Run `flutter format .` to format code

---

## Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/unit/example_test.dart
```

Test directories are organized as:
- `test/unit/` - Unit tests
- `test/widget/` - Widget tests
- `test/integration/` - Integration tests

---

## Next Steps for Development Team

1. **Implement State Management**
   - Choose: Provider, Riverpod, Bloc, or GetX
   - Set up in `lib/state/`

2. **Create Data Models**
   - Define Firestore document structures in `lib/models/`
   - Add JSON serialization

3. **Implement Firebase Services**
   - Auth service in `lib/services/firebase/`
   - Firestore CRUD operations
   - Storage upload/download

4. **Set Up Routing**
   - Configure navigation in `lib/app/routes.dart`
   - Use GoRouter or Auto_Route (recommended)

5. **Design UI/UX**
   - Implement `lib/app/app_theme.dart`
   - Create reusable widgets in `lib/shared/widgets/`

6. **Implement Authentication Flow**
   - Complete screens in `lib/features/auth/`
   - Set up Firebase Authentication

7. **Build Patient Features**
   - Implement all patient screens
   - Connect to Firebase services

8. **Build Doctor Features**
   - Implement all doctor screens
   - Set up real-time data sync

---

## Environment Variables

**Note**: Firebase configuration is already handled through the committed configuration files (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`). No environment variables are needed for Firebase.

If you need environment-specific configuration for other services (API keys, etc.), create a `.env` file:

```env
# Example: Third-party API keys (if needed)
# API_KEY=your_api_key_here
# APP_NAME=KHOTAA APP
```

**Important**: The `.env` file is gitignored. Never commit secrets or API keys!

---

## Contributing

1. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and commit
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

3. Push to remote
   ```bash
   git push origin feature/your-feature-name
   ```

4. Create a Pull Request

---

## License

[Add your license here]

---

## Team

[Add team members here]

---

## Support

For issues and questions:
- Create an issue in the repository
- Contact the development team

---

## Project Setup Completed By

Flutter & Firebase Setup Agent
Date: February 6, 2026

**Status**: Ready for Development

All configurations are complete. The project builds successfully on Android and iOS with Firebase initialized.

**Happy Coding!**
