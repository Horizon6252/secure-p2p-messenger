// ignore_for_file: constant_identifier_names

class Config {
  // VPS Server - Replace with your server IP and port
  // Example: "ws://192.168.1.100:9090" or "ws://your-domain.com:9090"
  static const String SERVER_URL = "ws://YOUR_SERVER_IP:9090";
  
  // Agora Settings (for voice/video calls)
  // Get your free App ID from https://console.agora.io/
  // Register, create a project, and copy your App ID here
  static const String AGORA_APP_ID = "YOUR_AGORA_APP_ID";
  
  // Connection settings
  static const Duration CONNECTION_TIMEOUT = Duration(seconds: 10);
  static const Duration RECONNECT_DELAY = Duration(seconds: 3);
  
  // Maximum file size for uploads (default 10MB)
  // Adjust based on your server capabilities and network
  static const int MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
}
