# 🏥 SwasthyaTap — Smart NFC Emergency Health Identity

[![Flutter](https://img.shields.io/badge/Flutter-v3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-v18+-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-v4+-000000?style=for-the-badge&logo=express&logoColor=white)](https://expressjs.com)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://mongodb.com)

**SwasthyaTap** is a modern, NFC-enabled emergency health card platform that bridges the gap between first responders and critical patient medical records during emergency situations. By scanning the card, emergency staff can immediately pull medical history, blood group, allergies, and contact details without needing credentials, while sending instant notifications to designated emergency contacts.

---

## 🌟 Key Features

### 👤 Citizen Portal
* **Interactive Health Dashboard:** Renovated profile view with validate-on-submit form fields and custom dropdown configurations for blood groups.
* **Email OTP Authentication:** Built-in secure verification with standard email OTP, backed by automatic test email generation using Ethereal SMTP.
* **3D Card Viewer:** Real-time 3D interactive representation of the digital SwasthyaTap physical card.
* **Organ Pledge Registration:** Seamless integration with National Organ & Tissue Transplant Organisation (NOTTO) workflows.

### 🏥 Hospital Portal
* **Verified Credentials:** Dual authentication for hospitals and personnel before checking scanning logs.
* **Active Blood Emergencies:** Ability to declare emergency blood requests and notify nearby volunteer donors.
* **Live Emergency Donor Map:** Visual tracking of nearby blood donors responding in real-time.

---

## 🛠️ Tech Stack

* **Frontend:** Flutter (Web & Mobile), Provider (State Management), CanvasKit rendering engine.
* **Backend:** Node.js, Express, MongoDB Atlas, Mongoose ODM.
* **Email System:** Nodemailer (SMTP with auto-generating developer test fallback).

---

## 📁 Repository Structure

```
Card/
├── backend/                  # Node.js + Express API Backend
│   ├── src/
│   │   ├── models/           # Mongoose Schemas (Citizen, OtpSession, Order, etc.)
│   │   ├── routes/           # API Routers (Auth, Citizens, Orders, BloodRequests)
│   │   ├── seed/             # Initial mock data seeder
│   │   └── index.js          # App Server entry point
│   └── .gitignore            # Backend ignore patterns (.env, node_modules)
├── lib/                      # Flutter Application Codebase
│   ├── models/               # Dart Data Models (MedicalProfile, EmergencyContact)
│   ├── providers/            # SwasthyaTap State Providers
│   ├── screens/              # UI screens (Citizen Portal, Hospital Portal)
│   ├── services/             # HTTP Client Services (ApiService)
│   ├── theme/                # Premium App Styling System
│   └── utils/                # Localization & PDF download generators
└── README.md                 # Project Documentation
```

---

## 🚀 Getting Started

### 1. Prerequisites
* **Flutter SDK** (v3.22.0 or higher)
* **Node.js** (v18 or higher)
* **MongoDB** (Atlas account or local instance)

### 2. Backend Setup
Navigate to the backend directory, install packages, and create a configuration file:
```bash
cd backend
npm install
```

Create a `.env` file inside the `backend/` directory:
```env
PORT=3000
MONGO_URI=mongodb+srv://adichhipa2_db_user:Oo2WWuEiChjI7Ab8@swasthyatap.abo8hz9.mongodb.net/?appName=swasthyatap
JWT_SECRET=super_secret_jwt_key
```

Seed the database with preconfigured mock users:
```bash
npm run seed
```

Start the API Server:
```bash
npm run dev
```

### 3. Flutter App Setup
Return to the root directory, fetch dependencies, and run the development server:
```bash
cd ..
flutter pub get
flutter run -d web-server --web-port 45885
```

---

## 🔒 Security & Privacy Features

* **NFC Emergency PIN Bypass:** Citizens can toggle whether responders need a PIN to view records or if they can bypass in an active emergency.
* **Cryptographic Signatures:** Organ pledges are hashed cryptographically (`SHA-256`) to ensure the integrity of user consent.
* **Secure Storage:** User authorization tokens are encrypted and persistent across app sessions.
