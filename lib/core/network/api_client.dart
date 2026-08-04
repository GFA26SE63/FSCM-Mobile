import 'package:dio/dio.dart';
import 'package:fmcg/config/app_environment.dart';

class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: AppEnvironment.apiBaseUrl,
          headers: const {'Accept': 'application/json'},
        ),
      );

  final Dio dio;
}
