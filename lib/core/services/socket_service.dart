import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:easy_split/core/constants/app_constants.dart';

/// Service managing real-time WebSocket connections via Socket.io.
class SocketService {
  io.Socket? _socket;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get realtimeEvents => _eventController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId) {
    if (_socket != null && _socket!.connected) return;

    // Extract root server URL (strip /api or /api/)
    String serverUrl = AppConstants.baseUrl;
    if (serverUrl.endsWith('/')) serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    if (serverUrl.endsWith('/api')) serverUrl = serverUrl.substring(0, serverUrl.length - 4);

    try {
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('⚡ Socket connected to $serverUrl');
        if (userId.isNotEmpty) {
          _socket!.emit('join_user', userId);
        }
      });

      _socket!.on('realtime_update', (data) {
        debugPrint('📩 Real-time update received: $data');
        if (data is Map) {
          _eventController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('🔌 Socket disconnected');
      });

      _socket!.onError((err) {
        debugPrint('⚠️ Socket error: $err');
      });
    } catch (e) {
      debugPrint('❌ Socket init error: $e');
    }
  }

  void joinGroup(String groupId) {
    if (groupId.isNotEmpty && _socket != null && _socket!.connected) {
      _socket!.emit('join_group', groupId);
    }
  }

  void leaveGroup(String groupId) {
    if (groupId.isNotEmpty && _socket != null && _socket!.connected) {
      _socket!.emit('leave_group', groupId);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
