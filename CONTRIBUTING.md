# Contributing to Secure P2P Messenger

Thank you for your interest in contributing to Secure P2P Messenger! 🎉

[English](#english) | [Русский](CONTRIBUTING_RU.md)

---

## English

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How Can I Contribute?](#how-can-i-contribute)
3. [Development Setup](#development-setup)
4. [Coding Standards](#coding-standards)
5. [Commit Guidelines](#commit-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Security Issues](#security-issues)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of:
- Experience level
- Gender identity
- Sexual orientation
- Disability
- Personal appearance
- Race or ethnicity
- Age
- Religion

### Expected Behavior

✅ **Do:**
- Be respectful and considerate
- Welcome newcomers and help them learn
- Accept constructive criticism gracefully
- Focus on what's best for the project
- Show empathy towards others

❌ **Don't:**
- Use offensive, discriminatory, or harassing language
- Make personal attacks
- Publish others' private information
- Engage in trolling or inflammatory behavior

### Enforcement

Violations can be reported to [your email]. All complaints will be reviewed and investigated promptly and fairly.

---

## How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**Good bug report includes:**
- Clear, descriptive title
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)
- Environment details:
  - OS (Android/Windows version)
  - App version
  - Server version

**Template:**
```markdown
**Description:**
Brief description of the bug

**Steps to Reproduce:**
1. Go to '...'
2. Click on '...'
3. See error

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Environment:**
- OS: Windows 11 / Android 13
- App Version: 2.0.0
- Server Version: 6.0

**Screenshots:**
If applicable
```

### 💡 Suggesting Features

Feature requests are welcome! Please:

1. Check if feature already requested
2. Explain use case and benefits
3. Consider if it fits project scope
4. Be open to discussion

**Template:**
```markdown
**Feature Description:**
What feature do you want?

**Use Case:**
Why is this needed?

**Proposed Solution:**
How would you implement it?

**Alternatives Considered:**
Other options you thought about

**Additional Context:**
Screenshots, mockups, etc.
```

### 📝 Improving Documentation

Documentation improvements are always appreciated:
- Fix typos or unclear explanations
- Add missing information
- Improve examples
- Translate to other languages

### 💻 Code Contributions

We accept contributions for:
- Bug fixes
- New features
- Performance improvements
- Code refactoring
- Test coverage

---

## Development Setup

### Prerequisites

**Required:**
- Flutter 3.0+
- Dart SDK 3.0+
- Git

**For Android:**
- Android Studio
- Android SDK (API 21+)

**For Windows:**
- Visual Studio 2019+ with C++ Desktop Development

### Setup Instructions

1. **Fork the repository:**
```bash
# Click "Fork" button on GitHub
```

2. **Clone your fork:**
```bash
git clone https://github.com/YOUR_USERNAME/secure-p2p-messenger.git
cd secure-p2p-messenger
```

3. **Add upstream remote:**
```bash
git remote add upstream https://github.com/sssilverhand/secure-p2p-messenger.git
```

4. **Install dependencies:**
```bash
flutter pub get
```

5. **Configure for development:**
```bash
# Copy example config
cp lib/config.example.dart lib/config.dart

# Edit config.dart with your test server
nano lib/config.dart
```

6. **Run the app:**
```bash
# For Android
flutter run

# For Windows
flutter run -d windows
```

---

## Coding Standards

### Dart/Flutter Style

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

**✅ Good:**
```dart
// Clear variable names
final String userName = 'Alice';
final List<Message> messages = [];

// Proper formatting
Future<void> sendMessage(String content) async {
  final encrypted = await CryptoEngine.encrypt(content, key);
  RelayService.sendMessage(contactId, {'type': 'text', 'body': encrypted});
}

// Comments for complex logic
// Generate shared secret using X25519 ECDH
final sharedSecret = await algorithm.sharedSecretKey(
  keyPair: myPrivateKey,
  remotePublicKey: theirPublicKey,
);
```

**❌ Bad:**
```dart
// Unclear names
final a = 'Alice';
final m = [];

// Poor formatting
Future<void>sendMessage(String c)async{final e=await CryptoEngine.encrypt(c,k);RelayService.sendMessage(cId,{'type':'text','body':e});}

// No comments for complex code
final s = await alg.sharedSecretKey(keyPair: k1, remotePublicKey: k2);
```

### Code Organization

```
lib/
├── main.dart                 # Entry point
├── config.dart              # Configuration
├── models/                  # Data models
│   ├── contact.dart
│   └── message.dart
├── services/               # Business logic
│   ├── crypto_engine.dart
│   ├── relay_service.dart
│   └── storage_service.dart
├── screens/               # UI screens
│   ├── identity_screen.dart
│   ├── contacts_screen.dart
│   └── chat_screen.dart
└── widgets/              # Reusable components
    └── message_bubble.dart
```

### Naming Conventions

- **Classes:** `PascalCase` (e.g., `CryptoEngine`, `RelayService`)
- **Functions:** `camelCase` (e.g., `sendMessage`, `generateKey`)
- **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAX_FILE_SIZE`)
- **Private:** Prefix with `_` (e.g., `_privateMethod`)

### Comments

```dart
// Good: Explain WHY, not WHAT
// Use X25519 instead of Ed25519 because Ed25519 is for signing, not key exchange
final algorithm = X25519();

// Bad: Redundant
// Create algorithm
final algorithm = X25519();
```

### Error Handling

```dart
// Always handle errors gracefully
try {
  await riskyOperation();
} catch (e) {
  print('Operation failed: $e');
  // Show user-friendly error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to send message')),
  );
}
```

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation changes
- **style:** Code formatting (no logic change)
- **refactor:** Code restructuring
- **test:** Adding tests
- **chore:** Maintenance tasks

### Examples

**Good commits:**
```
feat(crypto): implement X25519 key exchange

Replace Ed25519 with X25519 for key exchange as Ed25519
is designed for digital signatures, not ECDH.

Fixes #42
```

```
fix(chat): prevent message duplication on reconnect

Messages were being duplicated when user reconnected
due to missing deduplication logic in message handler.

Closes #56
```

```
docs(readme): add installation instructions for macOS

Added section covering Homebrew installation and
Flutter setup on macOS systems.
```

**Bad commits:**
```
fixed stuff
```

```
WIP
```

```
Updated files
```

---

## Pull Request Process

### Before Submitting

1. **Update your fork:**
```bash
git fetch upstream
git checkout main
git merge upstream/main
```

2. **Create feature branch:**
```bash
git checkout -b feature/amazing-feature
```

3. **Make your changes:**
```bash
# Edit files
# Test thoroughly
```

4. **Test your changes:**
```bash
# Run on Android
flutter run

# Run on Windows
flutter run -d windows

# Check for issues
flutter analyze
```

5. **Commit with good message:**
```bash
git add .
git commit -m "feat(feature): add amazing feature"
```

6. **Push to your fork:**
```bash
git push origin feature/amazing-feature
```

### Creating Pull Request

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select base: `main` ← compare: `feature/amazing-feature`
4. Fill in PR template:

```markdown
## Description
What does this PR do?

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
How was this tested?
- [ ] Android
- [ ] Windows
- [ ] Manual testing
- [ ] Automated tests

## Checklist
- [ ] Code follows project style
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tested on target platform(s)

## Screenshots (if applicable)
Add screenshots of UI changes
```

### Review Process

1. **Automated checks:** CI will run (if configured)
2. **Code review:** Maintainer will review your code
3. **Requested changes:** Address feedback
4. **Approval:** Once approved, PR will be merged

### After Merge

1. **Delete branch:**
```bash
git branch -d feature/amazing-feature
git push origin --delete feature/amazing-feature
```

2. **Update your fork:**
```bash
git checkout main
git pull upstream main
```

---

## Security Issues

**⚠️ DO NOT open public issues for security vulnerabilities!**

Instead:
1. Email: [your security email]
2. Include:
   - Vulnerability description
   - Steps to reproduce
   - Potential impact
3. We will respond within 24 hours
4. Coordinated disclosure after patch released

See [SECURITY.md](SECURITY.md) for full policy.

---

## Development Tips

### Debugging

```dart
// Use print statements strategically
print('🔐 Encrypting message: ${message.substring(0, 20)}...');
print('✅ Message sent to: ${contactId}');
print('❌ Error: $e');
```

### Testing on Multiple Devices

1. Run two instances (different access codes)
2. Test message delivery
3. Test offline message queue
4. Test calls (requires Agora setup)

### Performance

- Profile with Flutter DevTools
- Check memory leaks
- Monitor network usage
- Test on low-end devices

---

## Getting Help

- **Questions:** [GitHub Discussions](https://github.com/sssilverhand/secure-p2p-messenger/discussions)
- **Bugs:** [GitHub Issues](https://github.com/sssilverhand/secure-p2p-messenger/issues)
- **Chat:** Join our community (if available)

---

## Recognition

Contributors will be:
- Added to [CONTRIBUTORS.md](CONTRIBUTORS.md)
- Mentioned in release notes
- Recognized in project documentation

---

## License

By contributing, you agree that your contributions will be licensed under the [GPL-3.0 License](LICENSE).

---

**Thank you for contributing! 🙏**

Every contribution, no matter how small, helps make this project better for everyone.

**Made with ❤️ by [sssilverhand](https://github.com/sssilverhand)**
