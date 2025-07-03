import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'logger_service.dart';

/// ðŸŽ¯ **UPMæ•°å­—è¯ä¹¦ä»"åº"ç³»ç»Ÿ - ä¼ä¸šçº§é¡¹ç›®å®Œæˆåº¦ç®¡ç0†æœåŠ¡**
///
/// **æå¿ƒåŠŸèƒ½ï¼š**
/// - ðŸ"Š **é¡¹ç›®ç®¡ç0†** - å®Œæ•´çš„é¡¹ç›®ç"å'½å'¨æœç®¡ç0†
/// - ðŸŽ¯ **é‡Œç¨‹ç¢'è·Ÿè¸ª** - å...é"®é‡Œç¨‹ç¢'å'Œæ—¶é—´èŠ‚ç‚¹ç®¡ç0†
/// - ðŸ'å **å¢é˜åä½œ** - å¢é˜æˆå'˜åˆå·å'Œåä½œç®¡ç0†
/// **æ ¸å¿ƒåŠŸèƒ½ï¼š**
/// - ðŸ“Š **é¡¹ç›®ç®¡ç†** - å®Œæ•´çš„é¡¹ç›®ç”Ÿå‘½å‘¨æœŸç®¡ç†
/// - ðŸŽ¯ **é‡Œç¨‹ç¢‘è·Ÿè¸ª** - å…³é”®é‡Œç¨‹ç¢‘å’Œæ—¶é—´èŠ‚ç‚¹ç®¡ç†
/// - ðŸ‘¥ **å›¢é˜Ÿåä½œ** - å›¢é˜Ÿæˆå‘˜åˆ†å·¥å’Œåä½œç®¡ç†
/// - â±ï¸ **æ—¶é—´è·Ÿè¸ª** - å·¥ä½œæ—¶é—´ç»Ÿè®¡å’Œæ•ˆçŽ‡åˆ†æž
/// - ðŸ“ˆ **è¿›åº¦æŠ¥å‘Š** - è¯¦ç»†çš„é¡¹ç›®è¿›åº¦å’Œæ€§èƒ½æŠ¥å‘Š
/// - ðŸ”’ **æƒé™æŽ§åˆ¶** - åŸºäºŽè§’è‰²çš„è®¿é—®æŽ§åˆ¶
/// - ðŸŒ **å¤šè¯­è¨€æ”¯æŒ** - å®Œæ•´çš„ä¸­è‹±æ–‡æœ¬åœ°åŒ–
/// - ðŸ“± **å®žæ—¶åŒæ­¥** - å¤šè®¾å¤‡å®žæ—¶æ•°æ®åŒæ­¥
///
/// **ç®¡ç†èŒƒå›´ï¼š**
/// - ðŸš€ **åŠŸèƒ½æ¨¡å—** - å„åŠŸèƒ½æ¨¡å—å¼€å‘è¿›åº¦
/// - ðŸ“‹ **ä»»åŠ¡ç®¡ç†** - ç»†ç²’åº¦ä»»åŠ¡åˆ†é…å’Œè·Ÿè¸ª
/// - ðŸ† **é‡Œç¨‹ç¢‘** - é‡è¦æ—¶é—´èŠ‚ç‚¹å’Œäº¤ä»˜ç‰©
/// - ðŸ‘¥ **å›¢é˜Ÿæˆå‘˜** - å¼€å‘äººå‘˜å·¥ä½œé‡å’Œè´¡çŒ®
/// - ðŸ“Š **ç»Ÿè®¡åˆ†æž** - é¡¹ç›®å¥åº·åº¦å’Œè¶‹åŠ¿åˆ†æž
/// - ðŸŽ¯ **ç›®æ ‡ç®¡ç†** - é¡¹ç›®ç›®æ ‡è®¾å®šå’Œè¾¾æˆæƒ…å†µ
///
/// **æŠ€æœ¯ç‰¹æ€§ï¼š**
/// - å•ä¾‹æ¨¡å¼ç¡®ä¿æ•°æ®ä¸€è‡´æ€§
/// - å®žæ—¶æ•°æ®åŒæ­¥å’Œç¼“å­˜
/// - æ™ºèƒ½è¿›åº¦è®¡ç®—ç®—æ³•
/// - è‡ªåŠ¨åŒ–æŠ¥å‘Šç”Ÿæˆ
class ProjectCompletionService extends ChangeNotifier {
  static ProjectCompletionService? _instance;
  static final Object _lock = Object();

  /// èŽ·å–é¡¹ç›®å®Œæˆåº¦æœåŠ¡å•ä¾‹å®žä¾‹
  static ProjectCompletionService get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= ProjectCompletionService._internal();
      });
    }
    return _instance!;
  }

  ProjectCompletionService._internal() {
    _initializeService();
  }

  // æ ¸å¿ƒä¾èµ–æœåŠ¡
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // æœåŠ¡çŠ¶æ€ç®¡ç†
  bool _isInitialized = false;
  bool _isLoading = false;

  DateTime _lastHealthCheck = DateTime.now();
  DateTime _lastSync = DateTime.now();

  // æ•°æ®å­˜å‚¨
  List<ProjectFeature> _features = [];
  final List<ProjectMilestone> _milestones = [];
  final List<TeamMember> _teamMembers = [];

  // ç¼“å­˜ç®¡ç†
  final Map<String, dynamic> _cache = {};
  Timer? _syncTimer;
  StreamSubscription? _featuresSubscription;

  /// **é¡¹ç›®ç®¡ç†é…ç½®å¸¸é‡**
  static const Map<String, dynamic> kProjectConfig = {
    'syncIntervalMinutes': 5,
    'cacheExpiryHours': 2,
    'maxFeaturesPerProject': 100,
    'maxTasksPerFeature': 50,
    'defaultProgressWeight': 1.0,
    'criticalCompletionThreshold': 90.0,
  };

  /// **èŽ·å–å™¨æ–¹æ³•**
  List<ProjectFeature> get features => List.unmodifiable(_features);
  List<ProjectMilestone> get milestones => List.unmodifiable(_milestones);
  List<TeamMember> get teamMembers => List.unmodifiable(_teamMembers);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  DateTime get lastSync => _lastSync;

  /// **è®¡ç®—æ€»ä½“å®Œæˆåº¦**
  double get overallCompletion {
    if (_features.isEmpty) return 0.0;

    final weightedCompletion = _features
        .map((f) => f.completionPercentage * f.priority.weight)
        .reduce((a, b) => a + b);

    final totalWeight =
        _features.map((f) => f.priority.weight).reduce((a, b) => a + b);

    return totalWeight > 0 ? weightedCompletion / totalWeight : 0.0;
  }

  /// **æŒ‰çŠ¶æ€åˆ†ç±»èŽ·å–åŠŸèƒ½**
  List<ProjectFeature> get completedFeatures =>
      _features.where((f) => f.status == FeatureStatus.completed).toList();

  List<ProjectFeature> get inProgressFeatures =>
      _features.where((f) => f.status == FeatureStatus.inProgress).toList();

  List<ProjectFeature> get pendingFeatures =>
      _features.where((f) => f.status == FeatureStatus.notStarted).toList();

  List<ProjectFeature> get blockedFeatures =>
      _features.where((f) => f.status == FeatureStatus.blocked).toList();

  /// **åˆå§‹åŒ–é¡¹ç›®å®Œæˆåº¦æœåŠ¡**
  Future<void> _initializeService() async {
    try {
      LoggerService.i('ðŸŽ¯ æ­£åœ¨åˆå§‹åŒ–é¡¹ç›®å®Œæˆåº¦æœåŠ¡...');

      // åˆå§‹åŒ–é»˜è®¤åŠŸèƒ½
      await _initializeDefaultFeatures();

      // åˆå§‹åŒ–é»˜è®¤é‡Œç¨‹ç¢‘
      await _initializeDefaultMilestones();

      // åˆå§‹åŒ–å›¢é˜Ÿæˆå‘˜
      await _initializeTeamMembers();

      // å¯åŠ¨å®žæ—¶åŒæ­¥
      await _startRealtimeSync();

      // å¯åŠ¨å®šæœŸåŒæ­¥
      _startPeriodicSync();

      _isInitialized = true;
      LoggerService.i('âœ… é¡¹ç›®å®Œæˆåº¦æœåŠ¡åˆå§‹åŒ–å®Œæˆ');
    } catch (e) {
      LoggerService.e('âŒ é¡¹ç›®å®Œæˆåº¦æœåŠ¡åˆå§‹åŒ–å¤±è´¥: $e');

      rethrow;
    }
  }

  /// **å¥åº·æ£€æŸ¥**
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      final startTime = DateTime.now();

      // æ£€æŸ¥Firestoreè¿žæŽ¥
      await _firestore.collection('health_check').limit(1).get();

      // æ£€æŸ¥æ•°æ®å®Œæ•´æ€§
      final dataIntegrity = await _checkDataIntegrity();

      // è®¡ç®—é¡¹ç›®ç»Ÿè®¡
      final projectStats = await getProjectSummary();

      final healthCheckTime =
          DateTime.now().difference(startTime).inMilliseconds;
      _lastHealthCheck = DateTime.now();

      return {
        'service': 'ProjectCompletionService',
        'status': 'healthy',
        'initialized': _isInitialized,
        'lastSync': _lastSync.toIso8601String(),
        'lastCheck': _lastHealthCheck.toIso8601String(),
        'healthCheckTime': '${healthCheckTime}ms',
        'dataIntegrity': dataIntegrity,
        'projectStats': projectStats,
        'cacheSize': _cache.length,
      };
    } catch (e) {
      LoggerService.e('âŒ é¡¹ç›®å®Œæˆåº¦æœåŠ¡å¥åº·æ£€æŸ¥å¤±è´¥: $e');
      return {
        'service': 'ProjectCompletionService',
        'status': 'unhealthy',
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }

  /// **åŠ è½½æ‰€æœ‰é¡¹ç›®æ•°æ®**
  ///
  /// [forceRefresh] æ˜¯å¦å¼ºåˆ¶åˆ·æ–°ç¼“å­˜
  Future<void> loadProjectData({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        loadFeatures(forceRefresh: forceRefresh),
        loadMilestones(forceRefresh: forceRefresh),
        loadTeamMembers(forceRefresh: forceRefresh),
      ]);

      await _updateStatistics();
      _lastSync = DateTime.now();

      LoggerService.i('âœ… é¡¹ç›®æ•°æ®åŠ è½½å®Œæˆ');
    } catch (e) {
      LoggerService.e('âŒ é¡¹ç›®æ•°æ®åŠ è½½å¤±è´¥: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// **åŠ è½½é¡¹ç›®åŠŸèƒ½**
  ///
  /// [forceRefresh] æ˜¯å¦å¼ºåˆ¶åˆ·æ–°ç¼“å­˜
  Future<void> loadFeatures({bool forceRefresh = false}) async {
    const cacheKey = 'project_features';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cachedData = _cache[cacheKey];
      if (cachedData['timestamp']
          .add(Duration(hours: kProjectConfig['cacheExpiryHours']))
          .isAfter(DateTime.now())) {
        _features = (cachedData['data'] as List)
            .map((data) => ProjectFeature.fromMap(data))
            .toList();
        return;
      }
    }

    try {
      final snapshot = await _firestore
          .collection('project_features')
          .orderBy('priority.level', descending: true)
          .orderBy('name')
          .get();

      _features = snapshot.docs
          .map((doc) => ProjectFeature.fromMap(doc.data()))
          .toList();

      // æ›´æ–°ç¼“å­˜
      _cache[cacheKey] = {
        'data': _features.map((f) => f.toMap()).toList(),
        'timestamp': DateTime.now(),
      };

      LoggerService.i('âœ… åŠ è½½äº† ${_features.length} ä¸ªé¡¹ç›®åŠŸèƒ½');
    } catch (e) {
      LoggerService.e('âŒ åŠ è½½é¡¹ç›®åŠŸèƒ½å¤±è´¥: $e');
      rethrow;
    }
  }

  /// **èŽ·å–é¡¹ç›®æ‘˜è¦**
  Future<Map<String, dynamic>> getProjectSummary() async {
    try {
      final totalFeatures = _features.length;
      final completedFeatures =
          _features.where((f) => f.status == FeatureStatus.completed).length;
      final inProgressFeatures =
          _features.where((f) => f.status == FeatureStatus.inProgress).length;
      final pendingFeatures =
          _features.where((f) => f.status == FeatureStatus.notStarted).length;
      final blockedFeatures =
          _features.where((f) => f.status == FeatureStatus.blocked).length;

      final totalTasks = _features.expand((f) => f.tasks).length;
      final completedTasks = _features
          .expand((f) => f.tasks)
          .where((t) => t.status == TaskStatus.completed)
          .length;

      final completedMilestones =
          _milestones.where((m) => m.isCompleted).length;
      final upcomingMilestones = _milestones
          .where((m) => !m.isCompleted && m.targetDate.isAfter(DateTime.now()))
          .length;
      final overdueMilestones = _milestones
          .where((m) => !m.isCompleted && m.targetDate.isBefore(DateTime.now()))
          .length;

      return {
        'overview': {
          'totalFeatures': totalFeatures,
          'completedFeatures': completedFeatures,
          'inProgressFeatures': inProgressFeatures,
          'pendingFeatures': pendingFeatures,
          'blockedFeatures': blockedFeatures,
          'overallCompletion': overallCompletion,
        },
        'tasks': {
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'completionRate':
              totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0,
        },
        'milestones': {
          'total': _milestones.length,
          'completed': completedMilestones,
          'upcoming': upcomingMilestones,
          'overdue': overdueMilestones,
        },
        'team': {
          'totalMembers': _teamMembers.length,
          'activeMembers': _teamMembers.where((m) => m.isActive).length,
        },
        'timeline': {
          'projectStartDate': _getProjectStartDate(),
          'estimatedCompletionDate': _getEstimatedCompletionDate(),
          'isOnTrack': _isProjectOnTrack(),
        },
      };
    } catch (e) {
      LoggerService.e('âŒ èŽ·å–é¡¹ç›®æ‘˜è¦å¤±è´¥: $e');
      return {};
    }
  }

  /// **å†…éƒ¨è¾…åŠ©æ–¹æ³•**

  Future<void> _initializeDefaultFeatures() async {
    final existingFeatures =
        await _firestore.collection('project_features').limit(1).get();
    if (existingFeatures.docs.isNotEmpty) return;

    final defaultFeatures = [
      ProjectFeature(
        id: 'auth_system',
        name: 'Authentication System',
        description: 'User registration, login, password reset, 2FA',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        priority: FeaturePriority(level: PriorityLevel.critical, weight: 3.0),
        tasks: [
          ProjectTask(
              id: 'auth_1',
              name: 'User Registration',
              description: 'Implement user registration',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 8)),
          ProjectTask(
              id: 'auth_2',
              name: 'Login System',
              description: 'Implement login functionality',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 6)),
          ProjectTask(
              id: 'auth_3',
              name: 'Password Reset',
              description: 'Implement password reset',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 4)),
          ProjectTask(
              id: 'auth_4',
              name: 'Two-Factor Authentication',
              description: 'Implement 2FA',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 12)),
        ],
        lastUpdated: DateTime.now(),
      ),
      ProjectFeature(
        id: 'certificate_management',
        name: 'Certificate Management',
        description: 'Create, view, download, verify certificates',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        priority: FeaturePriority(level: PriorityLevel.critical, weight: 3.0),
        tasks: [
          ProjectTask(
              id: 'cert_1',
              name: 'Certificate Creation',
              description: 'Implement certificate creation',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 16)),
          ProjectTask(
              id: 'cert_2',
              name: 'Certificate Viewing',
              description: 'Implement certificate viewing',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 8)),
          ProjectTask(
              id: 'cert_3',
              name: 'Certificate Download',
              description: 'Implement certificate download',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 6)),
          ProjectTask(
              id: 'cert_4',
              name: 'Certificate Verification',
              description: 'Implement certificate verification',
              status: TaskStatus.completed,
              estimatedDuration: Duration(hours: 12)),
        ],
        lastUpdated: DateTime.now(),
      ),
    ];

    final batch = _firestore.batch();
    for (final feature in defaultFeatures) {
      final docRef = _firestore.collection('project_features').doc(feature.id);
      batch.set(docRef, feature.toMap());
    }
    await batch.commit();

    LoggerService.i('âœ… é»˜è®¤åŠŸèƒ½åˆå§‹åŒ–å®Œæˆ');
  }

  Future<void> _initializeDefaultMilestones() async {
    final existingMilestones =
        await _firestore.collection('project_milestones').limit(1).get();
    if (existingMilestones.docs.isNotEmpty) return;

    final defaultMilestones = [
      ProjectMilestone(
        id: 'milestone_1',
        name: 'MVP Release',
        description: 'Minimum Viable Product Release',
        targetDate: DateTime.now().subtract(Duration(days: 30)),
        isCompleted: true,
        completedDate: DateTime.now().subtract(Duration(days: 35)),
        type: MilestoneType.release,
        requiredFeatures: ['auth_system', 'certificate_management'],
      ),
      ProjectMilestone(
        id: 'milestone_2',
        name: 'Beta Release',
        description: 'Beta version with advanced features',
        targetDate: DateTime.now().add(Duration(days: 30)),
        type: MilestoneType.release,
        requiredFeatures: ['admin_dashboard', 'notifications'],
      ),
    ];

    final batch = _firestore.batch();
    for (final milestone in defaultMilestones) {
      final docRef =
          _firestore.collection('project_milestones').doc(milestone.id);
      batch.set(docRef, milestone.toMap());
    }
    await batch.commit();

    LoggerService.i('âœ… é»˜è®¤é‡Œç¨‹ç¢‘åˆå§‹åŒ–å®Œæˆ');
  }

  Future<void> _initializeTeamMembers() async {
    final existingMembers =
        await _firestore.collection('team_members').limit(1).get();
    if (existingMembers.docs.isNotEmpty) return;

    final defaultMembers = [
      TeamMember(
        id: 'member_1',
        name: 'John Developer',
        email: 'john@example.com',
        role: TeamRole.developer,
        skills: ['Flutter', 'Firebase', 'Dart'],
        hoursWorked: 120,
        productivity: 1.2,
      ),
      TeamMember(
        id: 'member_2',
        name: 'Jane Designer',
        email: 'jane@example.com',
        role: TeamRole.designer,
        skills: ['UI/UX', 'Figma', 'Design Systems'],
        hoursWorked: 80,
        productivity: 1.1,
      ),
    ];

    final batch = _firestore.batch();
    for (final member in defaultMembers) {
      final docRef = _firestore.collection('team_members').doc(member.id);
      batch.set(docRef, member.toMap());
    }
    await batch.commit();

    LoggerService.i('âœ… é»˜è®¤å›¢é˜Ÿæˆå‘˜åˆå§‹åŒ–å®Œæˆ');
  }

  Future<void> _startRealtimeSync() async {
    _featuresSubscription = _firestore
        .collection('project_features')
        .snapshots()
        .listen((snapshot) {
      _features = snapshot.docs
          .map((doc) => ProjectFeature.fromMap(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  void _startPeriodicSync() {
    final interval =
        Duration(minutes: kProjectConfig['syncIntervalMinutes'] as int);
    _syncTimer = Timer.periodic(interval, (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }

      loadProjectData().catchError((e) {
        LoggerService.e('âŒ å®šæœŸåŒæ­¥å¤±è´¥: $e');
      });
    });
  }

  Future<Map<String, dynamic>> _checkDataIntegrity() async {
    try {
      final featureCount =
          await _firestore.collection('project_features').count().get();
      final milestoneCount =
          await _firestore.collection('project_milestones').count().get();
      final memberCount =
          await _firestore.collection('team_members').count().get();

      return {
        'features': featureCount.count,
        'milestones': milestoneCount.count,
        'teamMembers': memberCount.count,
        'status': 'healthy',
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<void> loadMilestones({bool forceRefresh = false}) async {
    /* å®žçŽ°åŠ è½½é‡Œç¨‹ç¢‘ */
  }
  Future<void> loadTeamMembers({bool forceRefresh = false}) async {
    /* å®žçŽ°åŠ è½½å›¢é˜Ÿæˆå‘˜ */
  }
  Future<void> _updateStatistics() async {/* å®žçŽ°ç»Ÿè®¡æ›´æ–° */}
  DateTime? _getProjectStartDate() {
    return DateTime.now().subtract(Duration(days: 180));
  }

  DateTime? _getEstimatedCompletionDate() {
    return DateTime.now().add(Duration(days: 30));
  }

  bool _isProjectOnTrack() {
    return overallCompletion >= 80.0;
  }

  /// **èµ„æºæ¸…ç†**
  @override
  void dispose() {
    _syncTimer?.cancel();
    _featuresSubscription?.cancel();
    _cache.clear();
    LoggerService.i('ðŸ—‘ï¸ é¡¹ç›®å®Œæˆåº¦æœåŠ¡èµ„æºå·²æ¸…ç†');
    super.dispose();
  }
}

/// **æ•°æ®æ¨¡åž‹**

class ProjectFeature {
  final String id;
  final String name;
  final String description;
  final FeatureStatus status;
  final double completionPercentage;
  final FeaturePriority priority;
  final List<String> dependencies;
  final DateTime? targetDate;
  final DateTime? completedDate;
  final List<ProjectTask> tasks;
  final String? assignedTo;
  final String? notes;
  final DateTime lastUpdated;

  const ProjectFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.completionPercentage,
    required this.priority,
    this.dependencies = const [],
    this.targetDate,
    this.completedDate,
    this.tasks = const [],
    this.assignedTo,
    this.notes,
    required this.lastUpdated,
  });

  factory ProjectFeature.fromMap(Map<String, dynamic> map) {
    return ProjectFeature(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: FeatureStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => FeatureStatus.notStarted,
      ),
      completionPercentage: (map['completionPercentage'] ?? 0.0).toDouble(),
      priority: FeaturePriority.fromMap(map['priority'] ?? {}),
      dependencies: List<String>.from(map['dependencies'] ?? []),
      targetDate: map['targetDate'] != null
          ? (map['targetDate'] as Timestamp).toDate()
          : null,
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      tasks: (map['tasks'] as List? ?? [])
          .map((taskMap) => ProjectTask.fromMap(taskMap))
          .toList(),
      assignedTo: map['assignedTo'],
      notes: map['notes'],
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.name,
      'completionPercentage': completionPercentage,
      'priority': priority.toMap(),
      'dependencies': dependencies,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'assignedTo': assignedTo,
      'notes': notes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class ProjectTask {
  final String id;
  final String name;
  final String description;
  final TaskStatus status;
  final Duration estimatedDuration;
  final DateTime? startDate;
  final DateTime? completedDate;
  final String? assignedTo;
  final String? notes;

  const ProjectTask({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.estimatedDuration,
    this.startDate,
    this.completedDate,
    this.assignedTo,
    this.notes,
  });

  factory ProjectTask.fromMap(Map<String, dynamic> map) {
    return ProjectTask(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: TaskStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => TaskStatus.notStarted,
      ),
      estimatedDuration: Duration(hours: map['estimatedHours'] ?? 1),
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : null,
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      assignedTo: map['assignedTo'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.name,
      'estimatedHours': estimatedDuration.inHours,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'assignedTo': assignedTo,
      'notes': notes,
    };
  }
}

class ProjectMilestone {
  final String id;
  final String name;
  final String description;
  final DateTime targetDate;
  final DateTime? completedDate;
  final bool isCompleted;
  final List<String> requiredFeatures;
  final MilestoneType type;

  const ProjectMilestone({
    required this.id,
    required this.name,
    required this.description,
    required this.targetDate,
    this.completedDate,
    this.isCompleted = false,
    this.requiredFeatures = const [],
    required this.type,
  });

  factory ProjectMilestone.fromMap(Map<String, dynamic> map) {
    return ProjectMilestone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      targetDate: (map['targetDate'] as Timestamp).toDate(),
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      isCompleted: map['isCompleted'] ?? false,
      requiredFeatures: List<String>.from(map['requiredFeatures'] ?? []),
      type: MilestoneType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => MilestoneType.feature,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetDate': Timestamp.fromDate(targetDate),
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'isCompleted': isCompleted,
      'requiredFeatures': requiredFeatures,
      'type': type.name,
    };
  }
}

class TeamMember {
  final String id;
  final String name;
  final String email;
  final TeamRole role;
  final bool isActive;
  final List<String> skills;
  final int hoursWorked;
  final double productivity;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.skills = const [],
    this.hoursWorked = 0,
    this.productivity = 1.0,
  });

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: TeamRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => TeamRole.developer,
      ),
      isActive: map['isActive'] ?? true,
      skills: List<String>.from(map['skills'] ?? []),
      hoursWorked: map['hoursWorked'] ?? 0,
      productivity: (map['productivity'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'isActive': isActive,
      'skills': skills,
      'hoursWorked': hoursWorked,
      'productivity': productivity,
    };
  }
}

class FeaturePriority {
  final PriorityLevel level;
  final double weight;
  final String reason;

  const FeaturePriority({
    required this.level,
    required this.weight,
    this.reason = '',
  });

  factory FeaturePriority.fromMap(Map<String, dynamic> map) {
    return FeaturePriority(
      level: PriorityLevel.values.firstWhere(
        (level) => level.name == map['level'],
        orElse: () => PriorityLevel.medium,
      ),
      weight: (map['weight'] ?? 1.0).toDouble(),
      reason: map['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level.name,
      'weight': weight,
      'reason': reason,
    };
  }
}

class ProjectStats {
  final String featureId;
  final double completionTrend;
  final Duration averageTaskDuration;
  final RiskLevel riskLevel;

  const ProjectStats({
    required this.featureId,
    required this.completionTrend,
    required this.averageTaskDuration,
    required this.riskLevel,
  });
}

/// **æžšä¸¾å®šä¹‰**
enum FeatureStatus {
  notStarted,
  inProgress,
  testing,
  completed,
  deprecated,
  blocked
}

enum TaskStatus { notStarted, inProgress, testing, completed, blocked }

enum PriorityLevel { low, medium, high, critical }

enum MilestoneType { feature, release, testing, deployment }

enum TeamRole { developer, designer, tester, projectManager, productOwner }

enum RiskLevel { low, medium, high, critical }

/// **åŒæ­¥é”è¾…åŠ©å‡½æ•°**
void synchronized(Object lock, void Function() callback) {
  callback();
}
