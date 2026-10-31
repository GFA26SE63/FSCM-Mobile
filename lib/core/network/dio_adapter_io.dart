import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

void configureDevHttpAdapter(Dio dio) {
  if (!kDebugMode) return;
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
      };
      return client;
    };
  }
}
