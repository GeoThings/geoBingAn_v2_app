import 'storage_service.dart';
import 'api_service.dart';

// 統一 geoBingAn v2 角色定義 - 與後端 GeoBingAnRole 保持一致
enum UserRole {
  safetyInspector('safety_inspector', 'Safety Inspector'),
  environmentalSpecialist('environmental_specialist', 'Environmental Specialist'),
  infrastructureEngineer('infrastructure_engineer', 'Infrastructure Engineer'),
  emergencyResponder('emergency_responder', 'Emergency Responder'),
  constructionSupervisor('construction_supervisor', 'Construction Supervisor'),
  geotechnicalAnalyst('geotechnical_analyst', 'Geotechnical Analyst');

  final String key;
  final String displayName;

  const UserRole(this.key, this.displayName);

  static UserRole fromKey(String key) {
    return UserRole.values.firstWhere(
      (role) => role.key == key,
      orElse: () => UserRole.safetyInspector,
    );
  }
}

class RoleService {
  static RoleService? _instance;
  static RoleService get instance => _instance ??= RoleService._();

  RoleService._();

  final StorageService _storageService = StorageService.instance;
  final ApiService _apiService = ApiService.instance;

  // 快取角色配置資料
  Map<String, dynamic>? _cachedRoleConfig;
  DateTime? _cacheTimestamp;
  
  UserRole getCurrentRole() {
    final roleKey = _storageService.getUserRole();
    // 如果儲存的是舊版角色，映射到新角色
    final mappedKey = _mapLegacyRoleToNewRole(roleKey);
    return UserRole.fromKey(mappedKey);
  }

  Future<void> setRole(UserRole role) async {
    await _storageService.setUserRole(role.key);
    // 清除角色配置快取，強制重新載入
    _cachedRoleConfig = null;
    _cacheTimestamp = null;
  }

  /// 將舊版角色映射到新的統一角色系統
  String _mapLegacyRoleToNewRole(String legacyRole) {
    const legacyToNewMapping = {
      'accident_operator': 'safety_inspector',
      'issue_operator': 'infrastructure_engineer',
      'site_surveyor': 'construction_supervisor',
      'emergency_doctor': 'emergency_responder',
      'foodbank_manager': 'environmental_specialist',
    };

    return legacyToNewMapping[legacyRole] ?? legacyRole;
  }

  /// 從後端獲取角色配置資料
  Future<Map<String, dynamic>?> getRoleConfig() async {
    // 檢查快取是否有效 (1小時)
    if (_cachedRoleConfig != null && _cacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTimestamp!).inHours < 1) {
        return _cachedRoleConfig;
      }
    }

    try {
      final language = _storageService.getLanguage();
      final response = await _apiService.dio.get(
        '/reports/roles/app/config/',
        queryParameters: {'language': language},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _cachedRoleConfig = response.data['data'];
        _cacheTimestamp = DateTime.now();
        return _cachedRoleConfig;
      }
    } catch (e) {
      print('Failed to fetch role config from backend: $e');
    }

    // 回傳預設配置如果 API 呼叫失敗
    return _getDefaultRoleConfig();
  }

  /// 預設角色配置 (備用)
  Map<String, dynamic> _getDefaultRoleConfig() {
    return {
      'role_choices': [
        ['safety_inspector', 'Safety Inspector'],
        ['environmental_specialist', 'Environmental Specialist'],
        ['infrastructure_engineer', 'Infrastructure Engineer'],
        ['emergency_responder', 'Emergency Responder'],
        ['construction_supervisor', 'Construction Supervisor'],
        ['geotechnical_analyst', 'Geotechnical Analyst'],
      ],
      'role_labels': {
        'safety_inspector': '安全檢查員',
        'environmental_specialist': '環境專家',
        'infrastructure_engineer': '基礎設施工程師',
        'emergency_responder': '緊急應變人員',
        'construction_supervisor': '建案監督工程師',
        'geotechnical_analyst': '地工分析師',
      },
      'role_descriptions': {
        'safety_inspector': '專精於識別安全隱患和風險評估',
        'environmental_specialist': '專注於環境影響評估和污染監測',
        'infrastructure_engineer': '專長結構安全和資產管理',
        'emergency_responder': '專注於災害應變和風險管控',
        'construction_supervisor': '專門監控施工安全和品質控制',
        'geotechnical_analyst': '專精土壤地質和地基工程',
      },
      'language': 'zh-hant'
    };
  }
  
  /// 取得角色的簡化 prompt (完整分析由後端處理)
  String getRolePrompt(UserRole role) {
    switch (role) {
      case UserRole.safetyInspector:
        return 'You are a safety inspector. Help collect safety-related information for reporting.';

      case UserRole.environmentalSpecialist:
        return 'You are an environmental specialist. Help collect environmental impact and pollution information.';

      case UserRole.infrastructureEngineer:
        return 'You are an infrastructure engineer. Help collect structural and facility condition information.';

      case UserRole.emergencyResponder:
        return 'You are an emergency responder. Help collect emergency situation information.';

      case UserRole.constructionSupervisor:
        return 'You are a construction supervisor. Help collect construction safety and progress information.';

      case UserRole.geotechnicalAnalyst:
        return 'You are a geotechnical analyst. Help collect soil and geological condition information.';
    }
  }
  
  /// 取得角色的歡迎訊息 (使用後端角色配置)
  Future<String> getRoleWelcomeMessage(UserRole role) async {
    try {
      final roleConfig = await getRoleConfig();
      final roleDescriptions = roleConfig?['role_descriptions'] as Map<String, dynamic>?;

      if (roleDescriptions != null && roleDescriptions.containsKey(role.key)) {
        final description = roleDescriptions[role.key] as String;
        return '您好！我是 geoBingAn $description。請描述您要報告的情況，我會協助您完成報告。';
      }
    } catch (e) {
      print('Failed to get role welcome message from config: $e');
    }

    // 備用歡迎訊息
    final language = _storageService.getLanguage();
    final isTraditionalChinese = language == 'zh-hant' || language == 'zh-TW';

    if (isTraditionalChinese) {
      switch (role) {
        case UserRole.safetyInspector:
          return '您好！我是 geoBingAn 安全檢查員助理。請描述您發現的安全問題，我會協助您完成報告。';
        case UserRole.environmentalSpecialist:
          return '您好！我是 geoBingAn 環境專家助理。請描述環境相關問題，我會協助您完成評估報告。';
        case UserRole.infrastructureEngineer:
          return '您好！我是 geoBingAn 基礎設施工程師助理。請描述設施狀況問題，我會協助您完成檢查報告。';
        case UserRole.emergencyResponder:
          return '您好！我是 geoBingAn 緊急應變助理。請描述緊急狀況，我會協助您完成應變報告。';
        case UserRole.constructionSupervisor:
          return '您好！我是 geoBingAn 建案監督助理。請描述施工相關問題，我會協助您完成監督報告。';
        case UserRole.geotechnicalAnalyst:
          return '您好！我是 geoBingAn 地工分析助理。請描述地質相關問題，我會協助您完成分析報告。';
      }
    } else {
      // English
      switch (role) {
        case UserRole.safetyInspector:
          return 'Hello! I\'m your geoBingAn safety inspection assistant. Please describe the safety issue and I\'ll help you create a report.';
        case UserRole.environmentalSpecialist:
          return 'Hello! I\'m your geoBingAn environmental assessment assistant. Please describe the environmental issue and I\'ll help you create an assessment report.';
        case UserRole.infrastructureEngineer:
          return 'Hello! I\'m your geoBingAn infrastructure assistant. Please describe the facility condition and I\'ll help you create an inspection report.';
        case UserRole.emergencyResponder:
          return 'Hello! I\'m your geoBingAn emergency response assistant. Please describe the emergency situation and I\'ll help you create a response report.';
        case UserRole.constructionSupervisor:
          return 'Hello! I\'m your geoBingAn construction supervision assistant. Please describe the construction issue and I\'ll help you create a supervision report.';
        case UserRole.geotechnicalAnalyst:
          return 'Hello! I\'m your geoBingAn geotechnical analysis assistant. Please describe the geological condition and I\'ll help you create an analysis report.';
      }
    }
  }
  
  /// 取得角色特定的報告欄位配置
  Map<String, dynamic> getRoleSpecificFields(UserRole role) {
    switch (role) {
      case UserRole.safetyInspector:
        return {
          'report_type': 'safety_inspection',
          'required_fields': ['location', 'hazard_type', 'severity', 'immediate_risk'],
          'severity_scale': ['low', 'medium', 'high', 'critical'],
        };
      case UserRole.environmentalSpecialist:
        return {
          'report_type': 'environmental_assessment',
          'required_fields': ['location', 'environmental_factor', 'impact_level', 'source'],
          'severity_scale': ['minimal', 'moderate', 'significant', 'severe'],
        };
      case UserRole.infrastructureEngineer:
        return {
          'report_type': 'infrastructure_inspection',
          'required_fields': ['facility_type', 'condition', 'maintenance_need', 'priority'],
          'severity_scale': ['good', 'fair', 'poor', 'critical'],
        };
      case UserRole.emergencyResponder:
        return {
          'report_type': 'emergency_response',
          'required_fields': ['incident_type', 'urgency', 'resources_needed', 'evacuations'],
          'severity_scale': ['routine', 'urgent', 'emergency', 'disaster'],
        };
      case UserRole.constructionSupervisor:
        return {
          'report_type': 'construction_supervision',
          'required_fields': ['site_name', 'safety_status', 'progress', 'compliance'],
          'severity_scale': ['on_track', 'attention', 'concern', 'critical'],
        };
      case UserRole.geotechnicalAnalyst:
        return {
          'report_type': 'geotechnical_analysis',
          'required_fields': ['soil_type', 'stability', 'risk_factors', 'recommendations'],
          'severity_scale': ['stable', 'monitor', 'concern', 'unstable'],
        };
    }
  }

  /// 取得所有可用角色 (從後端配置或預設)
  Future<List<UserRole>> getAvailableRoles() async {
    try {
      final roleConfig = await getRoleConfig();
      final roleChoices = roleConfig?['role_choices'] as List<dynamic>?;

      if (roleChoices != null) {
        return roleChoices
            .map((choice) => UserRole.fromKey(choice[0] as String))
            .toList();
      }
    } catch (e) {
      print('Failed to get available roles from config: $e');
    }

    // 回傳預設角色列表
    return UserRole.values;
  }

  /// 取得角色的本地化標籤
  Future<String> getRoleLabel(UserRole role) async {
    try {
      final roleConfig = await getRoleConfig();
      final roleLabels = roleConfig?['role_labels'] as Map<String, dynamic>?;

      if (roleLabels != null && roleLabels.containsKey(role.key)) {
        return roleLabels[role.key] as String;
      }
    } catch (e) {
      print('Failed to get role label from config: $e');
    }

    // 回傳預設顯示名稱
    return role.displayName;
  }
}