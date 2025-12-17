# WhatToWear (WTW)

**Smart AI‑Powered Wardrobe & Outfit Recommendation App**

WhatToWear is a cross‑platform Flutter application that helps users organize their wardrobe and receive intelligent outfit recommendations based on weather conditions and personal preferences. The project was developed as a **Capstone Mobile App Project** and is ready for academic submission and demonstration.

---

## 📱 Project Overview

Choosing what to wear every day can be time‑consuming and stressful. People often forget what they already own, struggle to match clothes with the weather, and underutilize their wardrobe.

**WhatToWear** solves this problem by combining:

* Personal wardrobe management
* AI‑powered outfit suggestions
* Real‑time weather integration
* Secure cloud storage and offline support

The app is designed to be **user‑friendly, scalable, and production‑ready**.

---

## 🎯 Project Goals

* Apply Flutter for cross‑platform mobile development (Android & iOS)
* Build a clean, responsive, and intuitive UI
* Integrate backend services (Firebase, APIs)
* Use proper state management with Provider
* Ensure security, performance, and offline access
* Deliver complete technical documentation and a working product

---

## ✨ Key Features

### 👕 Wardrobe Management

* Add, edit, view, and delete clothing items
* Upload and store clothing images
* Categorize items (shirts, pants, shoes, accessories, etc.)
* Tag items by color, size, brand, and style
* Search and filter wardrobe items

### 🤖 AI Outfit Recommendations

* AI‑generated outfit suggestions using OpenAI API
* Context‑aware recommendations based on weather
* Smart caching to reduce API calls and cost
* Multi‑language support

### ☀️ Weather Integration

* Real‑time weather data based on user location
* Temperature and condition‑based outfit filtering
* Automatic weather refresh

### 🔐 Authentication & Security

* Firebase Email/Password authentication
* Secure user sessions
* User‑specific data isolation
* Secure API key storage

### 💾 Offline Support

* Local caching using Hive
* Access wardrobe data without internet
* Sync with cloud when connection is restored

### 🌙 UI & Accessibility

* Dark mode support
* Responsive design for different screen sizes
* Material Design 3 guidelines

---

## 🛠️ Technology Stack

### Frontend

* **Flutter** (Dart)
* **Provider** for state management
* **Material Design 3**

### Backend & Cloud

* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Storage**

### External APIs

* **OpenAI API** – outfit recommendations
* **Weather API** – real‑time weather data
* **Geolocation** – location‑based services

### Local Storage

* **Hive** – offline cache
* **Flutter Secure Storage** – sensitive data

---

## 🏗️ Architecture

The app follows a **clean MVC‑based architecture with Provider**:

* **UI Layer** – Screens and widgets
* **State Management Layer** – Provider (ChangeNotifier)
* **Service Layer** – Business logic and API integrations
* **Data Layer** – Models, Firebase, and local storage

This structure ensures scalability, testability, and maintainability.

---

## 📂 Project Structure

```
lib/
├── models/        # Data models
├── screens/       # UI screens
├── services/      # Business logic & APIs
├── widgets/       # Reusable UI components
├── utils/         # Helper functions
└── main.dart      # App entry point
```

---

## 🚀 Installation & Setup

### Prerequisites

* Flutter SDK 3.9.2+
* Dart SDK
* Android Studio / Xcode / VS Code
* Firebase project
* OpenAI API key

### Steps

```bash
# Clone repository
git clone <repository-url>
cd wtw

# Install dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build

# Run the app
flutter run
```

---

## 🗄️ Database Design

### Firestore Collections

```
users/{userId}/
 ├── wardrobe_items/{itemId}
 └── saved_outfits/{outfitId}
```

Each user has isolated data protected by Firebase security rules.

### Local Storage (Hive)

* `wardrobeBox` – cached wardrobe items
* `savedOutfits` – offline outfits
* `settings` – user preferences

---

## 🧪 Testing

* Unit tests for core logic
* Manual testing for UI, APIs, and authentication
* Tested scenarios:

  * Authentication flow
  * CRUD operations
  * Image upload
  * Weather & AI integration
  * Offline mode

---

## 🔐 Security

* Firebase Authentication with session persistence
* Secure API key storage
* Firestore rules enforcing user isolation
* No cross‑user data access

---

## 📊 Evaluation Mapping (Capstone)

| Criterion                    | Status |
| ---------------------------- | ------ |
| Problem Definition           | ✅      |
| System Design & Architecture | ✅      |
| Functionality & Features     | ✅      |
| UI/UX Design                 | ✅      |
| Innovation & Complexity      | ✅      |
| Testing & Debugging          | ✅      |
| Documentation & Presentation | ✅      |


---

## 📦 Deliverables

* Fully functional Flutter application
* Clean and well‑structured source code
* Technical documentation (this README)
* App demo and presentation slides
* Git repository with commit history

---

## 📄 License

This project is developed for **educational purposes only** as part of a capstone project.

---

## ✅ Project Status

**Version:** 1.0
**Status:** Ready for Submission 🚀
**Last Updated:** December 2025

