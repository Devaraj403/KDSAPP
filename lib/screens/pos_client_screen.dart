
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../service/connection_service.dart';
import '../service/mdns_service.dart';
import '../service/socket_service.dart';

class PosClientScreen extends StatefulWidget {
  const PosClientScreen({super.key});

  @override
  State<PosClientScreen> createState() => _PosClientScreenState();
}

class _PosClientScreenState extends State<PosClientScreen> {
  final SocketService _socketService = SocketService();
  late final ConnectionService _connectionService;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '3000');

  String _statusMessage = 'Initializing...';
  ServerInfo? _serverInfo;
  final List<OrderUpdate> _orders = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _connectionService = ConnectionService(_socketService);
    _listenToSocket();
    _autoConnect(); // Auto-connect on startup
  }

  Future<void> _autoConnect() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = '🔄 Auto-connecting...';
      _orders.clear();
    });

    final serverInfo = await _connectionService.autoConnect();

    if (serverInfo != null) {
      setState(() {
        _serverInfo = serverInfo;
        _statusMessage = '📡 Connecting to ${serverInfo.host}:${serverInfo.port}';
      });
    } else {
      setState(() {
        _statusMessage = '❌ Auto-connect failed. Use manual connection.';
        _isConnecting = false;
      });
    }
  }

  void _connectManually() {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();

    if (ip.isEmpty) {
      _showError('Please enter IP address');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      _showError('Please enter valid port (1-65535)');
      return;
    }

    setState(() {
      _serverInfo = ServerInfo(host: ip, port: port);
      _statusMessage = '🔌 Connecting to $ip:$port';
      _orders.clear();
    });

    _socketService.connect(ip, port);
    Navigator.of(context).pop();
  }

  void _showManualConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '3000',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Connection Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Find your computer IP with ipconfig (Windows) or ifconfig (Mac/Linux)', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 2),
                  Text('• Both devices must be on same WiFi', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _connectManually,
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _listenToSocket() {
    _socketService.statusStream.listen((status) {
      setState(() {
        switch (status) {
          case ConnectionStatus.connecting:
            _statusMessage = '🔌 Connecting to server...';
            break;
          case ConnectionStatus.connected:
            _statusMessage = '✅ Connected to POS server';
            _isConnecting = false;
            break;
          case ConnectionStatus.disconnected:
            _statusMessage = '⚠️ Disconnected from server';
            break;
          case ConnectionStatus.error:
            _statusMessage = '❌ Connection error';
            _isConnecting = false;
            break;
        }
      });
    });

    _socketService.orderStream.listen((orderData) {
      setState(() {
        _orders.insert(0, OrderUpdate.fromJson(orderData));
        if (_orders.length > 50) {
          _orders.removeLast();
        }
      });
    });
  }

  Color _getStatusColor() {
    switch (_socketService.status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  void _disconnect() {
    _socketService.disconnect();
    setState(() {
      _statusMessage = 'Disconnected';
      _orders.clear();
    });
  }

  @override
  void dispose() {
    _socketService.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Client'),
        backgroundColor: _getStatusColor(),
        actions: [
          if (_socketService.status == ConnectionStatus.connected)
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            )
          else
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showManualConnectionDialog,
              tooltip: 'Manual Connection',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _getStatusColor().withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _socketService.status == ConnectionStatus.connected
                          ? Icons.check_circle
                          : _isConnecting
                          ? Icons.hourglass_empty
                          : Icons.error,
                      color: _getStatusColor(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_serverInfo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Server: ${_serverInfo!.url}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Retry Button (only show if not connected and not connecting)
          if (_socketService.status != ConnectionStatus.connected && !_isConnecting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _autoConnect,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Auto-Connect'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

          // Orders Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[200],
            child: Text(
              'Recent Orders (${_orders.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: _orders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnecting
                        ? Icons.cloud_sync
                        : _socketService.status == ConnectionStatus.connected
                        ? Icons.inbox
                        : Icons.cloud_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isConnecting
                        ? 'Connecting...'
                        : _socketService.status == ConnectionStatus.connected
                        ? 'Waiting for orders...'
                        : 'Not connected',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _orders.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getOrderStatusColor(order.status),
                      child: Text(
                        '#${order.orderId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      'Order #${order.orderId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Status: ${order.status}\n${order.formattedTime}',
                    ),
                    trailing: Icon(
                      Icons.access_time,
                      color: Colors.grey[400],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _socketService.status == ConnectionStatus.connected
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _orders.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Orders cleared')),
          );
        },
        child: const Icon(Icons.clear_all),
        tooltip: 'Clear Orders',
      )
          : null,
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class OrderUpdate {
  final int orderId;
  final String status;
  final DateTime timestamp;

  OrderUpdate({
    required this.orderId,
    required this.status,
    required this.timestamp,
  });

  factory OrderUpdate.fromJson(Map<String, dynamic> json) {
    return OrderUpdate(
      orderId: json['orderId'] as int,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String get formattedTime {
    return DateFormat('HH:mm:ss').format(timestamp);
  }
}
