# CYN - Chase Your Needs

CYN (Chase Your Needs) is a Flutter-based mobile application designed to connect customers with skilled workers and local service providers.

## Overview

The platform supports two primary user roles:
- **Customer**: Browse service categories, find nearby skilled workers, send job requests, track real-time worker status, and communicate via in-app chat and voice calls.
- **Worker**: Manage availability, receive and respond to incoming service requests, navigate to customer locations, and track completed jobs and ratings.

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Backend & Database**: Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Cloud Messaging, SQLite (local storage)
- **Maps & Location**: Flutter Map, Geolocator
- **Real-Time Communication**: Agora RTC Engine

## Getting Started

### Prerequisites

- Flutter SDK (`>=3.0.0 <4.0.0`)
- Configured Firebase project (`firebase_options.dart` / platform configurations)

### Installation

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```
