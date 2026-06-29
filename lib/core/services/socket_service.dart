import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:easy_split/core/constants/app_constants.dart';

/// Service managing real-time WebSocket connections via Socket.io.
class SocketService {
  io.Socket? _socket;
  String? _currentUserId;
  final Set<String> _joinedGroupIds = {};
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get realtimeEvents => _eventController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId) {
    _currentUserId = userId;

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      } else if (userId.isNotEmpty) {
        _socket!.emit('join_user', userId);
      }
      return;
    }

    // Extract root server URL (strip /api or /api/)
    String serverUrl = AppConstants.baseUrl;
    if (serverUrl.endsWith('/')) serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    if (serverUrl.endsWith('/api')) serverUrl = serverUrl.substring(0, serverUrl.length - 4);

    try {
      debugPrint('🔌 Initializing Socket.io connection to $serverUrl');
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('⚡ Socket connected successfully to $serverUrl (ID: ${_socket!.id})');
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          _socket!.emit('join_user', _currentUserId);
          debugPrint('👤 Re-joined user room: user_$_currentUserId');
        }

        // Auto re-join all tracked group rooms upon connection!
        for (final groupId in _joinedGroupIds) {
          _socket!.emit('join_group', groupId);
          debugPrint('👥 Re-joined group room: group_$groupId');
        }
      });

      _socket!.on('realtime_update', (data) {
        debugPrint('📩 Real-time update event received: $data');
        if (data is Map) {
          _eventController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('🔌 Socket disconnected from server');
      });

      _socket!.onError((err) {
        debugPrint('⚠️ Socket error encountered: $err');
      });
    } catch (e) {
      debugPrint('❌ Socket initialization error: $e');
    }
  }

  void joinGroup(String groupId) {
    if (groupId.isEmpty) return;
    _joinedGroupIds.add(groupId);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_group', groupId);
      debugPrint('👥 Emitted join_group for group_$groupId');
    }
  }

  void leaveGroup(String groupId) {
    if (groupId.isEmpty) return;
    _joinedGroupIds.remove(groupId);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_group', groupId);
      debugPrint('🚪 Emitted leave_group for group_$groupId');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _joinedGroupIds.clear();
    _currentUserId = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
