import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class SocketService {
  IO.Socket? _socket;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _orderController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get orderStream => _orderController.stream;
  ConnectionStatus get status => _status;

  void connect(String host, int port) {
    _updateStatus(ConnectionStatus.connecting);
    debugPrint('🔌 Connecting to $host:$port');

    _socket = IO.io(
      'http://$host:$port',
      IO.OptionBuilder()
          .setTransports(['websocket','polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    _socket!.onConnect((_) {
      debugPrint('✅ Connected to server');
      _updateStatus(ConnectionStatus.connected);
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ Disconnected from server');
      _updateStatus(ConnectionStatus.disconnected);
    });

    _socket!.onConnectError((error) {
      debugPrint('⚠️ Connection error: $error');
      _updateStatus(ConnectionStatus.error);
    });

    _socket!.onReconnect((_) {
      debugPrint('🔄 Reconnected to server');
      _updateStatus(ConnectionStatus.connected);
    });

    _socket!.on('order-update', (data) {
      debugPrint('📦 Order update received: $data');
      if (data is Map<String, dynamic>) {
        _orderController.add(data);
      }
    });
  }

  void _updateStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void disconnect() {
    debugPrint('🔌 Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _orderController.close();
  }
}
