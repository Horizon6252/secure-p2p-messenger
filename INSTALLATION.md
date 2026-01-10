# Installation Guide

Complete guide for setting up Secure P2P Messenger for your team.

[English](#english) | [Русский](INSTALLATION_RU.md)

---

## English

## Table of Contents

1. [Server Setup](#server-setup)
2. [Client Configuration](#client-configuration)
3. [Building Applications](#building-applications)
4. [Distributing to Users](#distributing-to-users)
5. [Troubleshooting](#troubleshooting)

---

## Server Setup

### Requirements

- **VPS** with public IP address
- **512MB RAM** minimum (1GB recommended for 50+ users)
- **10GB storage**
- **Ubuntu 20.04+** or any Linux distribution
- **Port 9090** open for WebSocket connections

### Option 1: Direct Installation (Recommended)

#### 1. Install Dart SDK

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install apt-transport-https wget -y

# Add Dart repository
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

# Install Dart
sudo apt update
sudo apt install dart -y

# Add Dart to PATH
echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
dart --version
```

#### 2. Configure Server

```bash
# Create directory
mkdir -p ~/messenger-server
cd ~/messenger-server

# Download server.dart from repository
wget https://raw.githubusercontent.com/sssilverhand/secure-p2p-messenger/main/server/server.dart

# Edit access codes
nano server.dart
```

**Generate secure access codes:**

```bash
# Method 1: Using OpenSSL (recommended)
openssl rand -base64 20 | tr -d '/+=' | head -c 24 | sed 's/\(....\)/SECURE-\1-/g' | sed 's/-$//'

# Method 2: Using /dev/urandom
cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 24 | head -n 1 | sed 's/\(....\)/SECURE-\1-/g' | sed 's/-$//'

# Example output:
# SECURE-A1B2-C3D4-E5F6-G7H8
```

**Edit server.dart and add your codes:**

```dart
final Set<String> accessCodes = {
  'SECURE-YOUR-CODE-HERE-1234',
  'SECURE-YOUR-CODE-HERE-5678',
  'SECURE-YOUR-CODE-HERE-9012',
  // Add one code per user/group
};
```

#### 3. Configure Firewall

```bash
# Allow SSH (if not already allowed)
sudo ufw allow 22

# Allow messenger port
sudo ufw allow 9090

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

#### 4. Create Systemd Service (Auto-start on boot)

```bash
# Create service file
sudo nano /etc/systemd/system/messenger-server.service
```

**Add this content:**

```ini
[Unit]
Description=Secure P2P Messenger Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/messenger-server
ExecStart=/usr/lib/dart/bin/dart /root/messenger-server/server.dart
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start service:**

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable messenger-server

# Start server
sudo systemctl start messenger-server

# Check status
sudo systemctl status messenger-server

# View logs
sudo journalctl -u messenger-server -f
```

#### 5. Test Server

```bash
# Check if server is running
netstat -tulpn | grep 9090

# Test WebSocket connection
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" http://YOUR_SERVER_IP:9090
```

### Option 2: Docker Installation

#### 1. Create Dockerfile

```dockerfile
FROM dart:stable

WORKDIR /app

COPY server.dart .

EXPOSE 9090

CMD ["dart", "server.dart"]
```

#### 2. Build and Run

```bash
# Build image
docker build -t messenger-server .

# Run container
docker run -d -p 9090:9090 --name messenger --restart unless-stopped messenger-server

# View logs
docker logs -f messenger

# Stop/Start
docker stop messenger
docker start messenger
```

---

## Client Configuration

### Requirements

- **Flutter 3.0+**
- **Dart SDK 3.0+**
- **Android SDK** (for APK builds)
- **Visual Studio 2019+** (for Windows builds)

### 1. Clone Repository

```bash
git clone https://github.com/sssilverhand/secure-p2p-messenger.git
cd secure-p2p-messenger
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Client

```bash
# Copy example config
cp lib/config.example.dart lib/config.dart

# Edit config
nano lib/config.dart
```

**Update these values:**

```dart
class Config {
  // Replace with your VPS IP address
  static const String SERVER_URL = "ws://YOUR_SERVER_IP:9090";
  
  // Get free App ID from https://console.agora.io/
  static const String AGORA_APP_ID = "YOUR_AGORA_APP_ID";
  
  // Optional: Adjust file size limit
  static const int MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
}
```

### 4. Get Agora App ID (for Voice/Video Calls)

1. Go to [https://console.agora.io/](https://console.agora.io/)
2. Sign up for free account
3. Create new project
4. Copy **App ID** (NOT App Certificate)
5. Paste it in `config.dart`

**Note:** Free tier includes:
- 10,000 minutes/month
- Sufficient for small groups
- No credit card required

---

## Building Applications

### Android APK

#### 1. Configure Android

Edit `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    // Change to your unique package name
    applicationId = "com.yourcompany.securemessenger"
    minSdk = 21
    targetSdk = 34
    versionCode = 1
    versionName = "1.0.0"
}
```

#### 2. Build APK

```bash
# Clean build
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

#### 3. (Optional) Sign APK for Production

```bash
# Generate keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias upload

# Create android/key.properties
cat > android/key.properties << EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
EOF

# Update android/app/build.gradle.kts (see comments in file)
# Then rebuild
flutter build apk --release
```

### Windows EXE

#### 1. Prerequisites

- **Visual Studio 2019+** with C++ Desktop Development
- **Windows 10+**

#### 2. Build Windows App

```bash
# Clean build
flutter clean
flutter pub get

# Build release
flutter build windows --release

# Output location:
# build/windows/runner/Release/
```

#### 3. Create Distribution Package

```bash
# Create folder for distribution
mkdir secure-messenger-windows

# Copy all files from Release folder
cp -r build/windows/runner/Release/* secure-messenger-windows/

# Create ZIP archive
zip -r secure-messenger-windows.zip secure-messenger-windows/
```

**Files to include:**
- `secure_p2p_messenger.exe`
- All `.dll` files
- `data/` folder

---

## Distributing to Users

### What Users Need

1. **Access Code** (generated by you)
2. **APK file** (Android) or **EXE package** (Windows)

### Distribution Methods

#### Option 1: Direct Transfer

- Send APK/EXE via secure channel
- Send access code separately (SMS, encrypted email, etc.)

#### Option 2: GitHub Releases

1. Go to repository → Releases
2. Create new release
3. Upload APK and Windows ZIP
4. Share release link with users

#### Option 3: Private File Server

- Host files on your VPS
- Share download links

### User Installation Steps

#### Android:

1. Enable "Unknown Sources" in Settings
2. Download and install APK
3. Open app
4. Enter access code
5. Start messaging!

#### Windows:

1. Download and extract ZIP file
2. Run `secure_p2p_messenger.exe`
3. Enter access code
4. Start messaging!

---

## Troubleshooting

### Server Issues

#### Server Won't Start

```bash
# Check if port is already in use
sudo lsof -i :9090

# Kill process using port
sudo kill -9 <PID>

# Restart server
sudo systemctl restart messenger-server
```

#### Connection Refused

```bash
# Check firewall
sudo ufw status

# Allow port
sudo ufw allow 9090

# Check if server is running
sudo systemctl status messenger-server
```

#### View Server Logs

```bash
# Real-time logs
sudo journalctl -u messenger-server -f

# Last 100 lines
sudo journalctl -u messenger-server -n 100
```

### Client Issues

#### Cannot Connect to Server

1. **Check SERVER_URL in config.dart:**
   - Must start with `ws://` (not `http://`)
   - Use VPS public IP (not localhost)
   - Port must be 9090

2. **Check VPS firewall:**
   ```bash
   sudo ufw allow 9090
   ```

3. **Test connection:**
   ```bash
   telnet YOUR_SERVER_IP 9090
   ```

#### Invalid Access Code

- Code is case-sensitive
- Format: `SECURE-XXXX-XXXX-XXXX-XXXX`
- Check if code exists in server.dart

#### Calls Not Working

1. **Check Agora App ID:**
   - Must be valid App ID (not App Certificate)
   - No spaces or quotes

2. **Check permissions:**
   - Android: Microphone + Camera in Settings
   - Windows: Allow app through firewall

#### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub upgrade

# For Android
flutter build apk --release

# For Windows
flutter build windows --release
```

### Network Issues in Restricted Countries

If calls fail in Russia/China:

1. Agora uses global edge servers
2. Works through DPI/packet inspection
3. Fallback to TURN relay if needed
4. No VPN required for basic functionality

---

## Security Best Practices

### For Administrators:

1. **Keep access codes secure:**
   - Never commit real codes to Git
   - Store separately from repository
   - Use strong random codes

2. **Update server regularly:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Monitor server logs:**
   ```bash
   sudo journalctl -u messenger-server -f
   ```

4. **Backup keystore files:**
   - Store Android keystore safely
   - Keep password secure

### For Users:

1. **Keep access code secret**
2. **Don't share account with others**
3. **Enable device lock/PIN**
4. **Use "Emergency Wipe" if device lost**

---

## Updating

### Server Update

```bash
# Stop server
sudo systemctl stop messenger-server

# Update server.dart
cd ~/messenger-server
wget https://raw.githubusercontent.com/sssilverhand/secure-p2p-messenger/main/server/server.dart -O server.dart

# Restart server
sudo systemctl start messenger-server
```

### Client Update

```bash
# Pull latest changes
git pull origin main

# Update dependencies
flutter pub get

# Rebuild
flutter build apk --release
flutter build windows --release
```

---

## FAQ

**Q: How many users can one server handle?**
A: 50+ users easily on 1GB RAM VPS. Tested with 100+ concurrent connections.

**Q: Can I use domain name instead of IP?**
A: Yes! Use `ws://yourdomain.com:9090` in config.dart

**Q: Does it work without VPS?**
A: No. Server is required for relay and offline message storage.

**Q: Can I use HTTPS/WSS?**
A: Yes, but requires SSL certificate and nginx reverse proxy.

**Q: How to generate more access codes?**
A: Use the OpenSSL command in Server Setup section.

**Q: What if I lose my access code?**
A: Administrator must generate new code. Data cannot be recovered without code.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/sssilverhand/secure-p2p-messenger/issues)
- **Discussions:** [GitHub Discussions](https://github.com/sssilverhand/secure-p2p-messenger/discussions)

---

**Made with ❤️ by [sssilverhand](https://github.com/sssilverhand)**
