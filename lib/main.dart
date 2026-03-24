// ===========================================================================
// SM Academy Quiz Bank — Flutter Port
// ===========================================================================
// This single file replicates the full React/Firebase web app in Flutter.
//
// Architecture overview
//   • MaterialApp with a custom teal/slate theme
//   • AppState (ChangeNotifier) holds auth + all Firestore-like in-memory data
//   • SharedPreferences persists the logged-in user session across restarts
//   • Navigation: named routes + an IndexedStack for the bottom-nav scaffold
//   • All Firestore interactions are replaced with a local MockDb that mirrors
//     the Firestore schema so you can swap it with real `cloud_firestore` calls
//     by replacing each MockDb method with its Firestore equivalent.
//
// Screens implemented
//   Login  →  Register  →  Main scaffold
//     • Home          (pie-chart style progress + stat cards)
//     • Categories    (subjects list with search)
//     • Lectures      (lectures list for a subject)
//     • Quiz          (full exam mode: MCQ, bookmarks, sidebar, summary)
//     • Bookmarks     (accordion list of saved questions)
//     • Profile       (user info + logout)
//
// Required pubspec.yaml additions
//   dependencies:
//     shared_preferences: ^2.3.0
//     provider: ^6.1.2
//
// Everything else uses Flutter SDK only.
// ===========================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_service.dart';

// ---------------------------------------------------------------------------
// ENTRY POINT
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const SMBankApp(),
    ),
  );
}

class SMBankApp extends StatelessWidget {
  const SMBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SM Bank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم StreamBuilder للتعرف على حالة فايربيس (جاري التحقق، مسجل، غير مسجل)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. حالة التحميل: التطبيق يفتح ويتحقق من فايربيس (هنا تظهر شاشة التحميل)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        
        // 2. حالة الدخول: المستخدم مسجل بالفعل
        if (snapshot.hasData) {
          return MainLayout();
        }

        // 3. حالة الخروج: لا يوجد مستخدم مسجل
        return LoginPage();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// THEME
// ---------------------------------------------------------------------------
final _teal600 = const Color(0xFF0D9488);
final _teal700 = const Color(0xFF0F766E);
final _teal50 = const Color(0xFFF0FDFA);
final _teal100 = const Color(0xFFCCFBF1);
final _slate50 = const Color(0xFFF8FAFC);
final _slate100 = const Color(0xFFF1F5F9);
final _slate200 = const Color(0xFFE2E8F0);
final _slate400 = const Color(0xFF94A3B8);
final _slate500 = const Color(0xFF64748B);
final _slate700 = const Color(0xFF334155);
final _slate800 = const Color(0xFF1E293B);
final _slate900 = const Color(0xFF0F172A);
final _emerald50 = const Color(0xFFECFDF5);
final _emerald500 = const Color(0xFF10B981);
final _emerald600 = const Color(0xFF059669);
final _red50 = const Color(0xFFFFF1F2);
final _red500 = const Color(0xFFEF4444);
final _red600 = const Color(0xFFDC2626);
final _amber500 = const Color(0xFFF59E0B);
final _amber50 = const Color(0xFFFFFBEB);

ThemeData get _appTheme => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: _teal600),
      scaffoldBackgroundColor: _slate50,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _slate900,
        titleTextStyle: TextStyle(
          color: _slate900,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String departmentId;
  final String departmentName;
  final String stageId;
  final String stageName;
  final List<AssignedSubject> assignedSubjects;
  UserStats stats;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.departmentId,
    required this.departmentName,
    required this.stageId,
    required this.stageName,
    required this.assignedSubjects,
    required this.stats,
  });
}

class UserStats {
  int totalQuestions;
  int usedQuestions;
  int unusedQuestions;
  UserStats({
    this.totalQuestions = 0,
    this.usedQuestions = 0,
    this.unusedQuestions = 0,
  });
}

class AssignedSubject {
  final String subjectId;
  final String subjectName;
  final String departmentId;
  final String stageId;
  AssignedSubject({
    required this.subjectId,
    required this.subjectName,
    required this.departmentId,
    required this.stageId,
  });
}

class Lecture {
  final String id;
  final String name;
  final int order;
  Lecture({required this.id, required this.name, this.order = 0});
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;
  QuestionOption({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });
}

class Question {
  final String id;
  final String text;
  final List<QuestionOption> options;
  final String lectureId;
  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.lectureId,
  });
}

class QuestionProgress {
  final String? selectedOptionId;
  final bool isCorrect;
  final bool isAnswered;
  QuestionProgress({
    required this.selectedOptionId,
    required this.isCorrect,
    required this.isAnswered,
  });
}

// ---------------------------------------------------------------------------
// MOCK DATABASE (replace with real Firestore calls when integrating)
// ---------------------------------------------------------------------------
class MockDb {
  // Simulated users
  static final Map<String, _MockUser> _users = {
    'demo@student.com': _MockUser(
      uid: 'user_001',
      name: 'Ali Hassan',
      email: 'demo@student.com',
      password: 'demo1234',
      departmentId: 'dept_med',
      departmentName: 'Medicine',
      stageId: 'stage_3',
      stageName: 'Third Year',
      assignedSubjects: [
        AssignedSubject(
          subjectId: 'subj_anatomy',
          subjectName: 'Anatomy',
          departmentId: 'dept_med',
          stageId: 'stage_3',
        ),
        AssignedSubject(
          subjectId: 'subj_physio',
          subjectName: 'Physiology',
          departmentId: 'dept_med',
          stageId: 'stage_3',
        ),
        AssignedSubject(
          subjectId: 'subj_biochem',
          subjectName: 'Biochemistry',
          departmentId: 'dept_med',
          stageId: 'stage_3',
        ),
      ],
      stats: UserStats(totalQuestions: 120, usedQuestions: 45, unusedQuestions: 75),
    ),
  };

  static final Map<String, List<Lecture>> _lectures = {
    'subj_anatomy': [
      Lecture(id: 'lec_a1', name: 'Upper Limb', order: 1),
      Lecture(id: 'lec_a2', name: 'Lower Limb', order: 2),
      Lecture(id: 'lec_a3', name: 'Head & Neck', order: 3),
      Lecture(id: 'lec_a4', name: 'Thorax', order: 4),
    ],
    'subj_physio': [
      Lecture(id: 'lec_p1', name: 'Cardiac Physiology', order: 1),
      Lecture(id: 'lec_p2', name: 'Respiratory System', order: 2),
      Lecture(id: 'lec_p3', name: 'Renal Physiology', order: 3),
    ],
    'subj_biochem': [
      Lecture(id: 'lec_b1', name: 'Amino Acids & Proteins', order: 1),
      Lecture(id: 'lec_b2', name: 'Enzymes', order: 2),
      Lecture(id: 'lec_b3', name: 'Carbohydrate Metabolism', order: 3),
    ],
  };

  static final Map<String, List<Question>> _questions = {
    'lec_a1': [
      Question(
        id: 'q_a1_1',
        text: 'Which nerve is responsible for the "claw hand" deformity?',
        lectureId: 'lec_a1',
        options: [
          QuestionOption(id: 'o1', text: 'Median nerve', isCorrect: false, explanation: 'Median nerve injury causes "ape hand" not claw hand.'),
          QuestionOption(id: 'o2', text: 'Ulnar nerve', isCorrect: true, explanation: 'Ulnar nerve injury causes hyperextension at metacarpophalangeal joints and flexion at interphalangeal joints — the classic claw hand.'),
          QuestionOption(id: 'o3', text: 'Radial nerve', isCorrect: false, explanation: 'Radial nerve injury causes "wrist drop", not claw hand.'),
          QuestionOption(id: 'o4', text: 'Musculocutaneous nerve', isCorrect: false, explanation: 'Musculocutaneous nerve injury causes weakness of elbow flexion and forearm supination.'),
        ],
      ),
      Question(
        id: 'q_a1_2',
        text: 'The anatomical snuffbox is bounded by which tendons laterally?',
        lectureId: 'lec_a1',
        options: [
          QuestionOption(id: 'o1', text: 'Extensor pollicis longus and brevis', isCorrect: false, explanation: 'EPL forms the medial boundary (ulnar side) of the snuffbox.'),
          QuestionOption(id: 'o2', text: 'Flexor carpi radialis', isCorrect: false, explanation: 'Flexor carpi radialis is not part of the anatomical snuffbox boundaries.'),
          QuestionOption(id: 'o3', text: 'Abductor pollicis longus and extensor pollicis brevis', isCorrect: true, explanation: 'APL and EPB form the lateral (radial) boundary of the anatomical snuffbox.'),
          QuestionOption(id: 'o4', text: 'Extensor digitorum and extensor indicis', isCorrect: false, explanation: 'These tendons are not boundaries of the anatomical snuffbox.'),
        ],
      ),
      Question(
        id: 'q_a1_3',
        text: 'Which artery is the main supply to the head of the humerus?',
        lectureId: 'lec_a1',
        options: [
          QuestionOption(id: 'o1', text: 'Anterior circumflex humeral artery', isCorrect: true, explanation: 'The anterior circumflex humeral artery (a branch of the axillary artery) is the primary blood supply to the humeral head.'),
          QuestionOption(id: 'o2', text: 'Posterior circumflex humeral artery', isCorrect: false, explanation: 'While it also contributes, the anterior circumflex is considered the primary supply.'),
          QuestionOption(id: 'o3', text: 'Brachial artery', isCorrect: false, explanation: 'The brachial artery supplies the arm, not directly the humeral head.'),
          QuestionOption(id: 'o4', text: 'Subscapular artery', isCorrect: false, explanation: 'The subscapular artery supplies the subscapularis and serratus anterior muscles.'),
        ],
      ),
      Question(
        id: 'q_a1_4',
        text: 'Damage to the long thoracic nerve results in:',
        lectureId: 'lec_a1',
        options: [
          QuestionOption(id: 'o1', text: 'Loss of shoulder abduction', isCorrect: false, explanation: 'Loss of shoulder abduction is due to axillary nerve or suprascapular nerve damage.'),
          QuestionOption(id: 'o2', text: 'Winged scapula', isCorrect: true, explanation: 'The long thoracic nerve supplies serratus anterior. Damage causes medial border of the scapula to protrude — "winged scapula".'),
          QuestionOption(id: 'o3', text: 'Wrist drop', isCorrect: false, explanation: 'Wrist drop results from radial nerve damage (posterior interosseous or radial nerve in the spiral groove).'),
          QuestionOption(id: 'o4', text: 'Loss of elbow flexion', isCorrect: false, explanation: 'Loss of elbow flexion results from musculocutaneous nerve damage.'),
        ],
      ),
      Question(
        id: 'q_a1_5',
        text: 'Which of the following muscles is NOT in the rotator cuff?',
        lectureId: 'lec_a1',
        options: [
          QuestionOption(id: 'o1', text: 'Subscapularis', isCorrect: false, explanation: 'Subscapularis (medial rotation) is part of the rotator cuff — SITS mnemonic.'),
          QuestionOption(id: 'o2', text: 'Infraspinatus', isCorrect: false, explanation: 'Infraspinatus (lateral rotation) is part of the rotator cuff — SITS mnemonic.'),
          QuestionOption(id: 'o3', text: 'Deltoid', isCorrect: true, explanation: 'Deltoid is NOT part of the rotator cuff. The rotator cuff consists of Supraspinatus, Infraspinatus, Teres minor, and Subscapularis (SITS).'),
          QuestionOption(id: 'o4', text: 'Teres minor', isCorrect: false, explanation: 'Teres minor (lateral rotation) is part of the rotator cuff — SITS mnemonic.'),
        ],
      ),
    ],
    'lec_p1': [
      Question(
        id: 'q_p1_1',
        text: 'What is the normal cardiac output at rest for a 70 kg adult?',
        lectureId: 'lec_p1',
        options: [
          QuestionOption(id: 'o1', text: '2–3 L/min', isCorrect: false, explanation: '2–3 L/min is below normal and may indicate heart failure or cardiogenic shock.'),
          QuestionOption(id: 'o2', text: '5–6 L/min', isCorrect: true, explanation: 'Normal resting cardiac output is approximately 5 L/min (stroke volume ~70 mL × heart rate ~70 bpm).'),
          QuestionOption(id: 'o3', text: '8–10 L/min', isCorrect: false, explanation: '8–10 L/min is elevated and may be seen during exercise or in high-output states.'),
          QuestionOption(id: 'o4', text: '12–15 L/min', isCorrect: false, explanation: '12–15 L/min far exceeds normal resting values.'),
        ],
      ),
      Question(
        id: 'q_p1_2',
        text: 'Which component of the cardiac conduction system has the slowest conduction velocity?',
        lectureId: 'lec_p1',
        options: [
          QuestionOption(id: 'o1', text: 'SA node', isCorrect: false, explanation: 'SA node conducts at ~0.05 m/s but sets the pace; it is not the slowest in conduction velocity.'),
          QuestionOption(id: 'o2', text: 'AV node', isCorrect: true, explanation: 'The AV node has the slowest conduction velocity (~0.05 m/s), creating the crucial delay between atrial and ventricular contraction.'),
          QuestionOption(id: 'o3', text: 'Bundle of His', isCorrect: false, explanation: 'The Bundle of His conducts at approximately 1 m/s.'),
          QuestionOption(id: 'o4', text: 'Purkinje fibers', isCorrect: false, explanation: 'Purkinje fibers have the FASTEST conduction velocity (~4 m/s), enabling rapid ventricular activation.'),
        ],
      ),
      Question(
        id: 'q_p1_3',
        text: 'Starling\'s law of the heart states that:',
        lectureId: 'lec_p1',
        options: [
          QuestionOption(id: 'o1', text: 'Heart rate increases as venous return decreases', isCorrect: false, explanation: 'This is incorrect — decreased venous return leads to decreased preload and typically decreased cardiac output.'),
          QuestionOption(id: 'o2', text: 'Stroke volume is independent of end-diastolic volume', isCorrect: false, explanation: 'This is incorrect — Starling\'s law directly relates stroke volume to end-diastolic volume (preload).'),
          QuestionOption(id: 'o3', text: 'The greater the stretch of cardiac muscle, the greater the force of contraction', isCorrect: true, explanation: 'Frank-Starling mechanism: within physiological limits, increased preload (stretch) leads to increased stroke volume due to optimal actin-myosin overlap.'),
          QuestionOption(id: 'o4', text: 'Afterload has no effect on stroke volume', isCorrect: false, explanation: 'Afterload significantly affects stroke volume — increased afterload reduces stroke volume.'),
        ],
      ),
    ],
    'lec_b1': [
      Question(
        id: 'q_b1_1',
        text: 'Which amino acid has an imidazole side chain that acts as a buffer at physiological pH?',
        lectureId: 'lec_b1',
        options: [
          QuestionOption(id: 'o1', text: 'Lysine', isCorrect: false, explanation: 'Lysine has an ε-amino group (pKa ~10.5), too high to act as a physiological buffer.'),
          QuestionOption(id: 'o2', text: 'Arginine', isCorrect: false, explanation: 'Arginine has a guanidinium group (pKa ~12.5), also too high for buffering at pH 7.4.'),
          QuestionOption(id: 'o3', text: 'Histidine', isCorrect: true, explanation: 'Histidine\'s imidazole group has a pKa of ~6.0, allowing it to accept and donate protons near physiological pH (7.4), making it the key buffering amino acid.'),
          QuestionOption(id: 'o4', text: 'Tyrosine', isCorrect: false, explanation: 'Tyrosine has a phenol group (pKa ~10.5), too high for physiological buffering.'),
        ],
      ),
    ],
  };

  // In-memory progress and bookmarks (persists within session)
  static final Map<String, QuestionProgress> _progress = {};
  static final Set<String> _bookmarks = {};

  static Future<UserProfile?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // simulate network
    final mock = _users[email.toLowerCase()];
    if (mock == null || mock.password != password) return null;
    return _buildProfile(mock);
  }

  static Future<UserProfile?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (_users.containsKey(email.toLowerCase())) {
      throw Exception('Email already in use');
    }
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final mock = _MockUser(
      uid: uid,
      name: name,
      email: email,
      password: password,
      departmentId: '',
      departmentName: '',
      stageId: '',
      stageName: '',
      assignedSubjects: [],
      stats: UserStats(totalQuestions: 0, usedQuestions: 0, unusedQuestions: 0),
    );
    _users[email.toLowerCase()] = mock;
    return _buildProfile(mock);
  }

  static UserProfile? getUserByEmail(String email) {
    final mock = _users[email.toLowerCase()];
    if (mock == null) return null;
    return _buildProfile(mock);
  }

  static UserProfile _buildProfile(_MockUser mock) {
    return UserProfile(
      uid: mock.uid,
      name: mock.name,
      email: mock.email,
      departmentId: mock.departmentId,
      departmentName: mock.departmentName,
      stageId: mock.stageId,
      stageName: mock.stageName,
      assignedSubjects: mock.assignedSubjects,
      stats: mock.stats,
    );
  }

  static Future<List<Lecture>> getLectures(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final list = _lectures[subjectId] ?? [];
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  static Future<List<Question>> getQuestions(String lectureId) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return _questions[lectureId] ?? [];
  }

  static Future<Map<String, QuestionProgress>> getUserProgress() async {
    return Map.from(_progress);
  }

  static Future<void> saveProgress(
      String questionId, String? selectedOptionId, bool isCorrect) async {
    _progress[questionId] = QuestionProgress(
      selectedOptionId: selectedOptionId,
      isCorrect: isCorrect,
      isAnswered: true,
    );
    // update mock user stats
    for (final user in _users.values) {
      user.stats.usedQuestions++;
      if (user.stats.unusedQuestions > 0) user.stats.unusedQuestions--;
    }
  }

  static Future<void> deleteProgress(String questionId) async {
    _progress.remove(questionId);
    for (final user in _users.values) {
      if (user.stats.usedQuestions > 0) user.stats.usedQuestions--;
      user.stats.unusedQuestions++;
    }
  }

  static Future<Set<String>> getBookmarks(String uid) async {
    return Set.from(_bookmarks);
  }

  static Future<void> addBookmark(String uid, String questionId) async {
    _bookmarks.add(questionId);
  }

  static Future<void> removeBookmark(String uid, String questionId) async {
    _bookmarks.remove(questionId);
  }

  static Future<List<Question>> getBookmarkedQuestions(String uid) async {
    final ids = _bookmarks;
    final result = <Question>[];
    for (final entry in _questions.entries) {
      for (final q in entry.value) {
        if (ids.contains(q.id)) result.add(q);
      }
    }
    return result;
  }
}

class _MockUser {
  final String uid;
  final String name;
  final String email;
  final String password;
  final String departmentId;
  final String departmentName;
  final String stageId;
  final String stageName;
  final List<AssignedSubject> assignedSubjects;
  final UserStats stats;
  _MockUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.departmentId,
    required this.departmentName,
    required this.stageId,
    required this.stageName,
    required this.assignedSubjects,
    required this.stats,
  });
}

// ---------------------------------------------------------------------------
// APP STATE (ChangeNotifier)
// ---------------------------------------------------------------------------
class AppState extends ChangeNotifier {
  final SharedPreferences _prefs;
  UserProfile? _profile;
  bool _authLoading = true;

  UserProfile? get profile => _profile;
  bool get authLoading => _authLoading;
  bool get isLoggedIn => _profile != null;

  AppState(this._prefs) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final email = _prefs.getString('logged_in_email');
    if (email != null) {
      _profile = MockDb.getUserByEmail(email);
    }
    _authLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final profile = await MockDb.login(email, password);
      if (profile == null) return 'Invalid email or password';
      _profile = profile;
      await _prefs.setString('logged_in_email', email);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final profile = await MockDb.register(name: name, email: email, password: password);
      if (profile == null) return 'Registration failed';
      _profile = profile;
      await _prefs.setString('logged_in_email', email);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> logout() async {
    _profile = null;
    await _prefs.remove('logged_in_email');
    notifyListeners();
  }

  void refreshProfile() {
    if (_profile == null) return;
    _profile = MockDb.getUserByEmail(_profile!.email);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// ROOT APP
// ---------------------------------------------------------------------------
class SmAcademyApp extends StatelessWidget {
  const SmAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SM Academy',
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
      home: const _AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/main': (_) => const MainScaffold(),
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.authLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isLoggedIn) return const MainScaffold();
    return const LoginScreen();
  }
}

// ---------------------------------------------------------------------------
// LOGIN SCREEN
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    // تأكد أن الكلاس AppState يحتوي على دالة login
    final error = await context.read<AppState>().login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // _slate50
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE2E8F0).withOpacity(0.8), // _slate200
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- التعديل الأول: إضافة اللوجو عبر الرابط ---
                  Image.network(
                    'https://pub-6d31ff5e059e478f8519858d135599d5.r2.dev/logo.png',
                    height: 88,
                    fit: BoxFit.contain,
                    // يمكنك إضافة errorBuilder هنا للتعامل مع أخطاء تحميل الصورة إذا أردت
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SM ACADEMY',
                    style: TextStyle(
                      color: Color(0xFF0F766E), // _teal700
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Color(0xFF0F172A), // _slate900
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to continue your studies',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14), // _slate500
                  ),
                  const SizedBox(height: 28),
                  if (_error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2), // _red50
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)), // _red500
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18), // _red600
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)), // _red600
                          ),
                        ],
                      ),
                    ),
                  
                  // افتراض وجود كلاس _FieldLabel مسبقاً (تم إضافته في الملفات الأخرى)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  // افتراض وجود كلاس _InputField مسبقاً
                  _buildInputField(
                    controller: _emailCtrl,
                    hint: 'student@university.edu',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _passCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8), // _slate400
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488), // _teal600
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14)), // _slate500
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          'Register Now',
                          style: TextStyle(
                            color: Color(0xFF0D9488), // _teal600
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // --- التعديل الثاني: تم حذف قسم Demo Hint من هنا بالكامل ---
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لرسم الحقول (مأخوذة من الكود الأساسي إذا لم تكن موجودة كـ Widget منفصل)
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // _slate50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)), // _slate200
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15), // _slate400
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22), // _slate400
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REGISTER SCREEN
// ---------------------------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _obscure = true;

  String? _selectedDepartment;
  String? _selectedStage;

  // --- القوائم وحالة التحميل لبيانات فايربيس ---
  List<String> _departmentsList = [];
  List<String> _stagesList = [];
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _fetchDepartmentsFromFirebase();
  }

  Future<void> _fetchDepartmentsFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('departments').get();
      final fetchedDeps = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      
      if (mounted) {
        setState(() {
          _departmentsList = fetchedDeps;
          _isLoadingDepartments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDepartments = false);
      debugPrint("Error fetching departments: $e");
    }
  }

  Future<void> _fetchStagesFromFirebase(String departmentName) async {
    setState(() {
      _stagesList = [];
      _selectedStage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stages')
          .where('department', isEqualTo: departmentName)
          .get();
          
      final fetchedStages = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      
      if (mounted) {
        setState(() {
          _stagesList = fetchedStages;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stages: $e");
    }
  }

  Future<void> _submit() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    
    if (_selectedDepartment == null || _selectedStage == null) {
      setState(() => _error = 'Please select your department and academic stage');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    
    // تأكد من تمرير المتغيرات الجديدة لدالة register في ملف AppState الخاص بك
    final error = await context.read<AppState>().register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      // _selectedDepartment,
      // _selectedStage,
    );
    
    if (!mounted) return;
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Widget _buildDropdownField({
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
          hint: Row(
            children: [
              Icon(icon, color: Colors.grey.shade400, size: 22),
              const SizedBox(width: 12),
              Text(isLoading ? 'Loading...' : hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
            ],
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: Colors.grey.shade400, size: 22),
                  const SizedBox(width: 12),
                  Text(item, style: const TextStyle(fontSize: 15)),
                ],
              ),
            );
          }).toList(),
          onChanged: isLoading ? null : onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE2E8F0).withOpacity(0.8),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Join our medical learning community',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  if (_error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                      ),
                      child: Text(_error,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                    ),
                  
                  // 1. Full Name
                  _FieldLabel('Full Name'),
                  const SizedBox(height: 6),
                  _InputField(controller: _nameCtrl, hint: 'John Doe', icon: Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  
                  // 2. Email Address
                  _FieldLabel('Email Address'),
                  const SizedBox(height: 6),
                  _InputField(
                    controller: _emailCtrl,
                    hint: 'john@med.edu',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // 3. Department
                  const Align(alignment: Alignment.centerLeft, child: Text('Department', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(height: 6),
                  _buildDropdownField(
                    hint: 'Select Dept',
                    icon: Icons.domain_outlined,
                    value: _selectedDepartment,
                    items: _departmentsList,
                    isLoading: _isLoadingDepartments,
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartment = value;
                      });
                      if (value != null) {
                        _fetchStagesFromFirebase(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 4. Academic Stage
                  const Align(alignment: Alignment.centerLeft, child: Text('Academic Stage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(height: 6),
                  _buildDropdownField(
                    hint: _selectedDepartment == null ? 'Select Dept First' : 'Select Stage',
                    icon: Icons.school_outlined,
                    value: _selectedStage,
                    items: _stagesList,
                    onChanged: (value) {
                      setState(() {
                        _selectedStage = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 5. Password
                  _FieldLabel('Password'),
                  const SizedBox(height: 6),
                  _InputField(
                    controller: _passCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 6. Confirm Password
                  _FieldLabel('Confirm Password'),
                  const SizedBox(height: 6),
                  _InputField(
                    controller: _confirmCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Complete Registration',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN SCAFFOLD (with side nav on wide / bottom nav on mobile)
// ---------------------------------------------------------------------------
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  bool _drawerOpen = false;

  final List<_NavItem> _navItems = const [
    _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    _NavItem('Subjects', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _NavItem('Bookmarks', Icons.bookmark_outline_rounded, Icons.bookmark_rounded),
    _NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const BookmarksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1024;
    return Scaffold(
      body: Row(
        children: [
          // ---- Desktop Sidebar ----
          if (isWide)
            Container(
              width: 240,
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Logo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _teal50,
                      shape: BoxShape.circle,
                      border: Border.all(color: _teal100, width: 2),
                    ),
                    child: Center(
                      child: Text('SM',
                          style: TextStyle(
                              color: _teal700,
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('SM ACADEMY',
                      style: TextStyle(
                          color: _teal700,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 2)),
                  Text('STUDENT PORTAL',
                      style: TextStyle(
                          color: _slate400,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 2)),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _navItems.length,
                      itemBuilder: (_, i) {
                        final active = _selectedIndex == i;
                        return _SidebarNavTile(
                          item: _navItems[i],
                          active: active,
                          onTap: () => setState(() => _selectedIndex = i),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _LogoutTile(),
                  ),
                ],
              ),
            ),
          // ---- Content ----
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
                // Mobile hamburger overlay
                if (!isWide && _drawerOpen)
                  GestureDetector(
                    onTap: () => setState(() => _drawerOpen = false),
                    child: Container(color: Colors.black54),
                  ),
                if (!isWide && _drawerOpen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 240,
                    child: Material(
                      color: Colors.white,
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Text('SM Academy',
                                      style: TextStyle(
                                          color: _teal700,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20)),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.close, color: _slate500),
                                    onPressed: () => setState(() => _drawerOpen = false),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _navItems.length,
                                itemBuilder: (_, i) {
                                  final active = _selectedIndex == i;
                                  return _SidebarNavTile(
                                    item: _navItems[i],
                                    active: active,
                                    onTap: () => setState(() {
                                      _selectedIndex = i;
                                      _drawerOpen = false;
                                    }),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: _LogoutTile(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // Mobile bottom nav
      bottomNavigationBar: isWide
          ? null
          : Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _slate200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (i) {
                  final active = _selectedIndex == i;
                  final item = _navItems[i];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? item.activeIcon : item.icon,
                          color: active ? _teal600 : _slate400,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: active ? _teal600 : _slate400,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
      // Mobile top bar
      appBar: isWide
          ? null
          : AppBar(
              leading: IconButton(
                icon: Icon(Icons.menu_rounded, color: _slate700),
                onPressed: () => setState(() => _drawerOpen = !_drawerOpen),
              ),
              title: Text(
                'SM Academy',
                style: TextStyle(
                    color: _teal600,
                    fontWeight: FontWeight.w900,
                    fontSize: 20),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: _slate200),
              ),
            ),
    );
  }
}

class _NavItem {
  final String name;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.name, this.icon, this.activeIcon);
}

class _SidebarNavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _SidebarNavTile({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? _teal50 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                active ? item.activeIcon : item.icon,
                color: active ? _teal700 : _slate500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                item.name,
                style: TextStyle(
                  color: active ? _teal700 : _slate500,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await context.read<AppState>().logout();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: _slate500, size: 20),
            const SizedBox(width: 12),
            Text('Logout',
                style: TextStyle(color: _slate500, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    if (profile == null) return const SizedBox();
    final stats = profile.stats;
    final used = max(0, stats.usedQuestions);
    final unused = max(0, stats.unusedQuestions);
    final total = max(used + unused, stats.totalQuestions);
    final pct = total > 0 ? (used / total * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${profile.name}',
            style: TextStyle(
                color: _slate900, fontWeight: FontWeight.w800, fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text('Track your progress and keep learning.',
              style: TextStyle(color: _slate500, fontSize: 14)),
          const SizedBox(height: 28),
          // Progress card
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: _teal600, size: 22),
                      const SizedBox(width: 10),
                      Text('Overall Progress',
                          style: TextStyle(
                              color: _slate800,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Donut chart (custom painter)
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: _DonutPainter(
                          used: used.toDouble(),
                          total: total.toDouble(),
                          usedColor: _teal600,
                          unusedColor: _slate200,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pct%',
                                style: TextStyle(
                                    color: _slate900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 32),
                              ),
                              Text('Completed',
                                  style: TextStyle(
                                      color: _slate400,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "You've completed $used out of $total questions. Keep going to master your curriculum!",
                    style: TextStyle(color: _slate500, fontSize: 13, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Legend(color: _teal600, label: 'Used'),
                      const SizedBox(width: 20),
                      _Legend(color: _slate200, label: 'Unused'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stat cards
          _StatCard(
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF3B82F6),
            bg: const Color(0xFFEFF6FF),
            label: 'Total Questions',
            value: '$total',
            desc: 'Available in your curriculum',
          ),
          const SizedBox(height: 10),
          _StatCard(
            icon: Icons.check_circle_outline_rounded,
            color: _teal600,
            bg: _teal50,
            label: 'Used Questions',
            value: '$used',
            desc: 'Questions you have attempted',
          ),
          const SizedBox(height: 10),
          _StatCard(
            icon: Icons.radio_button_unchecked_rounded,
            color: _slate500,
            bg: _slate50,
            label: 'Unused Questions',
            value: '$unused',
            desc: 'Remaining practice material',
          ),
          const SizedBox(height: 28),
          Text('Recent Activity',
              style: TextStyle(
                  color: _slate800, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _slate200, style: BorderStyle.solid),
            ),
            child: Center(
              child: Text(
                'No recent activity found. Start a quiz to see your progress here!',
                style: TextStyle(
                    color: _slate400, fontStyle: FontStyle.italic, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double used;
  final double total;
  final Color usedColor;
  final Color unusedColor;

  _DonutPainter({
    required this.used,
    required this.total,
    required this.usedColor,
    required this.unusedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 20.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - strokeWidth / 2,
    );
    final paintBg = Paint()
      ..color = unusedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, paintBg);

    if (total > 0) {
      final sweep = 2 * pi * (used / total);
      final paintFg = Paint()
        ..color = usedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweep, false, paintFg);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              color: _slate600(), fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  Color _slate600() => const Color(0xFF475569);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final String value;
  final String desc;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.value,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: _slate400,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                Text(value,
                    style: TextStyle(
                        color: _slate900,
                        fontWeight: FontWeight.w900,
                        fontSize: 24)),
                Text(desc,
                    style: TextStyle(color: _slate400, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CATEGORIES / SUBJECTS SCREEN
// ---------------------------------------------------------------------------
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    if (profile == null) return const SizedBox();
    final subjects = profile.assignedSubjects
        .where((s) =>
            s.subjectName.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subjects',
                        style: TextStyle(
                            color: _slate900,
                            fontWeight: FontWeight.w800,
                            fontSize: 26)),
                    const SizedBox(height: 4),
                    Text('Select a subject to view lectures.',
                        style: TextStyle(color: _slate500, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _slate200),
              boxShadow: [BoxShadow(color: _slate200.withOpacity(0.5), blurRadius: 8)],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search subjects...',
                hintStyle: TextStyle(color: _slate400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: _slate400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (profile.assignedSubjects.isEmpty)
            _EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects assigned yet.',
              subtitle: 'Please contact the Admin.',
            )
          else if (subjects.isEmpty)
            _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching subjects found.',
            )
          else
            ...subjects.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SubjectTile(subject: s),
                )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final AssignedSubject subject;
  const _SubjectTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LecturesScreen(subject: subject),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _slate100),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _teal50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_rounded, color: _teal600, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.subjectName,
                        style: TextStyle(
                            color: _slate800,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Medical Subject',
                        style: TextStyle(
                            color: _slate400,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _slate400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LECTURES SCREEN
// ---------------------------------------------------------------------------
class LecturesScreen extends StatefulWidget {
  final AssignedSubject subject;
  const LecturesScreen({super.key, required this.subject});

  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen> {
  List<Lecture>? _lectures;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await MockDb.getLectures(widget.subject.subjectId);
      if (mounted) setState(() => _lectures = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slate50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: _slate500, size: 18),
                    const SizedBox(width: 6),
                    Text('Back to Subjects',
                        style: TextStyle(
                            color: _slate500,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.subject.subjectName,
                  style: TextStyle(
                      color: _slate900,
                      fontWeight: FontWeight.w800,
                      fontSize: 26)),
              const SizedBox(height: 4),
              Text('Select a lecture to start the MCQ session.',
                  style: TextStyle(color: _slate500, fontSize: 14)),
              const SizedBox(height: 28),
              if (_error != null)
                Text(_error!, style: TextStyle(color: _red600))
              else if (_lectures == null)
                Center(
                    child: CircularProgressIndicator(color: _teal600))
              else if (_lectures!.isEmpty)
                _EmptyState(
                  icon: Icons.book_outlined,
                  title: 'No lectures available yet.',
                  subtitle: 'Please check back later.',
                )
              else
                ..._lectures!.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LectureTile(
                        lecture: l,
                        subject: widget.subject,
                      ),
                    )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectureTile extends StatelessWidget {
  final Lecture lecture;
  final AssignedSubject subject;
  const _LectureTile({required this.lecture, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                lectureId: lecture.id,
                lectureName: lecture.name,
                subject: subject,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _slate100),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_circle_outline_rounded,
                    color: _teal600, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(lecture.name,
                    style: TextStyle(
                        color: _slate800,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              Text('Start Quiz',
                  style: TextStyle(
                      color: _slate400,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: _slate400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QUIZ SCREEN
// ---------------------------------------------------------------------------
class QuizScreen extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final AssignedSubject subject;

  const QuizScreen({
    super.key,
    required this.lectureId,
    required this.lectureName,
    required this.subject,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question>? _questions;
  int _currentIndex = 0;
  Map<String, QuestionProgress> _progress = {};
  Map<String, bool> _flagged = {};
  Set<String> _expandedExplanations = {};
  bool _showSidebar = false;
  bool _showSummary = false;
  double _textSize = 18;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = context.read<AppState>().profile;
    if (profile == null) return;

    final questions = await MockDb.getQuestions(widget.lectureId);
    final progress = await MockDb.getUserProgress();
    final bookmarks = await MockDb.getBookmarks(profile.uid);
    final flaggedMap = <String, bool>{};
    for (final id in bookmarks) {
      flaggedMap[id] = true;
    }
    if (mounted) {
      setState(() {
        _questions = questions;
        _progress = progress;
        _flagged = flaggedMap;
      });
    }
    _updateExpandedForIndex(0, progress, questions);
  }

  void _updateExpandedForIndex(
      int idx, Map<String, QuestionProgress> progress, List<Question> questions) {
    if (questions.isEmpty) return;
    final q = questions[idx];
    final qp = progress[q.id];
    if (qp != null && qp.isAnswered && qp.selectedOptionId != null) {
      setState(() => _expandedExplanations = {qp.selectedOptionId!});
    } else {
      setState(() => _expandedExplanations = {});
    }
  }

  Future<void> _handleOptionClick(String optionId, bool isCorrect) async {
    final q = _questions![_currentIndex];
    final qp = _progress[q.id];
    if (qp == null || !qp.isAnswered) {
      await MockDb.saveProgress(q.id, optionId, isCorrect);
      context.read<AppState>().refreshProfile();
      setState(() {
        _progress[q.id] = QuestionProgress(
            selectedOptionId: optionId, isCorrect: isCorrect, isAnswered: true);
        _expandedExplanations = {optionId};
      });
    } else {
      // toggle explanation
      setState(() {
        if (_expandedExplanations.contains(optionId)) {
          _expandedExplanations.remove(optionId);
        } else {
          _expandedExplanations.add(optionId);
        }
      });
    }
  }

  Future<void> _handleShowAnswer() async {
    final q = _questions![_currentIndex];
    final qp = _progress[q.id];
    if (qp == null || !qp.isAnswered) {
      await MockDb.saveProgress(q.id, null, false);
      context.read<AppState>().refreshProfile();
      setState(() {
        _progress[q.id] = QuestionProgress(
            selectedOptionId: null, isCorrect: false, isAnswered: true);
        _expandedExplanations = {};
      });
    }
  }

  Future<void> _handleReset() async {
    final q = _questions![_currentIndex];
    final qp = _progress[q.id];
    if (qp == null || !qp.isAnswered) return;
    await MockDb.deleteProgress(q.id);
    context.read<AppState>().refreshProfile();
    setState(() {
      _progress.remove(q.id);
      _expandedExplanations = {};
    });
  }

  Future<void> _toggleFlag(String questionId) async {
    final profile = context.read<AppState>().profile;
    if (profile == null) return;
    final isFlagged = _flagged[questionId] == true;
    if (isFlagged) {
      await MockDb.removeBookmark(profile.uid, questionId);
    } else {
      await MockDb.addBookmark(profile.uid, questionId);
    }
    setState(() => _flagged[questionId] = !isFlagged);
  }

  void _navigate(int idx) {
    setState(() {
      _currentIndex = idx;
      _showSidebar = false;
    });
    _updateExpandedForIndex(idx, _progress, _questions!);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _teal600),
              const SizedBox(height: 16),
              Text('Preparing your session...',
                  style: TextStyle(
                      color: _slate500, fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    if (_questions!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: _slate50, shape: BoxShape.circle),
                child: Icon(Icons.error_outline_rounded, color: _slate400, size: 40),
              ),
              const SizedBox(height: 20),
              Text('No Questions Found',
                  style: TextStyle(
                      color: _slate800, fontWeight: FontWeight.w800, fontSize: 22)),
              const SizedBox(height: 8),
              Text("This lecture doesn't have any questions yet.",
                  style: TextStyle(color: _slate500)),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions![_currentIndex];
    final qp = _progress[q.id];
    final isAnswered = qp?.isAnswered == true;
    final answered = _progress.values.where((p) => p.isAnswered).length;
    final correct = _progress.values.where((p) => p.isCorrect).length;
    final total = _questions!.length;
    final isFlagged = _flagged[q.id] == true;

    return WillPopScope(
      onWillPop: () async {
        if (_showSummary) {
          setState(() => _showSummary = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ---- Header ----
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: _slate100)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _slate400, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lectureName,
                                style: TextStyle(
                                    color: _slate800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('EXAM MODE',
                                  style: TextStyle(
                                      color: _slate400,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                        // Text size controls
                        Container(
                          decoration: BoxDecoration(
                            color: _slate50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _IconBtn(
                                icon: Icons.text_decrease_rounded,
                                onTap: () => setState(() => _textSize = max(12, _textSize - 2)),
                              ),
                              Container(width: 1, height: 16, color: _slate200),
                              _IconBtn(
                                icon: Icons.text_increase_rounded,
                                onTap: () => setState(() => _textSize = min(28, _textSize + 2)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Bookmark
                        IconButton(
                          icon: Icon(
                            isFlagged
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            color: isFlagged ? _amber500 : _slate400,
                            size: 24,
                          ),
                          onPressed: () => _toggleFlag(q.id),
                        ),
                        // Sidebar toggle
                        IconButton(
                          icon: Icon(Icons.grid_view_rounded, color: _slate400, size: 22),
                          onPressed: () => setState(() => _showSidebar = !_showSidebar),
                        ),
                        // End Exam
                        TextButton(
                          onPressed: () => setState(() => _showSummary = true),
                          style: TextButton.styleFrom(
                            backgroundColor: _red50,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.logout_rounded, color: _red600, size: 14),
                              const SizedBox(width: 4),
                              Text('End',
                                  style: TextStyle(
                                      color: _red600,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ---- Body ----
                  Expanded(
                    child: Row(
                      children: [
                        // Main content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _slate100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Question ${_currentIndex + 1}',
                                        style: TextStyle(
                                            color: _slate500,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isAnswered)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: qp!.isCorrect ? _emerald50 : _red50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              qp.isCorrect
                                                  ? Icons.check_circle_outline_rounded
                                                  : Icons.error_outline_rounded,
                                              color: qp.isCorrect ? _emerald600 : _red600,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              qp.isCorrect ? 'Correct' : 'Incorrect',
                                              style: TextStyle(
                                                  color: qp.isCorrect ? _emerald600 : _red600,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Question text
                                Text(
                                  q.text,
                                  style: TextStyle(
                                    color: _slate900,
                                    fontWeight: FontWeight.w700,
                                    fontSize: _textSize,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Options
                                ...List.generate(q.options.length, (idx) {
                                  final opt = q.options[idx];
                                  final isSelected =
                                      qp?.selectedOptionId == opt.id;
                                  final isExpanded =
                                      _expandedExplanations.contains(opt.id);

                                  Color borderColor = _slate200;
                                  Color bgColor = Colors.white;
                                  double opacity = 1.0;

                                  if (isAnswered) {
                                    if (opt.isCorrect) {
                                      borderColor = _emerald500;
                                      bgColor = _emerald50;
                                    } else if (isSelected && !opt.isCorrect) {
                                      borderColor = _red500;
                                      bgColor = _red50;
                                    } else {
                                      opacity = 0.55;
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _handleOptionClick(
                                              opt.id, opt.isCorrect),
                                          child: AnimatedOpacity(
                                            opacity: opacity,
                                            duration: const Duration(milliseconds: 200),
                                            child: Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius: BorderRadius.circular(18),
                                                border: Border.all(
                                                    color: borderColor, width: 2),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: isAnswered && opt.isCorrect
                                                          ? _emerald600
                                                          : isAnswered &&
                                                                  isSelected &&
                                                                  !opt.isCorrect
                                                              ? _red600
                                                              : _slate100,
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                    ),
                                                    child: Center(
                                                      child: isAnswered && opt.isCorrect
                                                          ? Icon(Icons.check_rounded,
                                                              color: Colors.white, size: 18)
                                                          : isAnswered &&
                                                                  isSelected &&
                                                                  !opt.isCorrect
                                                              ? Icon(Icons.close_rounded,
                                                                  color: Colors.white,
                                                                  size: 18)
                                                              : Text(
                                                                  String.fromCharCode(
                                                                      65 + idx),
                                                                  style: TextStyle(
                                                                      color: _slate500,
                                                                      fontWeight:
                                                                          FontWeight.w900,
                                                                      fontSize: 14),
                                                                ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Text(
                                                      opt.text,
                                                      style: TextStyle(
                                                          color: _slate700,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14,
                                                          height: 1.4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Expandable explanation
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOut,
                                          child: isExpanded
                                              ? Container(
                                                  margin: const EdgeInsets.only(top: 6),
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color: opt.isCorrect
                                                        ? _emerald50
                                                        : _red50,
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    border: Border.all(
                                                      color: opt.isCorrect
                                                          ? _emerald500.withOpacity(0.3)
                                                          : _red500.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            opt.isCorrect
                                                                ? Icons.check_circle_outline_rounded
                                                                : Icons.error_outline_rounded,
                                                            color: opt.isCorrect
                                                                ? _emerald600
                                                                : _red600,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            opt.isCorrect
                                                                ? 'CORRECT EXPLANATION'
                                                                : 'OPTION EXPLANATION',
                                                            style: TextStyle(
                                                              color: opt.isCorrect
                                                                  ? _emerald600
                                                                  : _red600,
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w900,
                                                              letterSpacing: 1.2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        opt.explanation,
                                                        style: TextStyle(
                                                            color: opt.isCorrect
                                                                ? const Color(0xFF065F46)
                                                                : const Color(0xFF7F1D1D),
                                                            fontSize: 13,
                                                            height: 1.5,
                                                            fontWeight: FontWeight.w500),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 20),
                                // Action buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isAnswered
                                            ? _handleReset
                                            : _handleShowAnswer,
                                        icon: Icon(
                                          isAnswered
                                              ? Icons.refresh_rounded
                                              : Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          isAnswered ? 'Reset' : 'Show Answer',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _slate700,
                                          side: BorderSide(color: _slate200, width: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _currentIndex < total - 1
                                            ? () => _navigate(_currentIndex + 1)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _slate900,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18)),
                                        ),
                                        child: Text(
                                          _currentIndex == total - 1
                                              ? 'Last Question'
                                              : 'Next Question',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                        // Sidebar (desktop always visible)
                        if (MediaQuery.of(context).size.width >= 1024)
                          _QuizSidebar(
                            questions: _questions!,
                            progress: _progress,
                            currentIndex: _currentIndex,
                            answeredCount: answered,
                            onNavigate: _navigate,
                            onEndExam: () => setState(() => _showSummary = true),
                          ),
                      ],
                    ),
                  ),
                  // ---- Footer ----
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _slate100)),
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _currentIndex > 0
                              ? () => _navigate(_currentIndex - 1)
                              : null,
                          icon: Icon(Icons.chevron_left_rounded, size: 20,
                              color: _currentIndex > 0 ? _slate600() : _slate200),
                          label: Text('Previous',
                              style: TextStyle(
                                  color: _currentIndex > 0 ? _slate600() : _slate200,
                                  fontWeight: FontWeight.w800)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                        const Spacer(),
                        // Progress
                        Text(
                          '${_currentIndex + 1} / $total',
                          style: TextStyle(
                              color: _slate400,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _currentIndex < total - 1
                              ? () => _navigate(_currentIndex + 1)
                              : null,
                          icon: const SizedBox.shrink(),
                          label: Row(
                            children: [
                              Text('Next',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 20),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Mobile sidebar overlay
              if (_showSidebar && MediaQuery.of(context).size.width < 1024)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showSidebar = false),
                          child: Container(color: Colors.black38),
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: _QuizSidebar(
                          questions: _questions!,
                          progress: _progress,
                          currentIndex: _currentIndex,
                          answeredCount: answered,
                          onNavigate: _navigate,
                          onEndExam: () => setState(() => _showSummary = true),
                        ),
                      ),
                    ],
                  ),
                ),
              // Summary modal
              if (_showSummary)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showSummary = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {}, // don't close when tapping inside
                          child: _SummaryModal(
                            total: total,
                            correct: correct,
                            onReturn: () => Navigator.pop(context),
                            onReview: () => setState(() => _showSummary = false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _slate600() => const Color(0xFF475569);
}

class _QuizSidebar extends StatelessWidget {
  final List<Question> questions;
  final Map<String, QuestionProgress> progress;
  final int currentIndex;
  final int answeredCount;
  final void Function(int) onNavigate;
  final VoidCallback onEndExam;

  const _QuizSidebar({
    required this.questions,
    required this.progress,
    required this.currentIndex,
    required this.answeredCount,
    required this.onNavigate,
    required this.onEndExam,
  });

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final pct = total > 0 ? answeredCount / total : 0.0;

    return Container(
      width: 280,
      color: _slate50,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EXAM PROGRESS',
                    style: TextStyle(
                        color: _slate400,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('$answeredCount of $total Answered',
                        style: TextStyle(
                            color: _slate700, fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(
                            color: _teal600, fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: _slate200,
                    color: _teal600,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: questions.length,
              itemBuilder: (_, idx) {
                final q = questions[idx];
                final qp = progress[q.id];
                final isActive = idx == currentIndex;
                Color bg = Colors.white;
                Color fg = _slate400;
                Color border = _slate200;

                if (qp?.isAnswered == true) {
                  bg = qp!.isCorrect ? _emerald500 : _red500;
                  fg = Colors.white;
                  border = bg;
                }

                return GestureDetector(
                  onTap: () => onNavigate(idx),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? _slate900 : border,
                        width: isActive ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w900,
                            fontSize: 12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEndExam,
                icon: Icon(Icons.logout_rounded, size: 16),
                label: const Text('End Exam',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryModal extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onReturn;
  final VoidCallback onReview;

  const _SummaryModal({
    required this.total,
    required this.correct,
    required this.onReturn,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final score = total > 0 ? (correct / total * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 40),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 5, color: _teal600),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _teal50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: _teal600, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text('Exam Summary',
                      style: TextStyle(
                          color: _slate900,
                          fontWeight: FontWeight.w900,
                          fontSize: 22)),
                  const SizedBox(height: 4),
                  Text('Great job completing this session!',
                      style: TextStyle(color: _slate500, fontSize: 13)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'SCORE',
                          value: '$score%',
                          valueColor: _teal600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'CORRECT',
                          value: '$correct/$total',
                          valueColor: _slate900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slate900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Return to Lectures',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onReview,
                      child: Text('Review Answers',
                          style: TextStyle(
                              color: _slate500, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryCard({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: _slate400, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontWeight: FontWeight.w900, fontSize: 22)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOOKMARKS SCREEN
// ---------------------------------------------------------------------------
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Question>? _questions;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = context.read<AppState>().profile;
    if (profile == null) return;
    final q = await MockDb.getBookmarkedQuestions(profile.uid);
    if (mounted) setState(() => _questions = q);
  }

  Future<void> _remove(String questionId) async {
    final profile = context.read<AppState>().profile;
    if (profile == null) return;
    await MockDb.removeBookmark(profile.uid, questionId);
    if (mounted) {
      setState(() {
        _questions?.removeWhere((q) => q.id == questionId);
        if (_expandedId == questionId) _expandedId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bookmarks',
              style: TextStyle(
                  color: _slate900, fontWeight: FontWeight.w800, fontSize: 26)),
          const SizedBox(height: 4),
          Text('Your saved questions for quick review.',
              style: TextStyle(color: _slate500, fontSize: 14)),
          const SizedBox(height: 24),
          if (_questions == null)
            Center(child: CircularProgressIndicator(color: _teal600))
          else if (_questions!.isEmpty)
            _EmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: 'No bookmarks yet.',
              subtitle: 'Save questions during quizzes to review them here.',
            )
          else
            ..._questions!.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookmarkAccordion(
                    question: q,
                    isExpanded: _expandedId == q.id,
                    onToggle: () => setState(() =>
                        _expandedId = _expandedId == q.id ? null : q.id),
                    onRemove: () => _remove(q.id),
                  ),
                )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _BookmarkAccordion extends StatelessWidget {
  final Question question;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _BookmarkAccordion({
    required this.question,
    required this.isExpanded,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final correct = question.options.firstWhere(
      (o) => o.isCorrect,
      orElse: () => question.options.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(color: _slate200.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _amber50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bookmark_rounded, color: _amber500, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.text,
                      style: TextStyle(
                          color: _slate800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.4),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: _red500, size: 18),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _slate400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: isExpanded
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _slate100)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Options',
                            style: TextStyle(
                                color: _slate400,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        ...List.generate(question.options.length, (idx) {
                          final opt = question.options[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: opt.isCorrect ? _emerald600 : _slate100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: opt.isCorrect
                                        ? Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                        : Text(
                                            String.fromCharCode(65 + idx),
                                            style: TextStyle(
                                                color: _slate500,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(opt.text,
                                      style: TextStyle(
                                          color: opt.isCorrect ? _emerald600 : _slate600(),
                                          fontWeight: opt.isCorrect
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 13,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _emerald50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _emerald500.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EXPLANATION',
                                  style: TextStyle(
                                      color: _emerald600,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 6),
                              Text(correct.explanation,
                                  style: TextStyle(
                                      color: const Color(0xFF065F46),
                                      fontSize: 12,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _slate600() => const Color(0xFF475569);
}

// ---------------------------------------------------------------------------
// PROFILE SCREEN
// ---------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    if (profile == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _teal100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: _slate200, blurRadius: 16, offset: const Offset(0, 4))
              ],
            ),
            child: Icon(Icons.person_rounded, color: _teal600, size: 46),
          ),
          const SizedBox(height: 14),
          Text(profile.name,
              style: TextStyle(
                  color: _slate900, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 4),
          Text('Medical Student',
              style: TextStyle(color: _slate500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 28),
          // Account Settings card
          _ProfileCard(
            title: 'Account Settings',
            children: [
              _ProfileRow(
                  icon: Icons.person_outline_rounded, label: 'Name', value: profile.name),
              _ProfileRow(
                  icon: Icons.mail_outline_rounded, label: 'Email', value: profile.email),
              _ProfileRow(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: profile.departmentName.isEmpty
                      ? 'Not Assigned'
                      : profile.departmentName),
              _ProfileRow(
                  icon: Icons.school_outlined,
                  label: 'Academic Stage',
                  value: profile.stageName.isEmpty ? 'Not Assigned' : profile.stageName),
            ],
          ),
          const SizedBox(height: 16),
          // Preferences card
          _ProfileCard(
            title: 'Preferences',
            children: [
              _ProfileToggleRow(icon: Icons.notifications_none_rounded, label: 'Notifications'),
              _ProfileToggleRow(icon: Icons.dark_mode_outlined, label: 'Dark Mode'),
              _ProfileRow(icon: Icons.security_outlined, label: 'Privacy & Security', hasChevron: true),
              _ProfileRow(icon: Icons.settings_outlined, label: 'App Settings', hasChevron: true),
            ],
          ),
          const SizedBox(height: 20),
          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<AppState>().logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: Icon(Icons.logout_rounded, color: _red600),
              label: Text('Sign Out',
                  style: TextStyle(color: _red600, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _red500.withOpacity(0.3)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('SM Academy v1.0.4',
              style: TextStyle(
                  color: _slate400,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ProfileCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _slate100),
        boxShadow: [BoxShadow(color: _slate200.withOpacity(0.5), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: _slate100)),
            ),
            child: Row(
              children: [
                Text(title.toUpperCase(),
                    style: TextStyle(
                        color: _slate400,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool hasChevron;
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.value = '',
    this.hasChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _slate50, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _slate500, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(
                        color: _slate400,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Manage' : value,
                  style: TextStyle(
                      color: _slate700, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          if (hasChevron)
            Icon(Icons.chevron_right_rounded, color: _slate300(), size: 20),
        ],
      ),
    );
  }

  Color _slate300() => const Color(0xFFCBD5E1);
}

class _ProfileToggleRow extends StatefulWidget {
  final IconData icon;
  final String label;
  const _ProfileToggleRow({required this.icon, required this.label});

  @override
  State<_ProfileToggleRow> createState() => _ProfileToggleRowState();
}

class _ProfileToggleRowState extends State<_ProfileToggleRow> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _slate50)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: _slate500, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label.toUpperCase(),
                    style: TextStyle(
                        color: _slate400,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(_on ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                        color: _slate700, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _on = !_on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: _on ? _teal600 : _slate300(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: _on ? 20 : 2,
                    top: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _slate300() => const Color(0xFFCBD5E1);
}

// ---------------------------------------------------------------------------
// SHARED WIDGETS
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(color: _slate200.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: TextStyle(
              color: _slate700, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: _slate900, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _slate400, fontSize: 14),
          prefixIcon: Icon(icon, color: _slate400, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Icon(icon, color: _slate500, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _slate200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: _slate50, shape: BoxShape.circle),
            child: Icon(icon, color: _slate400, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: _slate500, fontWeight: FontWeight.w600, fontSize: 15),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(color: _slate400, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
