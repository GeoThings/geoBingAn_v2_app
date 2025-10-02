import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/chat/presentation/pages/chat_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/oauth_callback_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Hive.initFlutter();
  
  await StorageService.instance.init();
  
  runApp(
    const ProviderScope(
      child: GeoBingAnApp(),
    ),
  );
}

class GeoBingAnApp extends ConsumerWidget {
  const GeoBingAnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'geoBingAn',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/chat': (context) => const ChatPage(),
        '/settings': (context) => const SettingsPage(),
        '/oauth/callback': (context) => const OAuthCallbackPage(),
      },
    );
  }
}