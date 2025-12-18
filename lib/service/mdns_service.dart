import 'dart:async';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';

class MdnsService {
  static const String serviceType = '_pos-server._tcp.local';
  static const int discoveryTimeout = 10; // seconds

  Future<ServerInfo?> discoverServer() async {
    final client = MDnsClient();

    try {
      await client.start();
      debugPrint('🔍 Starting mDNS discovery...');

      final completer = Completer<ServerInfo?>();
      bool found = false;

      // Set timeout
      Timer(const Duration(seconds: discoveryTimeout), () {
        if (!completer.isCompleted) {
          debugPrint('⏱️ Discovery timeout');
          completer.complete(null);
        }
      });

      // Perform discovery
      _performDiscovery(client, completer, found);

      final result = await completer.future;
      return result;
    } catch (e) {
      debugPrint('❌ Discovery error: $e');
      return null;
    } finally {
      client.stop();
    }
  }

  Future<void> _performDiscovery(
      MDnsClient client,
      Completer<ServerInfo?> completer,
      bool found,
      ) async {
    try {
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType))) {
        if (found || completer.isCompleted) break;

        debugPrint('📍 Found PTR: ${ptr.domainName}');

        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          if (found || completer.isCompleted) break;

          debugPrint('📍 Found SRV: ${srv.target}:${srv.port}');

          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))) {
            if (found || completer.isCompleted) break;

            final host = ip.address.address;
            final port = srv.port;

            debugPrint('✅ Found server at $host:$port');

            found = true;
            if (!completer.isCompleted) {
              completer.complete(ServerInfo(host: host, port: port));
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Discovery iteration error: $e');
    }
  }
}

class ServerInfo {
  final String host;
  final int port;

  ServerInfo({required this.host, required this.port});

  String get url => 'http://$host:$port';
}
