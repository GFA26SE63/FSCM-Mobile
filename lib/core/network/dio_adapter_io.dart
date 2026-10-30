import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

bool _isDevLocalOrPrivateHost(String host) {
  final h = host.trim().toLowerCase();
  if (h == 'localhost' || h == '127.0.0.1' || h == '::1' || h == '10.0.2.2') {
    return true;
  }
  if (h.endsWith('.local')) return true;
  // Private RFC1918 LAN IPv4 ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12)
  if (h.startsWith('10.') || h.startsWith('192.168.')) return true;
  if (h.startsWith('172.')) {
    final parts = h.split('.');
    if (parts.length == 4) {
      final second = int.tryParse(parts[1]) ?? -1;
      if (second >= 16 && second <= 31) return true;
    }
  }
  return false;
}

void configureDevHttpAdapter(Dio dio) {
  if (!kDebugMode) return;
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return _isDevLocalOrPrivateHost(host);
      };
      return client;
    };
  }
}
