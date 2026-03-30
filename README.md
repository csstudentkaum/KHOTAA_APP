# KHOTAA: Smart Diabetic Foot Shield

## Project Information

| | |
|---|---|
| **Course** | CPCS-499 – Senior Project |
| **Project Title** | KHOTAA: Smart Diabetic Foot Shield |
| **Institution** | King Abdulaziz University |

### Team Members

| # | Student Name | Student ID |
|---|-------------|-----------|
| 1 | Manar Abdullah Alharbi | 2206712 |
| 2 | Reema Mohammed Alghamdi | 2205046 |
| 3 | Sara Saleh Alsalmi | 2006010 |

## Overview

KHOTAA is a cross-platform mobile application developed as part of the CPCS-499 Senior Project. The application addresses the clinical need for early detection and continuous monitoring of Diabetic Foot Ulcer (DFU) complications by integrating smart insole sensor technology, artificial intelligence, and telemedicine into a unified mobile platform.

The system serves two user roles:
- **Patients** — monitor foot health through real-time pressure and temperature readings, upload foot images for AI analysis, and book consultations with healthcare providers.
- **Doctors** — review patient sensor data remotely, assess AI classification results, manage treatment plans, and communicate with patients through chat-based consultations.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend | Firebase (Authentication, Cloud Firestore, Realtime Database, Cloud Storage, Cloud Messaging) |
| Video/Voice | Agora SDK (real-time communication for consultations) |
| Target Platforms | Android, iOS |

## Functional Overview

- **Real-time sensor monitoring** — Continuous streaming of foot pressure and temperature data from the smart insole device to the application via Firebase Realtime Database.
- **AI-powered image classification** — A trained deep learning model classifies uploaded foot images into four categories: *ischemia*, *infection*, *both*, or *none*.
- **Consultation and booking system** — Patients can browse available doctors and book consultation sessions based on the doctor's predefined working hours.
- **Treatment plan management** — Doctors can create, update, and monitor patient treatment plans.
- **Health alerts and notifications** — Automated alerts are triggered when sensor readings exceed predefined thresholds, delivered via push notifications.
- **Preventive recommendations** — AI-generated preventive care suggestions based on sensor data analysis.

## Setup and Installation

### Prerequisites
- Flutter SDK 3.19 or later
- Android Studio (Android) or Xcode (iOS)
- Configured Firebase project

### Instructions
```bash
git clone https://github.com/csstudentkaum/KHOTAA_APP.git
cd KHOTAA_APP
flutter pub get
flutter run
```

To run on a specific device:
```bash
flutter devices
flutter run -d <device-id>
```

## Source Code Structure

```
lib/
├── main.dart                # Application entry point
├── firebase_options.dart    # Firebase configuration
├── app/                     # Theme and routing definitions
├── features/
│   ├── auth/                # Authentication (splash, login, registration)
│   ├── patient/             # Patient-facing screens and logic
│   └── doctor/              # Doctor-facing screens and logic
├── models/                  # Data models
├── services/                # Firebase and business logic services
├── state/                   # State management
└── shared/                  # Reusable UI components
```

## Firebase Architecture

| Service | Role |
|---------|------|
| **Cloud Firestore** | Primary NoSQL database storing users, consultations, alerts, notifications, devices, sensor readings, image analysis results, medical images, treatment plans, and preventive recommendations |
| **Realtime Database** | Low-latency streaming of live insole sensor data under `readings/{patientId}` |
| **Authentication** | Phone-based sign-in for patients; email/password sign-in for doctors |
| **Cloud Storage** | Storage of uploaded medical foot images |
| **Cloud Messaging (FCM)** | Delivery of push notifications for health alerts and booking updates |

**Firebase Project ID:** `khotaa-app`

## Development

Active development branch: `almost_integration`
