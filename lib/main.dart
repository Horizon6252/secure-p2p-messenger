// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, empty_catches, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings, unnecessary_non_null_assertion, duplicate_ignore, avoid_print

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'config.dart';

// Глобальный ключ для навигации
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    home: IdentityScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
  ));
}

// ============= CRYPTO =============
class CryptoEngine {
  static final aes = AesGcm.with256bits();

static Future<SecretKey> generateSharedKey(String myPriv, String theirPub) async {
  // Декодируем ключи из base64
  final myPrivateKey = SimpleKeyPairData(
    base64Decode(myPriv),
    publicKey: SimplePublicKey([], type: KeyPairType.x25519),
    type: KeyPairType.x25519,
  );
  
  final theirPublicKey = SimplePublicKey(
    base64Decode(theirPub),
    type: KeyPairType.x25519,
  );
  
  // Выполняем ECDH
  final algorithm = X25519();
  final sharedSecret = await algorithm.sharedSecretKey(
    keyPair: myPrivateKey,
    remotePublicKey: theirPublicKey,
  );
  
  // Используем KDF для генерации ключа шифрования
  final sharedBytes = await sharedSecret.extractBytes();
  final hash = await Sha256().hash(sharedBytes);
  
  return SecretKey(hash.bytes);
}

  static Future<String> encrypt(String text, SecretKey key) async {
    final box = await aes.encrypt(utf8.encode(text), secretKey: key);
    return base64Encode(box.concatenation());
  }

  static Future<String> decrypt(String cipher, SecretKey key) async {
    try {
      final box = SecretBox.fromConcatenation(base64Decode(cipher), nonceLength: 12, macLength: 16);
      final dec = await aes.decrypt(box, secretKey: key);
      return utf8.decode(dec);
    } catch (e) {
      return "[DECRYPT_ERROR]";
    }
  }

  static Future<List<int>> encryptBytes(List<int> data, SecretKey key) async {
    final box = await aes.encrypt(data, secretKey: key);
    return box.concatenation();
  }

  static Future<List<int>> decryptBytes(List<int> data, SecretKey key) async {
    try {
      final box = SecretBox.fromConcatenation(Uint8List.fromList(data), nonceLength: 12, macLength: 16);
      return await aes.decrypt(box, secretKey: key);
    } catch (e) {
      return [];
    }
  }
}

// ============= MODELS =============
class Contact {
  String name, publicId;
  bool isOnline;
  Contact({required this.name, required this.publicId, this.isOnline = false});
  
  Map<String, dynamic> toJson() => {'name': name, 'publicId': publicId, 'isOnline': isOnline};
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(name: j['name'], publicId: j['publicId'], isOnline: j['isOnline'] ?? false);
}

class Message {
  String type, content;
  bool isMine;
  DateTime timestamp;
  String? fileName;
  Message({required this.type, required this.content, required this.isMine, required this.timestamp, this.fileName});
  
  Map<String, dynamic> toJson() => {'type': type, 'content': content, 'isMine': isMine, 'timestamp': timestamp.toIso8601String(), 'fileName': fileName};
  factory Message.fromJson(Map<String, dynamic> j) => Message(type: j['type'], content: j['content'], isMine: j['isMine'], timestamp: DateTime.parse(j['timestamp']), fileName: j['fileName']);
}

// ============= STORAGE =============
class SecureStorage {
  static const storage = FlutterSecureStorage();

  static Future<void> saveContacts(List<Contact> contacts) async {
    await storage.write(key: 'contacts', value: jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  static Future<List<Contact>> loadContacts() async {
    final json = await storage.read(key: 'contacts');
    if (json == null) return [];
    return (jsonDecode(json) as List).map((c) => Contact.fromJson(c)).toList();
  }

  static Future<void> saveMessages(String contactId, List<Message> messages) async {
    await storage.write(key: 'messages_$contactId', value: jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  static Future<List<Message>> loadMessages(String contactId) async {
    final json = await storage.read(key: 'messages_$contactId');
    if (json == null) return [];
    return (jsonDecode(json) as List).map((m) => Message.fromJson(m)).toList();
  }

  static Future<void> clearAll() async => await storage.deleteAll();
}

// ============= RELAY SERVICE =============
class RelayService {
  static WebSocketChannel? _channel;
  static String? _myId;
  static final List<String> _onlineUsers = [];
  static Function(Map<String, dynamic>)? onMessage;
  static Function(List<String>)? onOnlineUpdate;
  static Function(String from, String channel, String callType)? onCallIncoming;
  static Function(String from)? onCallEnd;
  static bool _isConnected = false;

static Future<bool> connect(String myId) async {
  try {
    _myId = myId;
    _channel = WebSocketChannel.connect(Uri.parse(Config.SERVER_URL));
    await _channel!.ready.timeout(Config.CONNECTION_TIMEOUT);
    
    // Получаем сохраненный код доступа
    const storage = FlutterSecureStorage();
    final accessCode = await storage.read(key: 'access_code') ?? 'dummy';
    
    _channel!.sink.add(jsonEncode({'type': 'register', 'id': myId, 'code': accessCode}));

      _channel!.stream.listen((data) {
        try {
          final json = jsonDecode(data);
          
          if (json['type'] == 'registered') {
            _isConnected = true;
          } else if (json['type'] == 'online_list') {
            _onlineUsers.clear();
            _onlineUsers.addAll((json['users'] as List).cast<String>());
            onOnlineUpdate?.call(_onlineUsers);
          } else if (json['type'] == 'message') {
            onMessage?.call(json);
          } else if (json['type'] == 'call_offer') {
            onCallIncoming?.call(json['from'], json['channel'], json['callType']);
          } else if (json['type'] == 'call_end') {
            onCallEnd?.call(json['from']);
          }
        } catch (e) {
          // Error handled
        }
      }, onDone: () => _isConnected = false, onError: (_) => _isConnected = false);

      return true;
    } catch (e) {
      return false;
    }
  }

  static void sendMessage(String toId, Map<String, dynamic> data) {
    if (!_isConnected) return;
    _channel?.sink.add(jsonEncode({'type': 'message', 'from': _myId, 'to': toId, 'data': data}));
  }

  static void sendCallOffer(String toId, String channel, String callType) {
    _channel?.sink.add(jsonEncode({'type': 'call_offer', 'from': _myId, 'to': toId, 'channel': channel, 'callType': callType}));
  }

  static void sendCallEnd(String toId) {
    _channel?.sink.add(jsonEncode({'type': 'call_end', 'from': _myId, 'to': toId}));
  }

static bool isOnline(String userId) => _onlineUsers.contains(userId);
  static void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}

// ============= GLOBAL MESSAGE HANDLER =============
class GlobalMessageHandler {
  static String? _myPrivKey;
  static String? _myId;
  static List<Contact> _contacts = [];
  static bool _isInitialized = false;

  static Future<void> initialize(String myId, String myPrivKey) async {
    if (_isInitialized) return;
    
    _myId = myId;
    _myPrivKey = myPrivKey;
    _contacts = await SecureStorage.loadContacts();
    
    // Устанавливаем глобальный обработчик сообщений
    RelayService.onMessage = _handleIncomingMessage;
    
    // Устанавливаем глобальный обработчик звонков
    RelayService.onCallIncoming = _handleIncomingCall;
    RelayService.onCallEnd = _handleCallEnd;
    
    _isInitialized = true;
    print('✅ Global handlers initialized');
  }

  static Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    try {
      final fromId = data['from'];
      final payload = data['data'];
      
      // Находим контакт отправителя
      Contact? sender;
      for (var contact in _contacts) {
        if (contact.publicId == fromId) {
          sender = contact;
          break;
        }
      }
      
      if (sender == null) {
        final fromShort = fromId.length > 8 ? fromId.substring(0, 8) : fromId;
        print('⚠️  Message from unknown contact: $fromShort...');
        return;
      }
      
      // Генерируем ключ расшифровки
      final key = await CryptoEngine.generateSharedKey(_myPrivKey!, sender.publicId);
      
      // Загружаем существующие сообщения
      final messages = await SecureStorage.loadMessages(sender.publicId);
      
      // Обрабатываем разные типы сообщений
      Message? newMessage;
      
      if (payload['type'] == 'text') {
        final decrypted = await CryptoEngine.decrypt(payload['body'], key);
        newMessage = Message(
          type: 'text',
          content: decrypted,
          isMine: false,
          timestamp: DateTime.now(),
        );
        final preview = decrypted.length > 20 ? decrypted.substring(0, 20) : decrypted;
        print('📨 Text message from ${sender.name}: $preview...');
      } 
      else if (payload['type'] == 'voice') {
        final decBytes = await CryptoEngine.decryptBytes(base64Decode(payload['body']), key);
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac");
        await file.writeAsBytes(decBytes);
        newMessage = Message(
          type: 'voice',
          content: file.path,
          isMine: false,
          timestamp: DateTime.now(),
        );
        print('🎤 Voice message from ${sender.name}');
      } 
      else if (payload['type'] == 'video_msg') {
        final decBytes = await CryptoEngine.decryptBytes(base64Decode(payload['body']), key);
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4");
        await file.writeAsBytes(decBytes);
        newMessage = Message(
          type: 'video_msg',
          content: file.path,
          isMine: false,
          timestamp: DateTime.now(),
        );
        print('🎥 Video message from ${sender.name}');
      } 
      else if (payload['type'] == 'file') {
        final decBytes = await CryptoEngine.decryptBytes(base64Decode(payload['body']), key);
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/${payload['name']}");
        await file.writeAsBytes(decBytes);
        newMessage = Message(
          type: 'file',
          content: file.path,
          isMine: false,
          timestamp: DateTime.now(),
          fileName: payload['name'],
        );
        print('📎 File from ${sender.name}: ${payload['name']}');
      }
      
      if (newMessage != null) {
        messages.add(newMessage);
        await SecureStorage.saveMessages(sender.publicId, messages);
        
        // Показываем уведомление
        _showInAppNotification(sender.name, _getNotificationText(newMessage));
      }
    } catch (e) {
      print('❌ Error handling message: $e');
    }
  }

  static String _getNotificationText(Message msg) {
    switch (msg.type) {
      case 'text':
        return msg.content.length > 30 ? msg.content.substring(0, 30) + '...' : msg.content;
      case 'voice':
        return '🎤 Voice message';
      case 'video_msg':
        return '🎥 Video message';
      case 'file':
        return '📎 ${msg.fileName ?? 'File'}';
      default:
        return 'New message';
    }
  }

  static void _showInAppNotification(String from, String text) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // Создаем SnackBar уведомление
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.message, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(from, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text(text, style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.cyanAccent.withOpacity(0.9),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static Future<void> _handleIncomingCall(String from, String channel, String callType) async {
    final fromShort = from.length > 8 ? from.substring(0, 8) : from;
    print('📞 Incoming $callType call from: $fromShort...');
    
    // Находим контакт
    Contact? caller;
    for (var contact in _contacts) {
      if (contact.publicId == from) {
        caller = contact;
        break;
      }
    }
    
    if (caller == null) {
      print('⚠️  Call from unknown contact');
      return;
    }
    
    // Показываем диалог звонка
    _showIncomingCallDialog(caller, channel, callType);
  }

  static void _showIncomingCallDialog(Contact caller, String channel, String callType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          "📞 Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call",
          style: TextStyle(color: Colors.green),
        ),
        content: Text(
          "${caller.name} is calling...",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              RelayService.sendCallEnd(caller.publicId);
            },
            child: Text("Decline", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(c);
              // Открываем чат с контактом и передаём параметры входящего звонка
              if (_myId != null && _myPrivKey != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      myId: _myId!,
                      myPriv: _myPrivKey!,
                      contact: caller,
                      incomingCallChannel: channel,
                      incomingCallType: callType,
                    ),
                  ),
                );
              }
              print('✅ Call accepted - opened chat with ${caller.name}');
            },
            child: Text("Accept"),
          ),
        ],
      ),
    );
  }

  static void _handleCallEnd(String from) {
    final fromShort = from.length > 8 ? from.substring(0, 8) : from;
    print('🔴 Call ended from: $fromShort...');
  }

  static void updateContacts(List<Contact> contacts) {
    _contacts = contacts;
  }
}

// ============= ACCESS CODE SCREEN =============
class AccessCodeScreen extends StatefulWidget {
  const AccessCodeScreen({super.key});
  @override
  State<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends State<AccessCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _checking = false;
  String? _error;

  Future<void> _checkAccessCode() async {
    if (_codeCtrl.text.isEmpty) {
      setState(() => _error = "Enter access code");
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final channel = WebSocketChannel.connect(Uri.parse(Config.SERVER_URL));
      await channel.ready.timeout(Duration(seconds: 5));

      channel.sink.add(jsonEncode({
        'type': 'check_code',
        'code': _codeCtrl.text.trim().toUpperCase(),
      }));

      final response = await channel.stream.first.timeout(Duration(seconds: 5));
      final data = jsonDecode(response);

      if (data['valid'] == true) {
        await _generateKeysFromCode(_codeCtrl.text.trim().toUpperCase());
      } else {
        setState(() {
          _error = "Invalid access code";
          _checking = false;
        });
      }

      channel.sink.close();
    } catch (e) {
      setState(() {
        _error = "Cannot connect to server";
        _checking = false;
      });
    }
  }

  Future<void> _generateKeysFromCode(String code) async {
    final storage = FlutterSecureStorage();
    
    final codeHash = await Sha256().hash(utf8.encode(code));
    final seed = Uint8List.fromList(codeHash.bytes);
    final privBytes = seed.sublist(0, 32);
    
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPairFromSeed(privBytes);
    
    final pub = base64Encode((await keyPair.extractPublicKey()).bytes);
    final priv = base64Encode(await keyPair.extractPrivateKeyBytes());
    
    await storage.write(key: 'public_key', value: pub);
    await storage.write(key: 'private_key', value: priv);
    await storage.write(key: 'access_code', value: code);
    
    try {
      final channel = WebSocketChannel.connect(Uri.parse(Config.SERVER_URL));
      await channel.ready.timeout(Duration(seconds: 5));

      channel.sink.add(jsonEncode({
        'type': 'register',
        'id': pub,
        'code': code,
      }));

      final response = await channel.stream.first.timeout(Duration(seconds: 5));
      final data = jsonDecode(response);

      if (data['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => IdentityScreen()),
        );
      } else {
        setState(() {
          _error = "Server error";
          _checking = false;
        });
      }

      channel.sink.close();
    } catch (e) {
      setState(() {
        _error = "Connection failed";
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 100, color: Colors.cyanAccent),
                SizedBox(height: 40),
                Text(
                  "PRIVATE MESSENGER",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Multi-device accounts",
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                SizedBox(height: 60),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "ENTER ACCESS CODE",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _codeCtrl,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "SECURE-XXXX-XXXX-XXXX-XXXX",
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.cyanAccent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_checking,
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 15),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                      SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _checking ? null : _checkAccessCode,
                          child: _checking
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.black),
                                  ),
                                )
                              : Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.cyanAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "Multi-device login",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Use the same code on all your devices (PC, phone, tablet) to access your account",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Get your access code from the administrator",
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============= IDENTITY SCREEN =============
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});
  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  final storage = const FlutterSecureStorage();
  String _myId = "", _myPriv = "";
  bool _loading = true, _connected = false;

  @override
  void initState() {
    super.initState();
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    String? pub = await storage.read(key: 'public_key');
    String? priv = await storage.read(key: 'private_key');
    
    if (pub == null || priv == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => AccessCodeScreen()),
      );
      return;
    }
    
    setState(() {
      _myId = pub!;
      _myPriv = priv!;
      _loading = false;
    });
    _connectToServer();
  }

Future<void> _connectToServer() async {
  final success = await RelayService.connect(_myId);
  setState(() => _connected = success);
  
  if (success) {
    // Инициализируем глобальные обработчики
    await GlobalMessageHandler.initialize(_myId, _myPriv);
    print('✅ Connected and handlers ready');
  } else {
    _showConnectionError();
  }
}

  void _showConnectionError() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("⚠️ Connection Failed", style: TextStyle(color: Colors.orange)),
        content: Text("Cannot connect:\n${Config.SERVER_URL}\n\nCheck server & internet", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(c); _connectToServer(); }, child: Text("Retry")),
          ElevatedButton(onPressed: () => Navigator.pop(c), child: Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 100, color: Colors.cyanAccent),
                SizedBox(height: 30),
                Text("SECURE E2EE MESSENGER", style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_connected ? Icons.circle : Icons.circle_outlined, color: _connected ? Colors.green : Colors.red, size: 12),
                    SizedBox(width: 8),
                    Text(_connected ? "Connected" : "Disconnected", style: TextStyle(color: _connected ? Colors.green : Colors.red, fontSize: 12)),
                  ],
                ),
                SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.vpn_key, color: Colors.cyanAccent, size: 16),
                          SizedBox(width: 8),
                          Text("YOUR PUBLIC ID:", style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 10),
                      SelectableText(_myId, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'monospace')),
                      SizedBox(height: 15),
                      Text("Share this ID with contacts", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                  icon: Icon(Icons.people),
                  label: Text("OPEN CONTACTS"),
                  onPressed: _connected ? () => Navigator.push(context, MaterialPageRoute(builder: (c) => ContactsScreen(myId: _myId, myPriv: _myPriv))) : null,
                ),
                SizedBox(height: 20),
                if (!_connected) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), icon: Icon(Icons.refresh), label: Text("RECONNECT"), onPressed: _connectToServer),
                SizedBox(height: 20),
                TextButton.icon(icon: Icon(Icons.delete_forever, color: Colors.red), label: Text("EMERGENCY WIPE", style: TextStyle(color: Colors.red)), onPressed: _showWipeDialog),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWipeDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("⚠️ Wipe All Data?", style: TextStyle(color: Colors.red)),
        content: Text("This will DELETE:\n• Identity\n• Contacts\n• Messages\n• Files\n\nIRREVERSIBLE!", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(c);
              await SecureStorage.clearAll();
              RelayService.disconnect();
              setState(() => _loading = true);
              await _initIdentity();
            },
            child: Text("WIPE NOW"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    RelayService.disconnect();
    super.dispose();
  }
}

// ============= CONTACTS =============
class ContactsScreen extends StatefulWidget {
  final String myId, myPriv;
  const ContactsScreen({super.key, required this.myId, required this.myPriv});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    RelayService.onOnlineUpdate = (users) {
      setState(() {
        for (var contact in _contacts) contact.isOnline = users.contains(contact.publicId);
      });
    };
  }

Future<void> _loadContacts() async {
  final contacts = await SecureStorage.loadContacts();
  setState(() => _contacts = contacts);
  // Обновляем контакты в глобальном обработчике
  GlobalMessageHandler.updateContacts(contacts);
}

  void _addContact() {
    final nameCtrl = TextEditingController(), idCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Add Contact", style: TextStyle(color: Colors.cyanAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.person, color: Colors.cyanAccent))),
            SizedBox(height: 15),
            TextField(controller: idCtrl, style: TextStyle(color: Colors.white, fontSize: 10), decoration: InputDecoration(labelText: "Public ID", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.key, color: Colors.cyanAccent)), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () async {
              _contacts.add(Contact(name: nameCtrl.text.trim(), publicId: idCtrl.text.trim()));
              await SecureStorage.saveContacts(_contacts);
              setState(() {});
              Navigator.pop(c);
            },
            child: Text("Add", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("CONTACTS"), backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, actions: [IconButton(icon: Icon(Icons.person_add), onPressed: _addContact)]),
      body: _contacts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 80, color: Colors.white24), SizedBox(height: 20), Text("No contacts", style: TextStyle(color: Colors.white38)), SizedBox(height: 10), Text("Tap + to add", style: TextStyle(color: Colors.white24))]))
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (c, i) => Dismissible(
                key: Key(_contacts[i].publicId),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                onDismissed: (_) async {
                  _contacts.removeAt(i);
                  await SecureStorage.saveContacts(_contacts);
                },
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.cyanAccent, child: Text(_contacts[i].name[0].toUpperCase(), style: TextStyle(color: Colors.black))),
                  title: Text(_contacts[i].name, style: TextStyle(color: Colors.white)),
                  subtitle: Text(_contacts[i].publicId.substring(0, 20) + "...", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  trailing: Icon(Icons.circle, color: _contacts[i].isOnline ? Colors.green : Colors.grey, size: 12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(myId: widget.myId, myPriv: widget.myPriv, contact: _contacts[i]))),
                ),
              ),
            ),
    );
  }
}

// ============= CHAT =============
class ChatScreen extends StatefulWidget {
  final String myId, myPriv;
  final Contact contact;
  final String? incomingCallChannel;
  final String? incomingCallType;
  const ChatScreen({
    super.key, 
    required this.myId, 
    required this.myPriv, 
    required this.contact,
    this.incomingCallChannel,
    this.incomingCallType,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> _messages = [];
  final _msgCtrl = TextEditingController();
  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isPlayerInitialized = false;
  bool _isRecorderInitialized = false;
  
  // Agora
  RtcEngine? _agoraEngine;
  bool _inCall = false;
  String _callType = 'audio';
  // ignore: unused_field
  String? _currentChannel;

@override
void initState() {
  super.initState();
  _loadMessages();
  // _setupMessageListener(); ← УБРАЛИ!
  // _setupCallListeners(); ← УБРАЛИ!
  _setupOnlineStatusListener();
  _initAudio();
  _initAgora();
  
  // Проверяем входящий звонок
  if (widget.incomingCallChannel != null && widget.incomingCallType != null) {
    // Показываем диалог входящего звонка после инициализации
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _showIncomingCallDialogAuto(widget.incomingCallChannel!, widget.incomingCallType!);
      }
    });
  }
  
  // Периодически обновляем сообщения из storage
  Timer.periodic(Duration(seconds: 1), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    _loadMessages();
  });
}

// ← НОВЫЙ МЕТОД
void _setupOnlineStatusListener() {
  RelayService.onOnlineUpdate = (users) {
    if (mounted) {
      setState(() {
        // Обновляем UI
      });
    }
  };
}

  Future<void> _initAudio() async {
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();
    
    await _audioRecorder!.openRecorder();
    await _audioPlayer!.openPlayer();
    
    setState(() {
      _isRecorderInitialized = true;
      _isPlayerInitialized = true;
    });
  }

  Future<void> _initAgora() async {
    _agoraEngine = createAgoraRtcEngine();
    await _agoraEngine!.initialize(RtcEngineContext(
      appId: Config.AGORA_APP_ID,
    ));

    await _agoraEngine!.enableAudio();
    await _agoraEngine!.enableVideo();

    // Настройка аудио профиля
await _agoraEngine!.setAudioProfile(
  profile: AudioProfileType.audioProfileDefault,
  scenario: AudioScenarioType.audioScenarioGameStreaming,
);

    _agoraEngine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Joined channel: ${connection.channelId}");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user joined: $remoteUid");
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print("Remote user offline: $remoteUid");
        },
      ),
    );
  }

  Future<void> _loadMessages() async {
    final messages = await SecureStorage.loadMessages(widget.contact.publicId);
    setState(() => _messages = messages);
  }

  Future<void> _saveMessages() async {
    await SecureStorage.saveMessages(widget.contact.publicId, _messages);
  }


  String _generateChannelName() {
    final ids = [widget.myId, widget.contact.publicId]..sort();
    final combined = ids.join('_');
    return combined.substring(0, 32);
  }

  void _showIncomingCallDialogAuto(String channel, String callType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("📞 Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call", style: TextStyle(color: Colors.green)),
        content: Text("${widget.contact.name} is calling...", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              RelayService.sendCallEnd(widget.contact.publicId);
            },
            child: Text("Decline", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(c);
              _answerCall(channel, callType);
            },
            child: Text("Accept"),
          ),
        ],
      ),
    );
  }

  Future<void> _startCall(String callType) async {
    if (await Permission.microphone.request().isGranted &&
        (callType == 'audio' || await Permission.camera.request().isGranted)) {
      
      final channel = _generateChannelName();
      
      setState(() {
        _inCall = true;
        _callType = callType;
        _currentChannel = channel;
      });

      if (callType == 'video') {
        await _agoraEngine!.enableVideo();
      } else {
        await _agoraEngine!.disableVideo();
      }

      await _agoraEngine!.joinChannel(
  token: '',
  channelId: channel,
  uid: 0,
  options: ChannelMediaOptions(
    channelProfile: ChannelProfileType.channelProfileCommunication,
    clientRoleType: ClientRoleType.clientRoleBroadcaster,
    publishMicrophoneTrack: true,
    publishCameraTrack: callType == 'video',
    autoSubscribeAudio: true,
    autoSubscribeVideo: callType == 'video',
  ),
);

      RelayService.sendCallOffer(widget.contact.publicId, channel, callType);
    }
  }

  Future<void> _answerCall(String channel, String callType) async {
    if (await Permission.microphone.request().isGranted &&
        (callType == 'audio' || await Permission.camera.request().isGranted)) {
      
      setState(() {
        _inCall = true;
        _callType = callType;
        _currentChannel = channel;
      });

      if (callType == 'video') {
        await _agoraEngine!.enableVideo();
      } else {
        await _agoraEngine!.disableVideo();
      }

      await _agoraEngine!.joinChannel(
        token: '',
        channelId: channel,
        uid: 0,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: callType == 'video',
          autoSubscribeAudio: true,
          autoSubscribeVideo: callType == 'video',
        ),
      );
    }
  }

  void _endCall() async {
    await _agoraEngine?.leaveChannel();
    await _agoraEngine?.disableVideo();
    RelayService.sendCallEnd(widget.contact.publicId);
    setState(() {
      _inCall = false;
      _currentChannel = null;
    });
  }

  void _sendText() async {
    if (_msgCtrl.text.isEmpty) return;
    final key = await CryptoEngine.generateSharedKey(widget.myPriv, widget.contact.publicId);
    final encrypted = await CryptoEngine.encrypt(_msgCtrl.text, key);
    RelayService.sendMessage(widget.contact.publicId, {'type': 'text', 'body': encrypted});
    setState(() => _messages.add(Message(type: 'text', content: _msgCtrl.text, isMine: true, timestamp: DateTime.now())));
    await _saveMessages();
    _msgCtrl.clear();
  }

  void _sendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    if (bytes.length > Config.MAX_FILE_SIZE) {
      final sizeMB = Config.MAX_FILE_SIZE ~/ (1024 * 1024);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File too large (max ${sizeMB}MB)")));
      return;
    }
    final key = await CryptoEngine.generateSharedKey(widget.myPriv, widget.contact.publicId);
    final encrypted = await CryptoEngine.encryptBytes(bytes, key);
    RelayService.sendMessage(widget.contact.publicId, {'type': 'file', 'name': result.files.single.name, 'body': base64Encode(encrypted)});
    setState(() => _messages.add(Message(type: 'file', content: file.path, isMine: true, timestamp: DateTime.now(), fileName: result.files.single.name)));
    await _saveMessages();
  }

  void _toggleVoiceRecording() async {
    if (!_isRecorderInitialized) return;
    
    if (await Permission.microphone.request().isGranted) {
      if (_isRecording) {
        final path = await _audioRecorder!.stopRecorder();
        if (path != null) {
          final bytes = await File(path).readAsBytes();
          
          final key = await CryptoEngine.generateSharedKey(widget.myPriv, widget.contact.publicId);
          final encrypted = await CryptoEngine.encryptBytes(bytes, key);

          RelayService.sendMessage(widget.contact.publicId, {
            'type': 'voice',
            'body': base64Encode(encrypted),
          });

          setState(() => _messages.add(Message(
            type: 'voice',
            content: path,
            isMine: true,
            timestamp: DateTime.now(),
          )));
          await _saveMessages();
        }
        setState(() => _isRecording = false);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac";
        
        await _audioRecorder!.startRecorder(
          toFile: path,
          codec: Codec.aacADTS,
        );
        setState(() => _isRecording = true);
      }
    }
  }

  void _recordVideoMessage() async {
    if (await Permission.camera.request().isGranted && await Permission.microphone.request().isGranted) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => VideoRecorderScreen(onVideoRecorded: _sendVideoMessage)));
    }
  }

  void _sendVideoMessage(String videoPath) async {
    final bytes = await File(videoPath).readAsBytes();
    if (bytes.length > Config.MAX_FILE_SIZE) {
      final sizeMB = Config.MAX_FILE_SIZE ~/ (1024 * 1024);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video too large (max ${sizeMB}MB)")));
      return;
    }
    final key = await CryptoEngine.generateSharedKey(widget.myPriv, widget.contact.publicId);
    final encrypted = await CryptoEngine.encryptBytes(bytes, key);
    RelayService.sendMessage(widget.contact.publicId, {'type': 'video_msg', 'body': base64Encode(encrypted)});
    setState(() => _messages.add(Message(type: 'video_msg', content: videoPath, isMine: true, timestamp: DateTime.now())));
    await _saveMessages();
  }

  void _playVoice(String path) async {
    if (!_isPlayerInitialized) return;
    await _audioPlayer!.startPlayer(fromURI: path);
  }

  @override
  Widget build(BuildContext context) {
    if (_inCall) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_callType == 'video' ? Icons.videocam : Icons.call, size: 100, color: Colors.green),
              SizedBox(height: 30),
              Text("${_callType == 'video' ? 'Video' : 'Voice'} Call", style: TextStyle(color: Colors.white, fontSize: 24)),
              SizedBox(height: 10),
              Text(widget.contact.name, style: TextStyle(color: Colors.white70, fontSize: 18)),
              SizedBox(height: 50),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                icon: Icon(Icons.call_end),
                label: Text("End Call"),
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF050505),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name),
            Text(RelayService.isOnline(widget.contact.publicId) ? "🟢 Online" : "🔴 Offline", style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.call), onPressed: () => _startCall('audio')),
          IconButton(icon: Icon(Icons.videocam), onPressed: () => _startCall('video')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (c, i) {
                final idx = _messages.length - 1 - i;
                return _buildMessage(_messages[idx]);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.white10,
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.attach_file, color: Colors.cyanAccent), onPressed: _sendFile),
                IconButton(icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.red : Colors.cyanAccent), onPressed: _toggleVoiceRecording),
                IconButton(icon: Icon(Icons.videocam, color: Colors.cyanAccent), onPressed: _recordVideoMessage),
                Expanded(child: TextField(controller: _msgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Message...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none))),
                IconButton(icon: Icon(Icons.send, color: Colors.cyanAccent), onPressed: _sendText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Message msg) {
    final isMe = msg.isMine;
    Widget content;
    
    if (msg.type == 'text') {
      content = Text(msg.content, style: TextStyle(color: Colors.white));
    } else if (msg.type == 'voice') {
      content = GestureDetector(
        onTap: () => _playVoice(msg.content),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_arrow, color: Colors.cyanAccent, size: 20), SizedBox(width: 5), Text("Voice", style: TextStyle(color: Colors.white70))]),
      );
    } else if (msg.type == 'video_msg') {
      content = GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => VideoPlayerScreen(videoPath: msg.content))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle, color: Colors.cyanAccent, size: 20), SizedBox(width: 5), Text("Video", style: TextStyle(color: Colors.white70))]),
      );
    } else if (msg.type == 'file') {
      content = Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.insert_drive_file, color: Colors.cyanAccent, size: 20), SizedBox(width: 5), Flexible(child: Text(msg.fileName ?? "File", style: TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis))]);
    } else {
      content = Text(msg.type, style: TextStyle(color: Colors.white38));
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            SizedBox(height: 5),
            Text("${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}", style: TextStyle(color: Colors.white24, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _endCall();
    _agoraEngine?.release();
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    super.dispose();
  }
}

// ============= VIDEO RECORDER =============
class VideoRecorderScreen extends StatefulWidget {
  final Function(String) onVideoRecorded;
  const VideoRecorderScreen({super.key, required this.onVideoRecorded});
  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _controller = CameraController(
    frontCamera, 
    ResolutionPreset.medium,
    enableAudio: true,
    );
    await _controller!.initialize();
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = video.path;
      });
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    if (_videoPath != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: Colors.green),
              SizedBox(height: 30),
              Text("Video recorded!", style: TextStyle(color: Colors.white, fontSize: 20)),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      widget.onVideoRecorded(_videoPath!);
                      Navigator.pop(context);
                    },
                    child: Text("Send"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipOval(child: CameraPreview(_controller!)),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _isRecording ? Icon(Icons.stop, size: 40, color: Colors.white) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ============= VIDEO PLAYER =============
class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const VideoPlayerScreen({super.key, required this.videoPath});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))..initialize().then((_) => setState(() {}));
    _controller.play();
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
            : CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}