import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  
  late final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  
  ApiService._() {
    _initializeDio();
  }
  
  void _initializeDio() {
    final options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.apiTimeout,
      receiveTimeout: AppConfig.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    
    _dio = Dio(options);
    
    final cacheOptions = CacheOptions(
      store: HiveCacheStore(null),
      policy: CachePolicy.request,
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(days: 7),
    );
    
    _dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          final currentGroup = StorageService.instance.getCurrentGroup();
          if (currentGroup != null) {
            options.headers['X-Current-Group'] = currentGroup['id'];
          }
          
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final retryOptions = error.requestOptions;
              final token = await _getAccessToken();
              retryOptions.headers['Authorization'] = 'Bearer $token';
              
              try {
                final response = await _dio.fetch(retryOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                handler.reject(error);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }
  
  Future<String?> _getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }
  
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }
  
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        '/auth/auth/refresh_token/',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: refreshToken,
        );
        return true;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    }
    return false;
  }
  
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }
  
  // Auth endpoints
  Future<Response> login(String email, String password) async {
    return await _dio.post('/auth/auth/login/', data: {
      'email': email,
      'password': password,
    });
  }
  
  Future<Response> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Use email as username if not provided separately
    final username = email.split('@')[0]; // Use email prefix as username
    
    return await _dio.post('/auth/auth/register/', data: {
      'email': email,
      'username': username,
      'password': password,
      'password_confirm': password, // Use same password for confirmation
      'display_name': displayName,
    });
  }
  
  Future<Response> logout() async {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    return await _dio.post('/auth/auth/logout/', data: {
      'refresh_token': refreshToken,
    });
  }
  
  Future<Response> getCurrentUser() async {
    return await _dio.get('/auth/profile/me/');
  }
  
  // Reports endpoints
  Future<Response> getReports({
    Map<String, dynamic>? params,
  }) async {
    return await _dio.get('/reports/reports/', queryParameters: params);
  }
  
  Future<Response> submitReport(Map<String, dynamic> reportData) async {
    return await _dio.post('/reports/reports/submit/', data: reportData);
  }
  
  Future<Response> getFormTemplates() async {
    return await _dio.get('/reports/form-templates/');
  }
  
  Future<Response> getOntologyConcepts({
    String? domain,
    String? language,
  }) async {
    return await _dio.get('/reports/ontology-concepts/', queryParameters: {
      if (domain != null) 'domain': domain,
      if (language != null) 'language': language,
    });
  }
  
  // Messenger sessions for conversational forms
  Future<Response> startConversation({
    required String formTemplateId,
    String? platform,
  }) async {
    return await _dio.post('/reports/messenger-sessions/start_conversation/', data: {
      'form_template_id': formTemplateId,
      'platform': platform ?? 'mobile_app',
    });
  }
  
  Future<Response> sendConversationResponse({
    required String sessionId,
    required String response,
  }) async {
    return await _dio.post('/reports/messenger-sessions/$sessionId/respond/', data: {
      'response': response,
    });
  }
  
  // Groups endpoints
  Future<Response> getGroups() async {
    return await _dio.get('/groups/');
  }
  
  Future<Response> getGroupDetails(String groupId) async {
    return await _dio.get('/groups/$groupId/');
  }
  
  Dio get dio => _dio;
}