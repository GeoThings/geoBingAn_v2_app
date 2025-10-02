import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/role_service.dart';
import '../../../../core/services/language_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final StorageService _storageService = StorageService.instance;
  final RoleService _roleService = RoleService.instance;
  
  late UserRole _selectedRole;
  late String _selectedLanguage;
  late String _selectedTheme;
  Map<String, dynamic>? _user;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  void _loadSettings() {
    setState(() {
      _selectedRole = _roleService.getCurrentRole();
      _selectedLanguage = _storageService.getLanguage();
      _selectedTheme = _storageService.getThemeMode();
      _user = _storageService.getUser();
    });
  }
  
  Future<void> _updateRole(UserRole? role) async {
    if (role != null && role != _selectedRole) {
      await _roleService.setRole(role);
      setState(() {
        _selectedRole = role;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role updated to ${role.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _updateLanguage(String? language) async {
    if (language != null && language != _selectedLanguage) {
      await _storageService.saveLanguage(language);
      setState(() {
        _selectedLanguage = language;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Language updated. Some changes may require app restart.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _updateTheme(String? theme) async {
    if (theme != null && theme != _selectedTheme) {
      await _storageService.saveThemeMode(theme);
      setState(() {
        _selectedTheme = theme;
      });
      
      // TODO: Apply theme change dynamically
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Profile Section
          if (_user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: Text(
                        (_user!['display_name'] ?? _user!['username'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(_user!['display_name'] ?? _user!['username'] ?? 'User'),
                    subtitle: Text(_user!['email'] ?? ''),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          
          // Role Selection Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Role',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your role to get tailored AI assistance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: _selectedRole,
                      isExpanded: true,
                      onChanged: _updateRole,
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                role.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _getRoleDescription(role),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Language Settings
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      onChanged: _updateLanguage,
                      items: const [
                        DropdownMenuItem(
                          value: 'zh-hant',
                          child: Text('繁體中文 (Traditional Chinese)'),
                        ),
                        DropdownMenuItem(
                          value: 'zh-hans',
                          child: Text('简体中文 (Simplified Chinese)'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'ja',
                          child: Text('日本語 (Japanese)'),
                        ),
                        DropdownMenuItem(
                          value: 'ko',
                          child: Text('한국어 (Korean)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Theme Settings
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTheme,
                      isExpanded: true,
                      onChanged: _updateTheme,
                      items: const [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text('System Default'),
                        ),
                        DropdownMenuItem(
                          value: 'light',
                          child: Text('Light Mode'),
                        ),
                        DropdownMenuItem(
                          value: 'dark',
                          child: Text('Dark Mode'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // About Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                  leading: const Icon(Icons.info_outline),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  leading: const Icon(Icons.description_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to terms
                  },
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.safetyInspector:
        return 'Inspect safety hazards and risks';
      case UserRole.environmentalSpecialist:
        return 'Assess environmental impact and pollution';
      case UserRole.infrastructureEngineer:
        return 'Evaluate infrastructure condition';
      case UserRole.emergencyResponder:
        return 'Respond to emergency situations';
      case UserRole.constructionSupervisor:
        return 'Supervise construction safety';
      case UserRole.geotechnicalAnalyst:
        return 'Analyze soil and geological conditions';
    }
  }
}