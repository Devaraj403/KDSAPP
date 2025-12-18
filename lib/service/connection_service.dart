import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'mdns_service.dart';
import 'socket_service.dart';
import 'dart:async';

class ConnectionService {
  final MdnsService _mdnsService = MdnsService();
  final SocketService socketService;

  ConnectionService(this.socketService);
  Future<ServerInfo?> autoConnect() async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo; // Cache once
    final isEmulator = await _isRunningOnEmulator(deviceInfo);

    if (isEmulator) {
      debugPrint('🖥️ Detected emulator - trying platform-specific host:3000');
      return await _tryEmulatorConnection(deviceInfo);
    } else {
      debugPrint('📱 Detected physical device - trying mDNS discovery');
      return await _tryPhysicalDeviceConnection();
    }
  }

  Future<bool> _isRunningOnEmulator(dynamic deviceInfo) async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidInfo = deviceInfo as AndroidDeviceInfo;
        final isEmulator = androidInfo.isPhysicalDevice == false ||
            androidInfo.fingerprint.contains('generic') ||
            androidInfo.fingerprint.contains('unknown') ||
            androidInfo.model.contains('google_sdk') ||
            androidInfo.model.contains('Emulator') ||
            androidInfo.model.contains('Android SDK built for x86') ||
            androidInfo.manufacturer.contains('Genymotion') ||
            androidInfo.product.contains('sdk') ||
            androidInfo.product.contains('emulator');

        debugPrint('Android Device Info: ${androidInfo.model}, Physical: ${androidInfo.isPhysicalDevice}');
        return isEmulator;
      } else if (Platform.isIOS) {
        final iosInfo = deviceInfo as IosDeviceInfo;
        debugPrint('iOS Device Info: ${iosInfo.model}, Physical: ${iosInfo.isPhysicalDevice}');
        return !iosInfo.isPhysicalDevice;
      }
    } catch (e) {
      debugPrint('Error detecting emulator: $e');
    }
    return false;
  }

  // Future<ServerInfo?> _tryEmulatorConnection(dynamic deviceInfo) async {
  //   const port = 3000;
  //   String host;
  //
  //   if (Platform.isAndroid) {
  //     host = '10.0.2.2';
  //     debugPrint('Attempting Android emulator connection to $host:$port');
  //   } else if (Platform.isIOS) {
  //     host = 'localhost';  // iOS simulator uses host network stack
  //     debugPrint('Attempting iOS simulator connection to $host:$port');
  //   } else {
  //     return null;
  //   }
  //
  //   final serverInfo = ServerInfo(host: host, port: port);
  //   socketService.connect(host, port);
  //
  //   // Wait with multiple timeout checks
  //   for (int i = 0; i < 5; i++) {
  //     await Future.delayed(const Duration(seconds: 1));
  //     if (socketService.status == ConnectionStatus.connected) {
  //       debugPrint('✅ $host emulator connection successful');
  //       return serverInfo;
  //     }
  //     debugPrint('⚠️ Connection check $i/5: timeout');
  //   }
  //
  //   debugPrint('❌ $host emulator connection failed');
  //   return null;
  // }
  Future<ServerInfo?> _tryEmulatorConnection(dynamic deviceInfo) async {
    const port = 3000;
    String host;

    // CRITICAL: Check Platform BEFORE using deviceInfo
    if (Platform.isAndroid) {
      host = '10.0.2.2';
      debugPrint('🔌 Android emulator → $host:$port');
    } else {  // iOS, macOS, etc - ALL use localhost
      host = 'localhost';
      debugPrint('🔌 iOS simulator → $host:$port');  // THIS WILL SHOW NOW
    }

    final serverInfo = ServerInfo(host: host, port: port);
    socketService.connect(host, port);

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('⏱️ [$host] Check ${i+1}/10: ${socketService.status}');
      if (socketService.status == ConnectionStatus.connected) {
        debugPrint('✅ $host:3000 SUCCESS!');
        return serverInfo;
      }
    }

    debugPrint('❌ $host:3000 FAILED');
    return null;
  }


  Future<ServerInfo?> _tryPhysicalDeviceConnection() async {
    // Try mDNS discovery first
    debugPrint('Attempting mDNS discovery...');
    final serverInfo = await _mdnsService.discoverServer();

    if (serverInfo != null) {
      debugPrint('✅ mDNS discovery successful: ${serverInfo.host}:${serverInfo.port}');
      socketService.connect(serverInfo.host, serverInfo.port);
      return serverInfo;
    }

    debugPrint('❌ mDNS discovery failed');
    return null;
  }
}
