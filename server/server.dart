import 'dart:io';
import 'dart:convert';
import 'dart:async';

// Access codes for authentication
// IMPORTANT: Generate your own secure random codes!
// Format: SECURE-XXXX-XXXX-XXXX-XXXX (20 random alphanumeric characters)
// 
// How to generate:
// - Linux/macOS: Use /dev/urandom
// - Online: https://www.random.org/strings/
// - Or write your own generator
//
// SECURITY: Never use these example codes in production!
final Set<String> accessCodes = {
  'SECURE-A1B2-C3D4-E5F6-G7H8',
  'SECURE-I9J0-K1L2-M3N4-O5P6',
  'SECURE-Q7R8-S9T0-U1V2-W3X4',
  // Add more codes as needed for your users
};

// Message storage structure for offline delivery
class PendingMessage {
  final String from;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  PendingMessage(this.from, this.data, this.timestamp);
  
  Map<String, dynamic> toJson() => {
    'type': 'message',
    'from': from,
    'data': data,
  };
}

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 9090);
  print('✅ Relay Server v6.0 started on ${server.address.address}:${server.port}');
  print('🔐 Authorization: Multi-device accounts enabled');
  print('📊 Features: Messages, Files, Voice Messages, Agora Calls');
  print('🔒 E2EE: All content encrypted client-side');
  print('📬 Offline delivery: Enabled (24h storage)');
  print('\n📋 Active access codes: ${accessCodes.length}');
  accessCodes.forEach((code) => print('  $code → ACTIVE'));
  print('');

  final Map<String, WebSocket> clients = {};
  final Map<String, List<PendingMessage>> pendingMessages = {};
  
  // Periodic cleanup of old messages (every hour)
  Timer.periodic(Duration(hours: 1), (timer) {
    final now = DateTime.now();
    int cleaned = 0;
    
    pendingMessages.forEach((userId, messages) {
      messages.removeWhere((msg) {
        final age = now.difference(msg.timestamp);
        return age.inHours > 24; // Remove messages older than 24 hours
      });
      cleaned += messages.length;
    });
    
    // Remove empty queues
    pendingMessages.removeWhere((userId, messages) => messages.isEmpty);
    
    if (cleaned > 0) {
      print('🧹 Cleaned old messages. Pending: $cleaned messages for ${pendingMessages.length} users');
    }
  });

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket ws = await WebSocketTransformer.upgrade(request);
      String? clientId;

      ws.listen(
        (message) {
          try {
            final data = jsonDecode(message);

            if (data['type'] == 'check_code') {
              final code = data['code'] as String;
              final valid = accessCodes.contains(code);
              ws.add(jsonEncode({'valid': valid}));
              print('🔍 Code check: ${_maskCode(code)} → ${valid ? 'VALID' : 'INVALID'}');
            }

            else if (data['type'] == 'register') {
              final code = data['code'] as String;
              clientId = data['id'];

              if (accessCodes.contains(code)) {
                clients[clientId!] = ws;
                print('➕ Client connected: ${_shortId(clientId!)} | Code: ${_maskCode(code)} | Total: ${clients.length}');
                
                ws.add(jsonEncode({'type': 'registered', 'id': clientId, 'success': true}));
                _broadcastOnlineList(clients);
                
                // Send pending messages
                if (pendingMessages.containsKey(clientId)) {
                  final pending = pendingMessages[clientId!]!;
                  print('📬 Delivering ${pending.length} pending messages to ${_shortId(clientId!)}');
                  
                  for (var msg in pending) {
                    try {
                      ws.add(jsonEncode(msg.toJson()));
                      print('   ✅ Delivered: from ${_shortId(msg.from)} (${_formatAge(msg.timestamp)})');
                    } catch (e) {
                      print('   ❌ Failed to deliver message from ${_shortId(msg.from)}');
                    }
                  }
                  
                  // Clear queue after delivery
                  pendingMessages.remove(clientId);
                }
              } else {
                ws.add(jsonEncode({'type': 'register_failed', 'error': 'Invalid access code'}));
                print('❌ Connection rejected: Invalid code ${_maskCode(code)}');
              }
            }
            
            else if (data['type'] == 'message') {
              final fromId = data['from'];
              final targetId = data['to'];
              final targetWs = clients[targetId];

              final messageData = {
                'type': 'message',
                'from': fromId,
                'data': data['data'],
              };

              if (targetWs != null) {
                // Recipient is online - deliver immediately
                targetWs.add(jsonEncode(messageData));
                print('📨 Message: ${_shortId(fromId)} → ${_shortId(targetId)}');
                print('   ✅ Delivered to ${_shortId(targetId)} (online)');
              } else {
                // Recipient is offline - queue for delivery
                if (!pendingMessages.containsKey(targetId)) {
                  pendingMessages[targetId] = [];
                }
                
                pendingMessages[targetId]!.add(
                  PendingMessage(fromId, data['data'], DateTime.now())
                );
                
                print('📨 Message: ${_shortId(fromId)} → ${_shortId(targetId)}');
                print('   📬 Queued for offline delivery (${pendingMessages[targetId]!.length} pending)');
              }
            }
            
            else if (data['type'] == 'call_offer') {
              final targetId = data['to'];
              final targetWs = clients[targetId];

              if (targetWs != null) {
                targetWs.add(jsonEncode({
                  'type': 'call_offer',
                  'from': data['from'],
                  'channel': data['channel'],
                  'callType': data['callType'],
                }));
                print('📞 Call offer: ${_shortId(data['from'])} → ${_shortId(targetId)} (${data['callType']}) [Channel: ${data['channel']}]');
              } else {
                print('📞 Call offer: ${_shortId(data['from'])} → ${_shortId(targetId)} (offline - call not delivered)');
              }
            }
            
            else if (data['type'] == 'call_end') {
              final targetId = data['to'];
              final targetWs = clients[targetId];

              if (targetWs != null) {
                targetWs.add(jsonEncode({
                  'type': 'call_end',
                  'from': data['from'],
                }));
                print('🔴 Call ended: ${_shortId(data['from'])} ↔ ${_shortId(targetId)}');
              }
            }
          } catch (e) {
            print('⚠️  Error: $e');
          }
        },
        onDone: () {
          if (clientId != null) {
            clients.remove(clientId);
            print('➖ Client disconnected: ${_shortId(clientId!)} | Total: ${clients.length}');
            
            // Show pending messages count
            if (pendingMessages.containsKey(clientId)) {
              print('   📬 ${pendingMessages[clientId]!.length} messages pending for next connection');
            }
            
            _broadcastOnlineList(clients);
          }
        },
        onError: (e) {
          if (clientId != null) {
            clients.remove(clientId);
          }
        },
      );
    }
  }
}

void _broadcastOnlineList(Map<String, WebSocket> clients) {
  final onlineIds = clients.keys.toList();
  final message = jsonEncode({
    'type': 'online_list',
    'users': onlineIds,
  });

  print('📡 Broadcasting online list: ${onlineIds.length} users');
  for (var id in onlineIds) {
    print('   - ${_shortId(id)}');
  }

  for (var ws in clients.values) {
    try {
      ws.add(message);
    } catch (e) {
      // Error handled
    }
  }
}

String _shortId(String id) => id.length > 8 ? id.substring(0, 8) + '...' : id;
String _maskCode(String code) => code.length > 10 ? '${code.substring(0, 7)}...${code.substring(code.length - 4)}' : code;

String _formatAge(DateTime timestamp) {
  final age = DateTime.now().difference(timestamp);
  if (age.inMinutes < 1) return 'just now';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}
