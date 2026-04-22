# Healing Hands Response Force

A Flutter + Firebase mobile application for elder emergency response, assistance coordination, medication reminders, and nearby resource discovery.

This repository contains the `responseforce` app plus supplementary project artifacts such as schema diagrams, wireframes, and a project document. The app is structured around two user roles:

- **Elder**: requests help, manages profile information, tracks medication, and discovers nearby services.
- **Admin**: monitors incidents, updates case status, and reviews operational analytics.

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [Technology Stack](#technology-stack)
- [Application Architecture](#application-architecture)
- [Repository Structure](#repository-structure)
- [Key Data Collections](#key-data-collections)
- [Primary User Flows](#primary-user-flows)
- [Setup and Installation](#setup-and-installation)
- [Firebase and Platform Configuration](#firebase-and-platform-configuration)
- [Run the App](#run-the-app)
- [Testing](#testing)
- [Known Gaps and Implementation Notes](#known-gaps-and-implementation-notes)
- [Suggested Next Improvements](#suggested-next-improvements)

---

## Overview

**Healing Hands Response Force** is a role-based care-support application designed to help elderly users quickly request assistance and help administrators monitor and resolve incidents.

The codebase currently supports:

- Elder authentication and onboarding
- Admin-restricted access using a whitelist check
- SOS alert creation with location capture or manual map selection
- Nearby hospital, pharmacy, and police discovery
- Assistance requests for medicine, grocery, and general support
- Medication routines, reminders, and dose tracking
- In-app notification logs and status history
- Admin analytics for SOS activity and repeat-risk users

---

## Core Capabilities

### Elder-facing features

#### 1. Authentication and onboarding
- Role selection for **Elder** or **Admin**
- Elder registration flow
- Login and forgot-password flow
- First-run setup screen requesting location access
- Profile management with medical and emergency-contact details

#### 2. SOS emergency workflow
- Large one-tap SOS entry point from the home screen
- Attempts to attach a current GPS location snapshot
- Falls back to last known location when available
- Allows manual location selection through a map picker
- Creates a Firestore SOS record and a corresponding status-history entry
- Shows a request status screen after submission

#### 3. Assistance requests
- Dedicated flows for:
  - Medicine help
  - Grocery help
  - General assistance
- Stores urgency, summary, details, and preferred time
- Tracks request lifecycle through status changes

#### 4. Nearby services discovery
- Searches nearby:
  - Hospitals
  - Pharmacies
  - Police stations
- Uses map-based interaction and current-location capture
- Displays results on an OpenStreetMap view
- Supports phone calling and external Google Maps directions

#### 5. Medication reminders
- Create, update, and delete medication routines
- Maintain multiple reminder times per medicine
- Schedule local notifications
- Persist remote reminder metadata for FCM-oriented delivery
- Track doses as **taken** or **missed**
- Auto-mark overdue doses as missed when appropriate
- Present routines and “Today’s Doses” in separate tabs

#### 6. Notifications and status visibility
- User-visible notification log backed by Firestore
- Status history for SOS and assistance requests
- Dedicated request status screen for live state updates

### Admin-facing features

#### 1. Secure admin entry
- Admin sign-in is gated by an `admin_whitelist` check
- Non-whitelisted accounts are blocked from admin access

#### 2. Control center dashboard
- Separate tabs for:
  - SOS Alerts
  - Assistance
  - Analytics
- Status-based filtering for pending, in-progress, and resolved items
- Case lists ordered by most recent activity

#### 3. Analytics
- SOS counts for current week and month
- Pending, in-progress, and resolved totals
- Average response time estimation
- Repeat emergency user count
- High-risk user insights over recent activity windows

---

## Technology Stack

### Frontend
- **Flutter**
- **Dart**
- **Provider** for dependency injection and app state

### Backend and services
- **Firebase Authentication** for sign-in and registration
- **Cloud Firestore** as the operational datastore
- **Firebase Cloud Messaging (FCM)** for remote reminder-oriented integration points

### Device and platform features
- **Geolocator** for location permissions and coordinate capture
- **flutter_map** + **latlong2** for map rendering and map-based selection
- **flutter_local_notifications** + **timezone** for local reminders
- **url_launcher** for calls and map handoff
- **shared_preferences** for local role/setup persistence

### External APIs
- **Overpass API** for nearby hospital, pharmacy, and police discovery
- **OpenStreetMap tiles** through `flutter_map`

---

## Application Architecture

The app follows a pragmatic Flutter architecture centered on a service layer and Provider-based dependency wiring.

### Startup flow
- `main.dart` initializes Firebase
- Configures foreground/background messaging hooks
- Initializes:
  - `LocalReminderService`
  - `RemoteReminderService`
  - `InAppReminderWatcherService`
- Registers core services through `MultiProvider`

### Routing and bootstrap logic
- `app.dart` decides the first screen based on:
  - selected role in local state
  - authentication state
  - Firestore-stored role
  - whether elder setup is complete

### State management
- `AppState` persists:
  - selected role
  - elder setup completion flag

### Service layer responsibilities
- `AuthService`
  - authentication
  - elder registration
  - role lookup
  - admin whitelist enforcement
- `FirestoreService`
  - elder profile CRUD
  - SOS and assistance records
  - status history
  - notification logs
  - medication routines/logs
  - analytics
- `NearbyResourcesService`
  - Overpass API queries with short-term caching
- `LocalReminderService`
  - on-device notification scheduling
- `RemoteReminderService`
  - device token persistence and remote reminder record creation
- `InAppReminderWatcherService`
  - periodic scan for due reminders and in-app notification log creation

---

## Repository Structure

```text
App-Project-489/
├── responseforce/
│   ├── android/
│   ├── ios/
│   ├── linux/
│   ├── macos/
│   ├── web/
│   ├── windows/
│   ├── lib/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── state/
│   │   ├── theme/
│   │   ├── utils/
│   │   ├── widgets/
│   │   ├── app.dart
│   │   └── main.dart
│   ├── test/
│   ├── pubspec.yaml
│   └── README.md
├── CSE489_22201074_Sougata Chowdhury_Responseforce.doc
├── Schema Diagram.jpg
├── Wireframe diagram.png
├── healing_hands_complete_wireframe.pdf
└── healing_hands_schema_diagram.pdf
```

### Notable app folders

#### `lib/screens/`
Contains the UI flows, including:
- role selection
- login/registration
- elder home
- SOS confirmation
- request status
- nearby resources
- medication reminders
- admin dashboard
- admin analytics
- profile and notifications

#### `lib/services/`
Contains business and integration logic:
- auth
- Firestore access
- nearby-resource lookup
- local reminders
- remote reminders
- in-app reminder watcher

#### `lib/state/`
Contains application-wide UI/session state.

#### `test/`
Contains Flutter widget tests.

---

## Key Data Collections

The Firestore service indicates the app relies on the following primary collections.

| Collection | Purpose |
|---|---|
| `users` | Auth-linked user role and account metadata |
| `elder_profiles` | Elder demographic, medical, and emergency-contact details |
| `admin_whitelist` | Admin email authorization gate |
| `assistance_requests` | Non-emergency help requests |
| `sos_alerts` | Emergency SOS incidents |
| `status_history` | Change log for SOS and assistance records |
| `notification_logs` | In-app user-facing notifications |
| `medication_routines` | Saved medication schedules |
| `medication_logs` | Dose outcomes such as taken or missed |
| `users/{uid}/remote_medication_reminders` | Remote reminder schedule metadata |
| `users/{uid}/device_tokens` | Device token records for push/reminder workflows |

---

## Primary User Flows

### Elder flow
1. Choose **Continue as Elder**.
2. Log in or create a new elder account.
3. Complete permission/setup prompts.
4. Maintain profile details and emergency contacts.
5. Use the home screen to:
   - send an SOS
   - request medicine help
   - request grocery help
   - request general assistance
   - find nearby services
   - manage medication reminders
6. Track outcomes through notifications and request status screens.

### Admin flow
1. Choose **Continue as Admin**.
2. Log in with a whitelisted admin email.
3. Open the **Admin Control Center**.
4. Review and update:
   - SOS cases
   - assistance cases
5. Use analytics to identify activity trends and repeat-risk users.

---

## Setup and Installation

### Prerequisites
- Flutter SDK compatible with the project’s Dart constraint (`sdk: ^3.11.4`)
- Android Studio and/or Xcode for device builds
- A Firebase project with:
  - Authentication
  - Cloud Firestore
  - Cloud Messaging
- Location and notification permissions configured per platform

### Clone the repository

```bash
git clone https://github.com/Sougata-Chowdhury/App-Project-489.git
cd App-Project-489/responseforce
```

### Install dependencies

```bash
flutter pub get
```

---

## Firebase and Platform Configuration

This codebase depends on Firebase but does not include a fully documented deployment configuration in the repository. Before running the app in a fresh environment, configure the following:

### 1. Firebase Authentication
Enable the sign-in methods used by the app.

### 2. Cloud Firestore
Create the required collections and review your Firestore rules/indexes based on the query patterns in `FirestoreService`.

### 3. Firebase Cloud Messaging
Configure FCM if you intend to use the remote reminder path.

### 4. Android
Provide your Android Firebase setup, typically including:
- package name alignment
- `google-services.json`
- Gradle integration for Firebase
- runtime permissions for location and notifications

### 5. iOS
Provide your iOS Firebase setup, typically including:
- bundle identifier alignment
- `GoogleService-Info.plist`
- notification capability setup
- location permission strings in Info.plist

### 6. Web
The current app intentionally routes web builds to a notice screen because Firebase web options are not configured in `main.dart`. Complete web Firebase configuration before treating web as a supported target.

---

## Run the App

### Development run

```bash
flutter run
```

### Run on a specific device

```bash
flutter devices
flutter run -d <device-id>
```

---

## Testing

Run the existing widget tests with:

```bash
flutter test
```

At the time of review, the test suite is minimal and primarily covers a basic role-selection smoke test. Additional tests should be added for:

- authentication flows
- Firestore-backed services
- reminder scheduling logic
- SOS and assistance state transitions
- admin analytics calculations

---

## Known Gaps and Implementation Notes

### 1. Web support is incomplete
The web build currently shows a dedicated Firebase notice screen rather than the full app flow.

### 2. Existing README is still boilerplate
The current `responseforce/README.md` in the repository is the default Flutter starter README and should be replaced with project-specific documentation.

### 3. Test coverage is limited
Only a small widget smoke test is present.

### 4. Large UI files would benefit from modularization
Some screens, especially the medication reminder flow, are large and combine UI and workflow logic in a single file. Splitting screens into smaller widgets and controllers/services would improve maintainability.

### 5. Remote reminder delivery path may need backend completion
The app stores remote reminder metadata and device tokens, but production-grade delivery usually also requires a backend scheduler or Cloud Function to dispatch FCM messages at the right time.

---

## Suggested Next Improvements

1. Replace the in-repo README with this project documentation.
2. Add Firebase setup instructions and environment-specific configuration notes.
3. Introduce Firestore rules and index documentation.
4. Add integration and service-level automated tests.
5. Refactor large screens into smaller feature modules.
6. Add CI for formatting, analysis, and tests.
7. Complete web Firebase support or explicitly scope the app to mobile only.
8. Add screenshots or GIFs for the elder and admin flows.

---

## Recommended README Placement

For this repository, the most useful location for this documentation is:

- `responseforce/README.md`

That is the actual Flutter app root and the place where developers will look first when setting up or modifying the application.

---

## Summary

Healing Hands Response Force is a well-scoped Flutter/Firebase elder-care support app with solid feature coverage across emergency response, assistance requests, medication tracking, and admin case management. The project already contains the core app structure and feature implementation needed for a strong academic or prototype portfolio project; the biggest remaining gains are in deployment documentation, testing depth, and modular refactoring.
