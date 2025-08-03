import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../../core/services/storage_service.dart';

class OAuthCallbackPage extends StatefulWidget {
  const OAuthCallbackPage({super.key});

  @override
  State<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  final _secureStorage = const FlutterSecureStorage();
  String _status = 'loading';
  String _message = 'Processing login...';

  @override
  void initState() {
    super.initState();
    _handleOAuthCallback();
  }

  Future<void> _handleOAuthCallback() async {
    try {
      // Get the current URL from the browser
      final uri = Uri.base;
      final params = uri.queryParameters;
      
      // Check for encoded data (new method)
      final encodedData = params['data'];
      if (encodedData != null) {
        try {
          // Decode base64 encoded auth data
          final decodedData = utf8.decode(base64.decode(encodedData));
          final authData = jsonDecode(decodedData);
          
          // Save authentication data
          await _saveAuthData(authData);
          
          setState(() {
            _status = 'success';
            _message = 'Welcome, ${authData['user']['display_name'] ?? 'User'}!';
          });
          
          // Navigate to home after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          });
          return;
        } catch (e) {
          print('Failed to decode auth data: $e');
        }
      }
      
      // Check for direct mode (compatibility)
      final isDirect = params['direct'] == 'true';
      if (isDirect) {
        // This won't work in Flutter web as we can't access localStorage directly
        // We need the backend to send the data in the URL
        throw Exception('Direct mode not supported in mobile app');
      }
      
      // Check for token parameter (fallback)
      final token = params['token'];
      if (token != null) {
        // Would need to make an API call to get auth data
        // But this is less secure for mobile apps
        throw Exception('Token mode not fully implemented');
      }
      
      // Check for error parameter
      final error = params['error'];
      if (error != null) {
        throw Exception(error);
      }
      
      throw Exception('No authentication data received');
      
    } catch (e) {
      setState(() {
        _status = 'error';
        _message = 'Login failed: ${e.toString()}';
      });
      
      // Navigate to login after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    }
  }
  
  Future<void> _saveAuthData(Map<String, dynamic> authData) async {
    final tokens = authData['tokens'];
    final user = authData['user'];
    
    await _secureStorage.write(
      key: 'access_token',
      value: tokens['access_token'],
    );
    await _secureStorage.write(
      key: 'refresh_token',
      value: tokens['refresh_token'],
    );
    
    await StorageService.instance.saveUser(user);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_status == 'loading') ...[
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _message,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
            if (_status == 'success') ...[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 40,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Login Successful!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (_status == 'error') ...[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Login Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Redirecting to login page...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}