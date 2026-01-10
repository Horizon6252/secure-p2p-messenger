# Security Documentation

Comprehensive security analysis of Secure P2P Messenger.

[English](#english) | [Русский](SECURITY_RU.md)

---

## English

## Table of Contents

1. [Cryptographic Architecture](#cryptographic-architecture)
2. [Threat Model](#threat-model)
3. [Security Features](#security-features)
4. [Attack Resistance](#attack-resistance)
5. [Known Limitations](#known-limitations)
6. [Best Practices](#best-practices)
7. [Vulnerability Disclosure](#vulnerability-disclosure)

---

## Cryptographic Architecture

### End-to-End Encryption (E2EE)

The messenger implements a multi-layer encryption scheme:

```
User A                          Server                          User B
  │                               │                               │
  │ ─── Access Code ────────────► │ ◄──── Access Code ─────────  │
  │                               │                               │
  │ ◄── Ed25519 Identity ────────┤────── Ed25519 Identity ─────► │
  │                               │                               │
  │ ──────── X25519 ECDH Key Exchange (via server) ────────────► │
  │                               │                               │
  │ ◄────────── Shared Secret (AES-256-GCM) ──────────────────► │
  │                               │                               │
  │ ─── Encrypted Message ──────► │ ─── Encrypted Message ─────► │
  │     (Server cannot decrypt)   │     (Server cannot decrypt)   │
```

### Cryptographic Components

#### 1. Identity Generation (Ed25519)

**Purpose:** Derive deterministic public ID from access code

```dart
// Pseudocode
accessCode → SHA-256 → seed (32 bytes)
seed → Ed25519 KeyPair
publicKey → base64 → Public ID (visible to others)
privateKey → base64 → Private Key (stored locally)
```

**Properties:**
- Deterministic: Same access code always generates same keys
- Multi-device: Use same code on multiple devices
- No server-side key storage

#### 2. Key Exchange (X25519 ECDH)

**Purpose:** Generate shared encryption key between two users

```dart
// Pseudocode
User A: privateKeyA + publicKeyB → sharedSecretAB
User B: privateKeyB + publicKeyA → sharedSecretAB

// Both arrive at same shared secret
sharedSecretAB → SHA-256 → AES-256 key
```

**Properties:**
- Perfect Forward Secrecy: Each session uses unique shared secret
- Elliptic Curve: 256-bit security (equivalent to 3072-bit RSA)
- Server cannot compute shared secret (zero-knowledge)

#### 3. Message Encryption (AES-256-GCM)

**Purpose:** Encrypt message content

**Algorithm:** AES-256 in GCM mode
- **Key Size:** 256 bits
- **Nonce:** 96 bits (random)
- **MAC:** 128 bits (authentication tag)

**Properties:**
- Authenticated Encryption: Integrity + confidentiality
- Resistant to tampering
- Nonce never reused (random generation)

**Encryption Process:**
```
plaintext + sharedKey + randomNonce → [ciphertext + MAC]
```

**Decryption Process:**
```
[ciphertext + MAC] + sharedKey → verify MAC → plaintext
```

---

## Threat Model

### What We Protect Against

#### ✅ Protected:

1. **Passive Network Monitoring**
   - ISP cannot read messages
   - Government surveillance cannot decrypt
   - DPI cannot extract content

2. **Server Compromise**
   - Server admin cannot read messages
   - Server breach doesn't expose message content
   - Server logs only encrypted data

3. **Man-in-the-Middle (MITM)**
   - Public key exchange verified via access code
   - Each user verifies peer's public ID
   - Server cannot impersonate users

4. **Message Tampering**
   - AES-GCM MAC detects modifications
   - Invalid MAC → message rejected

5. **Replay Attacks**
   - Timestamp checking (messages older than 24h dropped)
   - Nonce uniqueness prevents replay

#### ❌ NOT Protected:

1. **Endpoint Compromise**
   - If device is hacked, messages are readable
   - Keylogger can capture messages before encryption
   - **Mitigation:** Device security (PIN, encryption, etc.)

2. **Access Code Leakage**
   - If access code stolen, attacker gets same identity
   - **Mitigation:** Keep code secret, emergency wipe feature

3. **Traffic Analysis**
   - Server knows who talks to whom
   - Server knows message timing/size
   - **Mitigation:** Use Tor/VPN for metadata privacy

4. **Screen Recording / Screenshots**
   - Visual access to device exposes messages
   - **Mitigation:** Physical device security

---

## Security Features

### 1. Zero-Knowledge Server

**What server KNOWS:**
- User is online/offline
- Message routing (from → to)
- Message size and timestamp

**What server CANNOT know:**
- Message content (encrypted)
- User identity (only sees public key hash)
- Relationship between access code and public ID

### 2. Local Encrypted Storage

**Storage Format:**
```
flutter_secure_storage (platform keychain)
├── contacts (encrypted JSON)
├── messages_<contactID> (encrypted JSON per contact)
├── public_key (base64)
├── private_key (base64)
└── access_code (stored for convenience)
```

**Platform Security:**
- **Android:** Android Keystore (hardware-backed on modern devices)
- **Windows:** Windows Credential Manager (DPAPI)

### 3. Offline Message Security

**Server Storage:**
```
pendingMessages[userID] = [
  {encrypted_message_1},
  {encrypted_message_2},
  ...
]
```

**Properties:**
- Messages stored encrypted (server cannot read)
- 24-hour TTL (automatic cleanup)
- Delivered on next connection
- Removed from server after delivery

### 4. Multi-Device Security

**Same Access Code = Same Identity:**
```
Device A: code → keyPair A
Device B: code → keyPair A (identical!)
```

**Advantages:**
- Seamless multi-device login
- No device pairing needed

**Risks:**
- Access code compromise = all devices compromised
- **Mitigation:** Keep code extremely secure

---

## Attack Resistance

### 1. Man-in-the-Middle (MITM)

**Attack Scenario:**
```
User A ──► Attacker ──► Server ──► User B
```

**Defense:**
- Public keys derived from access code (verifiable)
- Users can verify peer's Public ID out-of-band
- Server cannot modify public keys (deterministic from code)

**Recommendation:** 
- Verify peer's Public ID in person or via trusted channel
- Compare first 8 characters of Public ID

### 2. Server Compromise

**Attack Scenario:**
- Attacker gains root access to VPS
- Reads all server memory and logs

**What attacker gets:**
- List of online users (public IDs)
- Encrypted message queue
- Message routing metadata

**What attacker CANNOT get:**
- Message plaintext (encrypted E2EE)
- Access codes (not stored on server)
- Private keys (stored only on clients)

### 3. Replay Attack

**Attack Scenario:**
- Attacker captures encrypted message
- Resends it later to recipient

**Defense:**
- Nonce randomness (different ciphertext each time)
- Timestamp checking (24-hour window)
- Application-level deduplication

### 4. Denial of Service (DoS)

**Attack Scenario:**
- Attacker floods server with connections

**Mitigation:**
- Access code validation (attackers need valid codes)
- Rate limiting at network level (firewall)
- Small user base (10-50) makes DoS less attractive

**Recommendation:**
- Use fail2ban or similar
- Limit connections per IP

### 5. Traffic Analysis

**Attack Scenario:**
- Adversary monitors network traffic
- Learns who talks to whom, when, how much

**Current Status:** NOT PROTECTED
- Server sees routing metadata
- ISP sees traffic to/from server IP

**Mitigation Options:**
1. Use VPN/Tor for client connections
2. Add dummy traffic (cover traffic)
3. Implement onion routing (future work)

---

## Known Limitations

### 1. Metadata Leakage

**Problem:** Server knows communication patterns

**Impact:** Medium
- Who talks to whom
- Message frequency
- Online/offline times

**Mitigation:**
- Use Tor/VPN
- Traffic padding (future)

### 2. No Perfect Forward Secrecy (PFS)

**Problem:** Same key pair used for all sessions

**Impact:** Medium
- If access code compromised, all past messages decryptable (if captured)

**Mitigation:**
- Rotate access codes periodically
- Future: Implement Signal Protocol (Double Ratchet)

### 3. Access Code = Master Key

**Problem:** Single point of failure

**Impact:** High if compromised
- Access code leaks → full account access

**Mitigation:**
- Keep code extremely secure
- Emergency wipe feature
- Strong random codes only

### 4. No Message Authentication (Beyond MAC)

**Problem:** No cryptographic signature proving sender identity

**Impact:** Low (trust model assumes server honesty)
- Malicious server could impersonate users theoretically

**Future Improvement:**
- Sign messages with Ed25519 private key

### 5. Agora Calls - External Dependency

**Problem:** Voice/video calls rely on Agora SDK

**Security Status:**
- Agora uses E2EE for calls
- But Agora is closed-source
- Trust in Agora required

**Mitigation:**
- Calls use separate encryption layer
- Future: WebRTC self-hosted (no external)

---

## Best Practices

### For Users:

1. **Access Code Security:**
   - ✅ Store code in password manager
   - ✅ Never share code via insecure channels
   - ❌ Don't write code on paper/notes app
   - ❌ Don't share code on social media

2. **Device Security:**
   - ✅ Enable device lock (PIN/biometric)
   - ✅ Keep OS updated
   - ✅ Use full disk encryption
   - ❌ Don't root/jailbreak device

3. **Network Security:**
   - ✅ Use VPN in untrusted networks
   - ✅ Avoid public WiFi for sensitive chats
   - ❌ Don't disable HTTPS/SSL verification

4. **Emergency Procedures:**
   - ✅ Use "Emergency Wipe" if device lost
   - ✅ Contact admin for new access code
   - ❌ Don't try to "recover" lost code (impossible)

### For Administrators:

1. **Access Code Generation:**
   ```bash
   # Strong random codes only!
   openssl rand -base64 20 | tr -d '/+=' | head -c 24 | \
     sed 's/\(....\)/SECURE-\1-/g' | sed 's/-$//'
   ```
   - ✅ Use cryptographically secure random
   - ❌ Don't use predictable patterns
   - ❌ Don't reuse codes

2. **Server Hardening:**
   ```bash
   # Firewall
   sudo ufw default deny incoming
   sudo ufw allow 22   # SSH
   sudo ufw allow 9090 # Messenger
   
   # Fail2ban
   sudo apt install fail2ban
   
   # Auto-updates
   sudo apt install unattended-upgrades
   ```

3. **Access Code Management:**
   - ✅ Store codes in encrypted database
   - ✅ Distribute via secure channel (in-person, Signal, etc.)
   - ❌ Never commit codes to Git
   - ❌ Never send codes via unencrypted email

4. **Monitoring:**
   ```bash
   # Regular log checks
   sudo journalctl -u messenger-server -f
   
   # Watch for suspicious activity
   grep "Invalid" /var/log/messenger.log
   ```

---

## Vulnerability Disclosure

### Reporting Security Issues

If you discover a security vulnerability, please:

1. **DO NOT** open a public GitHub issue
2. Email: [Your security email here]
3. Include:
   - Vulnerability description
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **24 hours:** Initial response
- **7 days:** Assessment and severity rating
- **30 days:** Patch development and testing
- **Public disclosure:** After patch released (coordinated disclosure)

### Security Updates

- Security fixes released as patches
- Critical issues: Immediate notification to all users
- Minor issues: Included in regular updates

---

## Security Audit Status

### Current Status

- ✅ Code review completed (December 2024)
- ⏳ Independent security audit: Pending
- ⏳ Penetration testing: Pending

### Known Issues

No critical vulnerabilities currently known.

### Future Improvements

1. **Implement Perfect Forward Secrecy**
   - Signal Protocol / Double Ratchet
   - Rotate keys per session

2. **Add Message Signatures**
   - Sign messages with Ed25519
   - Prevent server impersonation

3. **Self-Hosted Calls**
   - Replace Agora with WebRTC
   - Full control over call infrastructure

4. **Metadata Protection**
   - Add traffic padding
   - Implement mixing (delay messages)

---

## Compliance

### GDPR Compliance

- ✅ No personal data collection (no phone/email)
- ✅ User controls all data (local storage)
- ✅ Right to erasure (emergency wipe)
- ✅ Data minimization (only encrypted data on server)

### Data Retention

- **Client:** User controls (delete anytime)
- **Server:** 24 hours maximum (offline messages only)

---

## Conclusion

Secure P2P Messenger provides strong end-to-end encryption suitable for:
- Private team communication
- Sensitive business discussions
- Personal messaging with privacy focus

**Strengths:**
- ✅ Military-grade encryption (X25519 + AES-256-GCM)
- ✅ Zero-knowledge server
- ✅ No phone number / email required
- ✅ Multi-device support

**Limitations:**
- ⚠️ Metadata not hidden
- ⚠️ Access code = single point of failure
- ⚠️ No PFS (yet)

**Recommendation:** Suitable for groups requiring privacy but not for life-threatening scenarios (activists in authoritarian regimes). For maximum security, combine with VPN/Tor.

---

**Questions? [GitHub Discussions](https://github.com/sssilverhand/secure-p2p-messenger/discussions)**

**Made with ❤️ by [sssilverhand](https://github.com/sssilverhand)**
