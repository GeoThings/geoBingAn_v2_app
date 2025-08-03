import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _showLocalLogin = false;
  final _secureStorage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _handleLocalLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await ApiService.instance.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Save tokens
        await _secureStorage.write(
          key: 'access_token',
          value: data['tokens']['access_token'],
        );
        await _secureStorage.write(
          key: 'refresh_token',
          value: data['tokens']['refresh_token'],
        );
        
        // Save user data
        if (data['user'] != null) {
          await StorageService.instance.saveUser(data['user']);
        }
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final googleAuthUrl = '${AppConfig.apiBaseUrl}/auth/oauth/google/login/';
      
      if (kIsWeb) {
        // For web, use direct navigation
        final callbackUrl = Uri.base.origin + '/oauth/callback';
        final authUrlWithCallback = '$googleAuthUrl?redirect_uri=${Uri.encodeComponent(callbackUrl)}';
        
        await launchUrl(
          Uri.parse(authUrlWithCallback),
          webOnlyWindowName: '_self',
        );
      } else {
        // For mobile, use flutter_web_auth_2
        final callbackUrlScheme = 'geobingan';
        
        try {
          final result = await FlutterWebAuth2.authenticate(
            url: googleAuthUrl,
            callbackUrlScheme: callbackUrlScheme,
          );
          
          // Parse the result
          final uri = Uri.parse(result);
          final params = uri.queryParameters;
          
          // Check for encoded auth data
          final encodedData = params['data'];
          if (encodedData != null) {
            final decodedData = utf8.decode(base64.decode(encodedData));
            final authData = jsonDecode(decodedData);
            
            // Save authentication data
            await _saveAuthData(authData);
            
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/home');
          } else if (params['error'] != null) {
            throw Exception(params['error']);
          } else {
            throw Exception('No authentication data received');
          }
        } catch (e) {
          // If flutter_web_auth_2 fails, try launching in external browser
          if (await canLaunchUrl(Uri.parse(googleAuthUrl))) {
            await launchUrl(
              Uri.parse(googleAuthUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            throw 'Could not launch Google Sign In';
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign in with Google: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _showLocalLogin ? _buildLocalLoginForm(isDark) : _buildSocialLogin(isDark),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSocialLogin(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 48),
        Text(
          'geoBingAn',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Report incidents with AI assistance',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 64),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Image.network(
                  'https://www.google.com/favicon.ico',
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.g_mobiledata, size: 24, color: Colors.white);
                  },
                ),
          label: Text(_isLoading ? 'Signing in...' : 'Sign in with Google'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _showLocalLogin = true;
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          child: const Text('Sign in with Email'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/register');
          },
          child: const Text('Create Account'),
        ),
      ],
    );
  }
  
  Widget _buildLocalLoginForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _showLocalLogin = false;
              });
            },
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black,
            ),
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 24),
          Text(
            'Sign In',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back to geoBingAn',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLocalLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Sign In'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}