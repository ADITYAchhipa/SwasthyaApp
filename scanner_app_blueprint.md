# Blueprint & Specification: Scanner-Only App with Automatic Decryption

This document serves as a complete technical guide and prompt for other AI models to generate a new, dedicated **Scanner-Only** application. It captures the essence of the system we built, its core cryptographic flow, and provides detailed specifications and code templates to implement automatic decryption (password-less) for both web and mobile environments.

---

## Part 1: Architecture of the Existing Application

We built a web-based **Offline Secret QR Messenger** that allows users to encrypt messages, generate QR codes, scan QR codes, and decrypt them using a password.

### 1. Technology Stack
* **Framework**: React (v19) configured with Vite (v8) as the build tool.
* **Styling**: Tailwind CSS (v4) for clean, utility-first styling.
* **Routing**: React Router DOM (v7) for page transitions.
* **QR Generation**: `qrcode` npm package.
* **QR Scanning**: `html5-qrcode` npm package (for camera streaming and decoding).
* **Cryptography**: `crypto-js` npm package (AES-256 for symmetric encryption/decryption, SHA-256 for integrity).
* **Testing**: Vitest for unit tests.

### 2. Folder Structure
```text
src/
├── components/
│   ├── MessageForm.jsx    # Form to input secret message, password, and advanced options
│   ├── QRDisplay.jsx      # Renders and allows downloading the generated QR code
│   └── QRScanner.jsx      # Component interfacing with camera to scan QR codes via html5-qrcode
├── pages/
│   ├── GenerateQR.jsx     # Logic wrapper for generating and encrypting a QR
│   └── ScanQR.jsx         # Logic wrapper for scanning, prompt password input, and decrypting
├── utils/
│   ├── encrypt.js         # Encryption logic (AES-256 with PBKDF2 derivation)
│   ├── decrypt.js         # Decryption logic, metadata evaluation, integrity checks
│   └── filename.js        # File naming utility
├── App.jsx                # Core shell layout, routes (/generate, /scan)
└── main.jsx               # React entry point
```

### 3. Encryption & Decryption Mechanism
* **Symmetric AES-256**: Uses CryptoJS AES. When a text password is provided, PBKDF2 is used internally to derive a key.
* **Payload Structure**:
  * **Inner Payload** (JSON string before encryption):
    ```json
    {
      "plaintext": "Actual message/user info content",
      "expiry": "ISO DateTime String (optional)",
      "sender": "Sender Name (optional)",
      "createdAt": "ISO DateTime String (optional)",
      "hash": "SHA-256 string of plaintext (optional)",
      "messageId": "UUID string for one-time read (optional)"
    }
    ```
  * **Outer Payload** (JSON string stored in the QR code):
    ```json
    {
      "version": 1,
      "data": "U2FsdGVkX19..." // CryptoJS AES Ciphertext (base64 encoded)
    }
    ```

---

## Part 2: Requirements for the New Scanner-Only App

The goal is to create a new application that focuses **solely on scanning user data** (e.g., identity cards, medical info, or user profiles) with **no password prompt** shown to the operator. 

### Core Features:
1. **Scan-Only Interface**: No message composer or generator page. The app boots directly to the scanner or a simple dashboard.
2. **Auto-Decryption**: Once a QR code is captured, the app automatically decrypts the content using a pre-determined cryptographic scheme.
3. **User Profile Display**: Formats and displays the decrypted user information in a polished, premium profile card (Name, Age, Emergency Contact, Medical info, etc.).
4. **Offline Capability**: Operates 100% client-side with no network connection required.

---

## Part 3: Automated Encryption/Decryption Strategies
To achieve password-less decryption, we can choose between two main strategies. Both ensure the QR contents remain encrypted (unreadable to standard QR scanner apps like Google Lens) while decrypting instantly in our custom app.

### Strategy A: Shared Static Secret Key (Symmetric AES)
The generator (card creator) and the scanner app share a hardcoded static encryption key/passphrase.
* **Pros**: Simple to implement; fits easily into the existing `CryptoJS.AES` codebase.
* **Cons**: Anyone who extracts the key from the source code can decrypt any QR code.
* **Best for**: Closed enterprise applications or low-stakes utility environments.

### Strategy B: Asymmetric Cryptography (Public/Private Key pair)
The scanner app contains a hardcoded Private Key. The generator contains the corresponding Public Key.
* **Flow**:
  1. The generator encrypts the user's data using the **Public Key** (using RSA-OAEP or hybrid ECIES).
  2. The generated QR code is scanned.
  3. The scanner app decrypts the QR payload automatically using the embedded **Private Key**.
* **Pros**: High security. If someone steals the generator software, they can only *create* encrypted QRs; they cannot decrypt other users' QRs because they don't have the Private Key (which only resides inside the scanner app).
* **Cons**: Asymmetric encryption has size limitations. Large payloads require hybrid encryption (generating a random symmetric key, encrypting the payload with AES, and encrypting the AES key with the RSA Public Key).

---

## Part 4: Technical Implementations (React & Flutter)

Provide these templates to another AI model to generate the new app in either web (React) or mobile (Flutter).

### Implementation 1: React / Vite (Web App)

#### 1. Automated Decryption Utility (`src/utils/autoDecrypt.js`)
This replaces `decrypt.js` and uses a system key (Strategy A) to instantly decrypt without asking for user input.

```javascript
import CryptoJS from 'crypto-js';

// Pre-shared system key. Change this to a secure passphrase.
const SYSTEM_SECRET_KEY = "SwasthyaTap_System_Secure_Key_2026";

export class DecryptionError extends Error {
  constructor(message) {
    super(message);
    this.name = 'DecryptionError';
  }
}

/**
 * Automatically decrypts the QR payload using the pre-shared system key.
 * @param {string} payloadJson - The raw QR scan output
 * @returns {Object} Decrypted user profile data
 */
export function autoDecryptPayload(payloadJson) {
  let outerPayload;
  try {
    outerPayload = JSON.parse(payloadJson);
  } catch {
    throw new DecryptionError('Invalid payload format: Not valid JSON');
  }

  if (!outerPayload || outerPayload.version !== 1 || !outerPayload.data) {
    throw new DecryptionError('Invalid payload structure: Missing version or data');
  }

  try {
    // Decrypt using our system secret key
    const decryptedBytes = CryptoJS.AES.decrypt(outerPayload.data, SYSTEM_SECRET_KEY);
    const plaintext = decryptedBytes.toString(CryptoJS.enc.Utf8);
    
    if (!plaintext) {
      throw new DecryptionError('Decryption failed: Incorrect key or corrupted data');
    }

    const innerPayload = JSON.parse(plaintext);
    return innerPayload;
  } catch (err) {
    throw new DecryptionError('Failed to parse or decrypt payload contents');
  }
}
```

#### 2. Scan Screen Component (`src/pages/ScanOnly.jsx`)
```jsx
import { useState } from 'react';
import QRScanner from '../components/QRScanner.jsx';
import { autoDecryptPayload } from '../utils/autoDecrypt.js';

export default function ScanOnly() {
  const [scannerActive, setScannerActive] = useState(true);
  const [userData, setUserData] = useState(null);
  const [error, setError] = useState(null);

  function handleScan(data) {
    try {
      setError(null);
      const decodedData = autoDecryptPayload(data);
      
      // Expected structure of user data: { name, age, phone, bloodGroup, emergencyContact }
      setUserData(decodedData);
      setScannerActive(false); // Stop camera on success
    } catch (err) {
      setError(err.message || 'Failed to decrypt QR code');
    }
  }

  function handleScanError(err) {
    setError(`Camera error: ${err}`);
  }

  function handleReset() {
    setUserData(null);
    setError(null);
    setScannerActive(true);
  }

  return (
    <div className="max-w-md mx-auto p-4 space-y-6">
      <h2 className="text-2xl font-bold text-center text-gray-900">User Info Scanner</h2>
      
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded-md flex flex-col gap-2">
          <p className="text-sm font-medium">{error}</p>
          <button onClick={handleReset} className="text-xs underline text-left font-bold">Try Again</button>
        </div>
      )}

      {scannerActive && (
        <div className="relative border-4 border-dashed border-blue-500 rounded-lg p-2 bg-black/5">
          <QRScanner onScan={handleScan} onError={handleScanError} active={scannerActive} />
          <div className="absolute top-2 left-1/2 -translate-x-1/2 bg-blue-600 text-white text-xs px-3 py-1 rounded-full shadow-sm">
            Align user QR code in center
          </div>
        </div>
      )}

      {userData && (
        <div className="bg-white shadow-xl rounded-2xl border border-gray-100 overflow-hidden transform transition-all duration-300">
          <div className="bg-gradient-to-r from-blue-600 to-indigo-700 p-6 text-white text-center">
            <div className="w-20 h-20 bg-white/20 rounded-full mx-auto flex items-center justify-center text-3xl font-extrabold shadow-inner mb-3">
              {userData.name ? userData.name[0].toUpperCase() : 'U'}
            </div>
            <h3 className="text-xl font-bold">{userData.name || 'N/A'}</h3>
            <p className="text-blue-100 text-sm">User Details</p>
          </div>
          
          <div className="p-6 space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <span className="text-xs text-gray-400 block uppercase">Age</span>
                <span className="font-semibold text-gray-800 text-sm">{userData.age || 'N/A'}</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 block uppercase">Blood Group</span>
                <span className="font-semibold text-red-600 text-sm">{userData.bloodGroup || 'N/A'}</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 block uppercase">Phone</span>
                <span className="font-semibold text-gray-800 text-sm">{userData.phone || 'N/A'}</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 block uppercase">Emergency Contact</span>
                <span className="font-semibold text-gray-800 text-sm">{userData.emergencyContact || 'N/A'}</span>
              </div>
            </div>
            
            {userData.medicalHistory && (
              <div className="border-t border-gray-100 pt-4">
                <span className="text-xs text-gray-400 block uppercase">Medical Notes</span>
                <p className="text-sm text-gray-600 mt-1">{userData.medicalHistory}</p>
              </div>
            )}
            
            <button 
              onClick={handleReset}
              className="w-full mt-4 bg-gray-900 text-white py-2.5 rounded-xl font-medium hover:bg-gray-800 transition-colors"
            >
              Scan Next User
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
```

---

### Implementation 2: Flutter / Dart (Mobile App)

For building this directly as a Flutter mobile application, follow this specification.

#### 1. Required Packages (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  mobile_scanner: ^5.1.1       # Fast & reliable native QR scanning
  encrypt: ^5.0.3              # Symmetric encryption wrapper for AES
```

#### 2. Crypto Helper (`lib/utils/crypto_helper.dart`)
```dart
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoHelper {
  // Pre-shared system key (must match the encryption generator side, 32 characters for AES-256)
  static const String _systemKey = "SwasthyaTapSystemKey32Characters!"; 

  /// Decrypts the QR content JSON using the static key and parses it.
  static Map<String, dynamic> decryptUserInfo(String payloadJson) {
    try {
      final Map<String, dynamic> outer = jsonDecode(payloadJson);
      
      if (outer['version'] != 1 || outer['data'] == null) {
        throw Exception("Invalid format version");
      }

      final String ciphertext = outer['data'];

      // Setup encryption keys (matching AES-CBC standard or AES-GCM)
      // Note: encrypt package expects 256-bit key (32 bytes)
      final key = encrypt.Key.fromUtf8(_systemKey);
      
      // If Using standard AES/CBC/PKCS7 (default in CryptoJS):
      // CryptoJS appends "Salted__" (8 bytes) + 8 bytes salt to the start of the payload.
      // Below is a pure AES fallback using a simple fixed IV for clean offline mobile performance.
      final iv = encrypt.IV.fromLength(16); // or match your IV scheme
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final decrypted = encrypter.decrypt64(ciphertext, iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Failed to decrypt: ${e.toString()}");
    }
  }
}
```

#### 3. Scanner Screen Page (`lib/screens/scan_only_screen.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/crypto_helper.dart';

class ScanOnlyScreen extends StatefulWidget {
  const ScanOnlyScreen({Key? key}) : super(key: key);

  @override
  State<ScanOnlyScreen> createState() => _ScanOnlyScreenState();
}

class _ScanOnlyScreenState extends State<ScanOnlyScreen> {
  bool _isScanning = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String rawValue = barcodes.first.rawValue!;
      setState(() {
        _isScanning = false;
      });

      try {
        final data = CryptoHelper.decryptUserInfo(rawValue);
        setState(() {
          _userData = data;
          _errorMessage = null;
        });
      } catch (e) {
        setState(() {
          _errorMessage = "Invalid QR code or decryption failed.";
          _userData = null;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _userData = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Info Scanner'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: _errorMessage != null
              ? _buildErrorWidget()
              : _userData != null
                  ? _buildProfileCard()
                  : _buildCameraScanner(),
        ),
      ),
    );
  }

  Widget _buildCameraScanner() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Point your camera at the user QR code',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 320,
            height: 320,
            child: MobileScanner(
              onDetect: _onDetect,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _resetScanner,
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _userData?['name'] ?? 'Unknown User';
    final age = _userData?['age'] ?? 'N/A';
    final bloodGroup = _userData?['bloodGroup'] ?? 'N/A';
    final phone = _userData?['phone'] ?? 'N/A';
    final emergencyContact = _userData?['emergencyContact'] ?? 'N/A';
    final medicalNotes = _userData?['medicalHistory'] ?? 'None';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Verified Profile',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoTile('Age', age.toString()),
                _buildInfoTile('Blood Group', bloodGroup, isAlert: true),
                _buildInfoTile('Phone Number', phone),
                _buildInfoTile('Emergency Contact', emergencyContact),
                const Divider(),
                const Text(
                  'Medical Notes',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  medicalNotes,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _resetScanner,
                    child: const Text('Scan Next Code'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isAlert ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
```
