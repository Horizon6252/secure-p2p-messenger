# Secure P2P Messenger

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)

A lightweight, secure, end-to-end encrypted peer-to-peer messenger designed for small groups (10-50 users) with multi-device support.

[English](#english) | [Русский](README_RU.md)

---

## English

### ✨ Key Features

#### 🔐 Security & Privacy
- **End-to-End Encryption (E2EE)** using X25519 Elliptic Curve Diffie-Hellman
- **No phone numbers or emails** - access via secure codes only
- **Server-side encryption** - server cannot read your messages
- **Multi-device login** - one access code for all your devices (phone, PC, tablet)
- **Local encrypted storage** - messages stored securely on device

#### 💬 Messaging
- **Text messages** with real-time delivery
- **Voice messages** with AAC encoding
- **Video messages** with audio (up to 10MB)
- **File sharing** (up to 10MB)
- **Offline delivery** - messages stored up to 24 hours
- **Online status indicators**

#### 📞 Voice & Video Calls
- **High-quality voice calls** via Agora RTC
- **Video calls** with audio
- **Works in restricted networks** (Russia, China, etc.)
- **No external dependencies** for basic functionality

#### 🖥️ Multi-Platform
- **Android** (APK)
- **Windows** (EXE)
- iOS/macOS/Linux (with minor modifications)

---

### 🎯 Perfect For

- Small teams (10-50 people)
- Family groups
- Private communities
- Organizations needing privacy
- Users in restricted network environments
- Self-hosted communication solutions

---

### 🚀 Quick Start

#### Requirements

**Server (VPS):**
- 512MB RAM minimum (1GB recommended)
- 10GB storage
- Public IP address
- Dart SDK 3.0+ or Docker

**Client:**
- Flutter 3.0+
- Android SDK (for APK builds)
- Visual Studio (for Windows builds)

#### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/sssilverhand/secure-p2p-messenger.git
cd secure-p2p-messenger
```

2. **Set up the server:**
```bash
cd server
# Edit server.dart - add your access codes
nano server.dart

# Run the server
dart server.dart
```

3. **Configure the client:**
```bash
cd ../
# Copy example config
cp lib/config.example.dart lib/config.dart

# Edit config.dart - add your server IP and Agora App ID
nano lib/config.dart
```

4. **Build the app:**
```bash
# For Android
flutter build apk --release

# For Windows
flutter build windows --release
```

See [INSTALLATION.md](INSTALLATION.md) for detailed instructions.

---

### 🏗️ Architecture

```
┌─────────────┐     WebSocket      ┌─────────────┐
│   Client    │◄──────────────────►│   Server    │
│  (Flutter)  │    E2EE Messages   │   (Dart)    │
└─────────────┘                    └─────────────┘
       │                                   │
       │                                   │
       ├─ X25519 Key Exchange              ├─ Message Queue
       ├─ AES-256-GCM Encryption           ├─ Offline Storage (24h)
       ├─ Local Encrypted Storage          └─ Access Code Auth
       └─ Agora RTC (Voice/Video)
```

### Security Flow

1. **Authentication:** Access code → Ed25519 key derivation → Public ID
2. **Key Exchange:** X25519 ECDH between users
3. **Encryption:** AES-256-GCM for all messages
4. **Calls:** Agora RTC with end-to-end encryption

---

### 🔧 Configuration

#### Server Configuration

Edit `server/server.dart`:

```dart
final Set<String> accessCodes = {
  'SECURE-XXXX-XXXX-XXXX-XXXX',  // Generate your own codes
  'SECURE-YYYY-YYYY-YYYY-YYYY',
  // Add more codes as needed
};
```

#### Client Configuration

Edit `lib/config.dart`:

```dart
class Config {
  static const String SERVER_URL = "ws://YOUR_SERVER_IP:9090";
  static const String AGORA_APP_ID = "YOUR_AGORA_APP_ID";
  static const int MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
}
```

---

### 📊 Specifications

| Feature | Limit | Notes |
|---------|-------|-------|
| **Max Users** | 50+ | Tested on 1GB RAM VPS |
| **Message Size** | 10MB | Configurable |
| **Offline Storage** | 24 hours | Automatic cleanup |
| **Encryption** | X25519 + AES-256-GCM | Military-grade |
| **Call Quality** | HD Audio/Video | Via Agora RTC |
| **Platforms** | Android, Windows | iOS/macOS/Linux compatible |

---

### 🛡️ Security

This messenger implements modern cryptographic standards:

- **X25519** Elliptic Curve Diffie-Hellman for key exchange
- **AES-256-GCM** for message encryption
- **Ed25519** for identity derivation
- **Zero-knowledge** server architecture

See [SECURITY.md](SECURITY.md) for detailed security analysis.

---

### 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

### 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

### 🙏 Acknowledgments

- **Flutter** - Cross-platform UI framework
- **Agora** - Real-time communication SDK
- **Dart** - Programming language

---

### 📞 Support

- **Issues:** [GitHub Issues](https://github.com/sssilverhand/secure-p2p-messenger/issues)
- **Discussions:** [GitHub Discussions](https://github.com/sssilverhand/secure-p2p-messenger/discussions)

---

### ⚠️ Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The authors are not responsible for any misuse or damage caused by this software.

---

### 🌟 Star History

If you find this project useful, please consider giving it a star ⭐

---

Made with ❤️ by [sssilverhand](https://github.com/sssilverhand)
