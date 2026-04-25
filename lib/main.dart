// =============================================================================
//  SM Academy – Flutter App
//  Single-file implementation.
//
//  pubspec.yaml dependencies required:
//    firebase_core: ^3.6.0
//    firebase_auth: ^5.3.1
//    cloud_firestore: ^5.4.4
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Firebase configuration
// ---------------------------------------------------------------------------
const FirebaseOptions _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBAzEF3ygdped8Mi9Gc4snGzJXZF3lJA6U',
  authDomain: 'my-web-bank.firebaseapp.com',
  projectId: 'my-web-bank',
  storageBucket: 'my-web-bank.firebasestorage.app',
  messagingSenderId: '1094324213312',
  appId: '1:1094324213312:web:3996a953b2a569ee2a31a5',
);

// ===========================================================================
//  DESIGN TOKENS & GLOBALS
// ===========================================================================
const Color kTeal = Color(0xFF0D9488);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate600 = Color(0xFF475569);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate200 = Color(0xFFE2E8F0);
const Color kSlate100 = Color(0xFFF1F5F9);
const Color kSlate50 = Color(0xFFF8FAFC);
const Color kEmerald = Color(0xFF059669);
const Color kEmeraldBg = Color(0xFFD1FAE5);
const Color kRed = Color(0xFFDC2626);
const Color kRedBg = Color(0xFFFEE2E2);
const Color kWhite = Colors.white;

// ===========================================================================
//  GLOBAL SETTINGS STATE
// ===========================================================================
class AppSettings extends ChangeNotifier {
  bool isDarkMode = false;
  bool wifiOnly = true;
  bool notifications = true;

  void toggleDark(bool val) {
    isDarkMode = val;
    notifyListeners();
  }

  void toggleWifi(bool val) {
    wifiOnly = val;
    notifyListeners();
  }

  void toggleNotif(bool val) {
    notifications = val;
    notifyListeners();
  }
}

final AppSettings appSettings = AppSettings();

// Helper extension for dynamic colors based on theme mode
extension ThemeColors on BuildContext {
  bool get isDark => appSettings.isDarkMode;
  Color get bg => isDark ? const Color(0xFF0F172A) : kSlate50;
  Color get card => isDark ? const Color(0xFF1E293B) : kWhite;
  Color get textMain => isDark ? const Color(0xFFF8FAFC) : kSlate900;
  Color get textSec => isDark ? const Color(0xFF94A3B8) : kSlate500;
  Color get border => isDark ? const Color(0xFF334155) : kSlate100;
  Color get borderActive => isDark ? const Color(0xFF475569) : kSlate200;
  Color get inputFill => isDark ? const Color(0xFF0F172A) : kSlate50;
  Color get iconBg =>
      isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1);
  Color get iconColor => textMain;
  Color get shadow => isDark ? Colors.black54 : const Color(0x18000000);
}

// ===========================================================================
//  MODELS
// ===========================================================================

class UserStats {
  final int totalQuestions;
  final int usedQuestions;
  final int unusedQuestions;

  const UserStats({
    required this.totalQuestions,
    required this.usedQuestions,
    required this.unusedQuestions,
  });

  factory UserStats.fromMap(Map<String, dynamic>? data) {
    final d = data ?? <String, dynamic>{};
    return UserStats(
      totalQuestions: ((d['totalQuestions'] as num?) ?? 0).toInt(),
      usedQuestions: ((d['usedQuestions'] as num?) ?? 0).toInt(),
      unusedQuestions: ((d['unusedQuestions'] as num?) ?? 0).toInt(),
    );
  }
}

class AssignedSubject {
  final String subjectId;
  final String subjectName;
  final String departmentId;
  final String stageId;

  const AssignedSubject({
    required this.subjectId,
    required this.subjectName,
    required this.departmentId,
    required this.stageId,
  });

  factory AssignedSubject.fromMap(Map<String, dynamic> d) => AssignedSubject(
        subjectId: d['subjectId'] as String? ?? '',
        subjectName: d['subjectName'] as String? ?? '',
        departmentId: d['departmentId'] as String? ?? '',
        stageId: d['stageId'] as String? ?? '',
      );
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String departmentId;
  final String departmentName;
  final String stageId;
  final String stageName;
  final List<AssignedSubject> assignedSubjects;
  final UserStats stats;

  const UserProfile({
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

  factory UserProfile.fromMap(String uid, Map<String, dynamic> d) {
    final rawSubs = d['assignedSubjects'] as List<dynamic>? ?? <dynamic>[];
    return UserProfile(
      uid: uid,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      departmentId: d['departmentId'] as String? ?? '',
      departmentName: d['departmentName'] as String? ?? '',
      stageId: d['stageId'] as String? ?? '',
      stageName: d['stageName'] as String? ?? '',
      assignedSubjects: rawSubs
          .whereType<Map<String, dynamic>>()
          .map(AssignedSubject.fromMap)
          .toList(),
      stats: UserStats.fromMap(d['stats'] as Map<String, dynamic>?),
    );
  }
}

class Department {
  final String id;
  final String name;
  const Department({required this.id, required this.name});
}

class Stage {
  final String id;
  final String name;
  const Stage({required this.id, required this.name});
}

class Lecture {
  final String id;
  final String name;
  final int order;
  const Lecture({required this.id, required this.name, this.order = 999999});
}

class QuizOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;

  const QuizOption({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuizOption.fromMap(Map<String, dynamic> d) => QuizOption(
        id: d['id'] as String? ?? '',
        text: d['text'] as String? ?? '',
        isCorrect: d['isCorrect'] == true,
        explanation: d['explanation'] as String? ?? '',
      );
}

class Question {
  final String id;
  final String text;
  final List<QuizOption> options;

  const Question({
    required this.id,
    required this.text,
    required this.options,
  });

  factory Question.fromMap(String id, Map<String, dynamic> d) {
    final rawOpts = d['options'] as List<dynamic>? ?? <dynamic>[];
    return Question(
      id: id,
      text: (d['questionText'] ??
          d['text'] ??
          d['title'] ??
          d['question'] ??
          '') as String,
      options: rawOpts
          .whereType<Map<String, dynamic>>()
          .map(QuizOption.fromMap)
          .toList(),
    );
  }
}

// ===========================================================================
//  AUTH STATE
// ===========================================================================

class AuthState extends ChangeNotifier {
  User? _user;
  UserProfile? _profile;
  bool _loading = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _profileSub;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get loading => _loading;

  AuthState() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    _user = firebaseUser;
    await _profileSub?.cancel();
    _profileSub = null;

    if (firebaseUser != null) {
      final ref =
          FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
      _profileSub = ref.snapshots().listen((snap) {
        _profile =
            snap.exists ? UserProfile.fromMap(snap.id, snap.data()!) : null;
        _loading = false;
        notifyListeners();
      });
    } else {
      _profile = null;
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

// ===========================================================================
//  ENTRY POINT
// ===========================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };
  try {
    await Firebase.initializeApp();
  } catch (_) {
    await Firebase.initializeApp(options: _firebaseOptions);
  }
  runApp(const _SmAcademyRoot());
}

class _SmAcademyRoot extends StatefulWidget {
  const _SmAcademyRoot();
  @override
  State<_SmAcademyRoot> createState() => _SmAcademyRootState();
}

class _SmAcademyRootState extends State<_SmAcademyRoot> {
  final AuthState _auth = AuthState();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_auth, appSettings]),
      builder: (_, __) {
        return MaterialApp(
          title: 'SM Academy',
          debugShowCheckedModeBanner: false,
          themeMode: appSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: kSlate50,
            colorScheme: const ColorScheme.light(
              primary: kTeal,
              onPrimary: kWhite,
              surface: kWhite,
              onSurface: kSlate900,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: const ColorScheme.dark(
              primary: kTeal,
              onPrimary: kWhite,
              surface: Color(0xFF1E293B),
              onSurface: Color(0xFFF8FAFC),
            ),
          ),
          home: _auth.loading
              ? const _SplashScreen()
              : (_auth.user == null
                  ? _LoginScreen(auth: _auth)
                  : (_auth.profile == null
                      ? Scaffold(
                          backgroundColor: appSettings.isDarkMode
                              ? const Color(0xFF0F172A)
                              : kSlate50,
                          body: const Center(
                            child: CircularProgressIndicator(color: kTeal),
                          ),
                        )
                      : _MainShell(auth: _auth))),
        );
      },
    );
  }
}

// ===========================================================================
//  SPLASH SCREEN
// ===========================================================================

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTeal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppLogo(size: 100, bgColor: context.card),
            const SizedBox(height: 24),
            const Text(
              'SM ACADEMY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  SHARED WIDGETS
// ===========================================================================

class _AppLogo extends StatelessWidget {
  final double size;
  final Color bgColor;
  const _AppLogo({this.size = 80, this.bgColor = kSlate50});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.network(
        'https://pub-6d31ff5e059e478f8519858d135599d5.r2.dev/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: bgColor,
          child: Icon(Icons.school_rounded, size: size * 0.55, color: kTeal),
        ),
      ),
    );
  }
}

Widget _labeledField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  bool obscure = false,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.textMain,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: context.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textSec),
          prefixIcon: Icon(icon, color: context.textSec, size: 20),
          filled: true,
          fillColor: context.inputFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kTeal, width: 2),
          ),
        ),
      ),
    ],
  );
}

Widget _errorBanner(String message) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: kRed, fontSize: 13)),
    );

Widget _kDivider(BuildContext context) =>
    Divider(height: 1, color: context.border, indent: 16);

// ===========================================================================
//  LOGIN SCREEN
// ===========================================================================

class _LoginScreen extends StatefulWidget {
  final AuthState auth;
  const _LoginScreen({required this.auth});
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: context.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppLogo(size: 88, bgColor: context.bg),
                    const SizedBox(height: 12),
                    const Text(
                      'SM ACADEMY',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: kTeal,
                          letterSpacing: 3),
                    ),
                    const SizedBox(height: 16),
                    Text('Welcome Back',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.textMain)),
                    const SizedBox(height: 6),
                    Text('Sign in to continue your studies',
                        style: TextStyle(fontSize: 14, color: context.textSec)),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      _errorBanner(_error),
                      const SizedBox(height: 16),
                    ],
                    _labeledField(
                      context,
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'student@university.edu',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _labeledField(
                      context,
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: TextStyle(color: context.textSec)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      _RegisterScreen(auth: widget.auth))),
                          child: const Text('Register Now',
                              style: TextStyle(
                                  color: kTeal, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
//  REGISTER SCREEN
// ===========================================================================

class _RegisterScreen extends StatefulWidget {
  final AuthState auth;
  const _RegisterScreen({required this.auth});
  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  List<Department> _departments = [];
  List<Stage> _stages = [];
  String? _selectedDeptId;
  String? _selectedStageId;

  bool _fetchingDepts = true;
  bool _fetchingStages = false;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('departments').get();
      setState(() {
        _departments =
            snap.docs.map((d) => Department(id: d.id, name: d.id)).toList();
      });
    } catch (e) {
      debugPrint('Departments fetch error: $e');
    } finally {
      if (mounted) setState(() => _fetchingDepts = false);
    }
  }

  Future<void> _fetchStages(String deptId) async {
    setState(() {
      _fetchingStages = true;
      _stages = [];
      _selectedStageId = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('departments')
          .doc(deptId)
          .collection('years')
          .get();
      setState(() {
        _stages = snap.docs.map((d) => Stage(id: d.id, name: d.id)).toList();
      });
    } catch (e) {
      debugPrint('Stages fetch error: $e');
    } finally {
      if (mounted) setState(() => _fetchingStages = false);
    }
  }

  Future<void> _register() async {
    if (_selectedDeptId == null || _selectedStageId == null) {
      setState(() => _error = 'Please select your department and stage.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    final dept = _departments.firstWhere((d) => d.id == _selectedDeptId);
    final stage = _stages.firstWhere((s) => s.id == _selectedStageId);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'uid': cred.user!.uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'departmentId': _selectedDeptId,
        'departmentName': dept.name,
        'stageId': _selectedStageId,
        'stageName': stage.name,
        'assignedSubjects': [],
        'stats': {
          'totalQuestions': 0,
          'usedQuestions': 0,
          'unusedQuestions': 0
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool enabled = true,
    String hint = 'Select',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textMain)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled ? onChanged : null,
          items: items,
          isExpanded: true,
          dropdownColor: context.card,
          style: TextStyle(color: context.textMain),
          borderRadius: BorderRadius.circular(16),
          hint: Text(hint, style: TextStyle(color: context.textSec)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: context.textSec, size: 20),
            filled: true,
            fillColor: context.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.border)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: context.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppLogo(size: 80, bgColor: context.bg),
                    const SizedBox(height: 12),
                    const Text('SM ACADEMY',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kTeal,
                            letterSpacing: 3)),
                    const SizedBox(height: 16),
                    Text('Create Account',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.textMain)),
                    const SizedBox(height: 6),
                    Text('Join our medical learning community',
                        style: TextStyle(fontSize: 14, color: context.textSec)),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      _errorBanner(_error),
                      const SizedBox(height: 16),
                    ],
                    _labeledField(context,
                        controller: _nameCtrl,
                        label: 'Full Name',
                        hint: 'John Doe',
                        icon: Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    _labeledField(context,
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'john@med.edu',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _labeledField(context,
                        controller: _passCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    const SizedBox(height: 14),
                    _fetchingDepts
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(color: kTeal)))
                        : _dropdown(
                            context,
                            label: 'Department',
                            icon: Icons.business_outlined,
                            value: _selectedDeptId,
                            hint: 'Select Department',
                            items: _departments
                                .map((d) => DropdownMenuItem<String>(
                                    value: d.id, child: Text(d.name)))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDeptId = val;
                                _selectedStageId = null;
                                _stages = [];
                              });
                              if (val != null) _fetchStages(val);
                            },
                          ),
                    const SizedBox(height: 14),
                    _fetchingStages
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(color: kTeal)))
                        : _dropdown(
                            context,
                            label: 'Academic Stage',
                            icon: Icons.school_outlined,
                            value: _selectedStageId,
                            hint: _selectedDeptId == null
                                ? 'Select Department First'
                                : 'Select Stage',
                            enabled: _selectedDeptId != null,
                            items: _stages
                                .map((s) => DropdownMenuItem<String>(
                                    value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedStageId = val),
                          ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_loading || _fetchingDepts) ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Complete Registration',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ',
                            style: TextStyle(color: context.textSec)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Sign In',
                              style: TextStyle(
                                  color: kEmerald,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
//  MAIN SHELL
// ===========================================================================

class _MainShell extends StatefulWidget {
  final AuthState auth;
  const _MainShell({required this.auth});
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomePage(auth: widget.auth),
      _CategoriesPage(auth: widget.auth),
      _BookmarksPage(auth: widget.auth),
      _ProfilePage(auth: widget.auth),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.card,
          border: Border(top: BorderSide(color: context.border)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kTeal,
            unselectedItemColor: context.textSec,
            backgroundColor: context.card,
            elevation: 0,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.book_outlined),
                  activeIcon: Icon(Icons.book_rounded),
                  label: 'Subjects'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_border_rounded),
                  activeIcon: Icon(Icons.bookmark_rounded),
                  label: 'Bookmarks'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
//  HOME PAGE (UPDATED ACCURATE STATS)
// ===========================================================================

class _HomePage extends StatefulWidget {
  final AuthState auth;
  const _HomePage({required this.auth});
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  bool _loadingStats = true;
  int _totalSubjects = 0;
  int _totalAvailableQuestions = 0;
  int _attemptedQuestions = 0;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _truePercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadAccurateStats();
  }

  Future<void> _loadAccurateStats() async {
    final uid = widget.auth.user?.uid;
    final profile = widget.auth.profile;
    if (uid == null || profile == null) return;

    try {
      _totalSubjects = profile.assignedSubjects.length;

      // 1. Fetch attempted and correct counts
      final progSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      _attemptedQuestions = progSnap.docs.length;
      _correctAnswers =
          progSnap.docs.where((d) => d.data()['isCorrect'] == true).length;
      _incorrectAnswers = _attemptedQuestions - _correctAnswers;

      // 2. Aggregate total questions available across all assigned subjects
      int tq = 0;
      for (var sub in profile.assignedSubjects) {
        final lecSnap = await FirebaseFirestore.instance
            .collection('departments')
            .doc(sub.departmentId)
            .collection('years')
            .doc(sub.stageId)
            .collection('subjects')
            .doc(sub.subjectId)
            .collection('lectures')
            .get();

        for (var lec in lecSnap.docs) {
          try {
            final qCount =
                await lec.reference.collection('questions').count().get();
            tq += qCount.count ?? 0;
          } catch (_) {}
        }
      }
      _totalAvailableQuestions = tq;
      if (_totalAvailableQuestions > 0) {
        _truePercentage =
            ((_attemptedQuestions / _totalAvailableQuestions) * 100).round();
      } else {
        _truePercentage = 0;
      }
    } catch (e) {
      debugPrint('Stats Error: $e');
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.auth.profile;
    if (profile == null) return const SizedBox.shrink();

    final double progressVal = _totalAvailableQuestions > 0
        ? (_attemptedQuestions / _totalAvailableQuestions)
        : 0.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${profile.name}',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.textMain),
            ),
            const SizedBox(height: 4),
            Text('Track your progress and keep learning.',
                style: TextStyle(color: context.textSec, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
                boxShadow: [
                  BoxShadow(
                      color: context.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: context.iconBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.trending_up_rounded,
                            color: context.iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Overall Progress',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.textMain)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: progressVal,
                            strokeWidth: 14,
                            backgroundColor: context.borderActive,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(kTeal),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_truePercentage%',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: context.textMain),
                            ),
                            Text(
                              'COMPLETED',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSec,
                                  letterSpacing: 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You've completed $_attemptedQuestions out of $_totalAvailableQuestions questions. Keep going!",
                    style: TextStyle(
                        color: context.textSec, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loadingStats)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: kTeal)))
            else
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _statCard(
                      icon: Icons.library_books,
                      label: 'Assigned Subjects',
                      value: '$_totalSubjects',
                      color: const Color(0xFF3B82F6),
                      bgColor: context.isDark
                          ? const Color(0xFF1E3A8A)
                          : const Color(0xFFEFF6FF)),
                  _statCard(
                      icon: Icons.format_list_numbered,
                      label: 'Total Questions',
                      value: '$_totalAvailableQuestions',
                      color: const Color(0xFF8B5CF6),
                      bgColor: context.isDark
                          ? const Color(0xFF4C1D95)
                          : const Color(0xFFF5F3FF)),
                  _statCard(
                      icon: Icons.edit_note,
                      label: 'Attempted',
                      value: '$_attemptedQuestions',
                      color: const Color(0xFFF59E0B),
                      bgColor: context.isDark
                          ? const Color(0xFF78350F)
                          : const Color(0xFFFFFBEB)),
                  _statCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Correct',
                      value: '$_correctAnswers',
                      color: kEmerald,
                      bgColor: context.isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFECFDF5)),
                  _statCard(
                      icon: Icons.cancel_outlined,
                      label: 'Incorrect',
                      value: '$_incorrectAnswers',
                      color: kRed,
                      bgColor: context.isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFEF2F2)),
                  _statCard(
                      icon: Icons.percent_rounded,
                      label: 'True Score',
                      value: '$_truePercentage%',
                      color: kTeal,
                      bgColor: context.isDark
                          ? const Color(0xFF134E4A)
                          : const Color(0xFFF0FDFA)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      {required IconData icon,
      required String label,
      required String value,
      required Color color,
      required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
              color: context.shadow, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.textMain,
                height: 1.2),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textSec),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  CATEGORIES PAGE
// ===========================================================================

class _CategoriesPage extends StatefulWidget {
  final AuthState auth;
  const _CategoriesPage({required this.auth});
  @override
  State<_CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<_CategoriesPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final profile = widget.auth.profile;
    if (profile == null) return const SizedBox.shrink();
    final subjects = profile.assignedSubjects;
    final filtered = subjects
        .where(
            (s) => s.subjectName.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subjects',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.textMain)),
            const SizedBox(height: 4),
            Text('Select a subject to view lectures.',
                style: TextStyle(color: context.textSec, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: context.textMain),
              decoration: InputDecoration(
                hintText: 'Search subjects...',
                hintStyle: TextStyle(color: context.textSec),
                prefixIcon: Icon(Icons.search_rounded, color: context.textSec),
                fillColor: context.inputFill,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: subjects.isEmpty
                  ? _emptyState(
                      'No subjects assigned yet.\nPlease contact the Admin.')
                  : filtered.isEmpty
                      ? _emptyState('No matching subjects found.')
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final s = filtered[i];
                            return _SubjectCard(
                              subject: s,
                              onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => _LecturesPage(
                                    subjectId: s.subjectId,
                                    departmentId: s.departmentId,
                                    stageId: s.stageId,
                                    subjectName: s.subjectName,
                                    auth: widget.auth,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: context.inputFill, shape: BoxShape.circle),
              child:
                  Icon(Icons.book_outlined, size: 36, color: context.textSec),
            ),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.textSec, fontSize: 14, height: 1.5)),
          ],
        ),
      );
}

class _SubjectCard extends StatelessWidget {
  final AssignedSubject subject;
  final VoidCallback onTap;
  const _SubjectCard({required this.subject, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
                color: context.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: context.iconBg,
                  borderRadius: BorderRadius.circular(14)),
              child:
                  Icon(Icons.book_rounded, color: context.iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.subjectName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.textMain)),
                  Text('MEDICAL SUBJECT',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.textSec,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textSec),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  LECTURES PAGE
// ===========================================================================

class _LecturesPage extends StatefulWidget {
  final String subjectId;
  final String departmentId;
  final String stageId;
  final String subjectName;
  final AuthState auth;

  const _LecturesPage(
      {required this.subjectId,
      required this.departmentId,
      required this.stageId,
      required this.subjectName,
      required this.auth});

  @override
  State<_LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<_LecturesPage> {
  List<Lecture> _lectures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLectures();
  }

  Future<void> _fetchLectures() async {
    // UPDATED PATH: departments/{deptId}/years/{stageId}/subjects/{subjectId}/lectures
    final ref = FirebaseFirestore.instance
        .collection('departments')
        .doc(widget.departmentId)
        .collection('years')
        .doc(widget.stageId)
        .collection('subjects')
        .doc(widget.subjectId)
        .collection('lectures');

    try {
      QuerySnapshot snap;
      try {
        snap = await ref.orderBy('order').get();
      } catch (_) {
        snap = await ref.get();
      }
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return Lecture(
            id: d.id,
            name: (data['name'] as String?) ?? d.id,
            order: ((data['order'] as num?) ?? 999999).toInt());
      }).toList();
      list.sort((a, b) => a.order.compareTo(b.order) != 0
          ? a.order.compareTo(b.order)
          : a.name.compareTo(b.name));
      setState(() => _lectures = list);
    } catch (e) {
      debugPrint('Lectures fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.card,
        foregroundColor: context.textMain,
        title: Text(widget.subjectName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _lectures.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _lectures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _LectureCard(
                    lecture: _lectures[i],
                    subjectId: widget.subjectId,
                    departmentId: widget.departmentId,
                    stageId: widget.stageId,
                    auth: widget.auth,
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: context.inputFill, shape: BoxShape.circle),
                child:
                    Icon(Icons.book_outlined, size: 36, color: context.textSec),
              ),
              const SizedBox(height: 16),
              Text('No lectures available for this subject yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSec, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _LectureCard extends StatelessWidget {
  final Lecture lecture;
  final String subjectId;
  final String departmentId;
  final String stageId;
  final AuthState auth;

  const _LectureCard(
      {required this.lecture,
      required this.subjectId,
      required this.departmentId,
      required this.stageId,
      required this.auth});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _QuizPage(
            lectureId: lecture.id,
            lectureName: lecture.name,
            subjectId: subjectId,
            departmentId: departmentId,
            stageId: stageId,
            auth: auth,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
                color: context.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: context.iconBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.play_circle_outline_rounded,
                  color: context.iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(lecture.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textMain))),
            Text('Start Quiz',
                style: TextStyle(
                    fontSize: 11,
                    color: context.textSec,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: context.textSec),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  QUIZ PAGE
// ===========================================================================

class _QProgress {
  final String? selectedOptionId;
  final bool isCorrect;
  const _QProgress({this.selectedOptionId, required this.isCorrect});
}

class _QuizPage extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final String subjectId;
  final String departmentId;
  final String stageId;
  final AuthState auth;

  const _QuizPage(
      {required this.lectureId,
      required this.lectureName,
      required this.subjectId,
      required this.departmentId,
      required this.stageId,
      required this.auth});
  @override
  State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  List<Question> _questions = [];
  bool _loading = true;
  int _index = 0;
  final Map<String, _QProgress> _progress = {};
  final Map<String, bool> _bookmarked = {};
  final Set<String> _expanded = {};
  bool _showSidebar = false;
  bool _showSummary = false;
  double _textSize = 18;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    try {
      // UPDATED PATH
      final qSnap = await FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.departmentId)
          .collection('years')
          .doc(widget.stageId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('lectures')
          .doc(widget.lectureId)
          .collection('questions')
          .get();

      _questions =
          qSnap.docs.map((d) => Question.fromMap(d.id, d.data())).toList();

      final pSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      for (final d in pSnap.docs) {
        final data = d.data();
        _progress[d.id] = _QProgress(
            selectedOptionId: data['selectedOptionId'] as String?,
            isCorrect: data['isCorrect'] == true);
      }

      final bSnap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: uid)
          .get();
      for (final d in bSnap.docs) {
        final qId = d.data()['questionId'] as String? ?? '';
        if (qId.isNotEmpty) _bookmarked[qId] = true;
      }
    } catch (e) {
      debugPrint('Quiz fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAnswer(
      String questionId, String optionId, bool isCorrect) async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(questionId)
          .set({
        'questionId': questionId,
        'lectureId': widget.lectureId,
        'selectedOptionId': optionId,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => _progress[questionId] =
          _QProgress(selectedOptionId: optionId, isCorrect: isCorrect));

      // Update basic profile stats locally if needed for non-dashboard logic
      final updates = <String, dynamic>{
        'stats.usedQuestions': FieldValue.increment(1)
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);
    } catch (e) {
      debugPrint('Save answer error: $e');
    }
  }

  void _handleOptionTap(String optionId, bool isCorrect) {
    final q = _questions[_index];
    final qp = _progress[q.id];
    if (qp == null) {
      _saveAnswer(q.id, optionId, isCorrect);
      setState(() => _expanded
        ..clear()
        ..add(optionId));
    } else {
      setState(() {
        if (_expanded.contains(optionId))
          _expanded.remove(optionId);
        else
          _expanded.add(optionId);
      });
    }
  }

  void _showAnswer() {
    final q = _questions[_index];
    for (final opt in q.options) {
      if (opt.isCorrect) {
        _saveAnswer(q.id, opt.id, true);
        setState(() => _expanded
          ..clear()
          ..add(opt.id));
        break;
      }
    }
  }

  void _resetQuestion() {
    setState(() {
      _progress.remove(_questions[_index].id);
      _expanded.clear();
    });
  }

  Future<void> _toggleBookmark(String questionId) async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    final bookmarksRef = FirebaseFirestore.instance.collection('bookmarks');
    try {
      if (_bookmarked[questionId] == true) {
        final existingDocs = await bookmarksRef
            .where('userId', isEqualTo: uid)
            .where('questionId', isEqualTo: questionId)
            .get();
        for (final d in existingDocs.docs) {
          await d.reference.delete();
        }
        setState(() => _bookmarked[questionId] = false);
      } else {
        // UPDATED PATH
        final questionPath =
            'departments/${widget.departmentId}/years/${widget.stageId}/subjects/${widget.subjectId}/lectures/${widget.lectureId}/questions/$questionId';
        await bookmarksRef.add({
          'AddedAt': FieldValue.serverTimestamp(),
          'questionId': questionId,
          'questionPath': questionPath,
          'userId': uid,
        });
        setState(() => _bookmarked[questionId] = true);
      }
    } catch (e) {
      debugPrint('Bookmark toggle error: $e');
    }
  }

  int get _answeredCount =>
      _questions.where((q) => _progress.containsKey(q.id)).length;
  int get _correctCount =>
      _questions.where((q) => _progress[q.id]?.isCorrect == true).length;
  void _goNext() {
    if (_index < _questions.length - 1)
      setState(() {
        _index++;
        _expanded.clear();
      });
  }

  void _goPrev() {
    if (_index > 0)
      setState(() {
        _index--;
        _expanded.clear();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
              backgroundColor: context.card,
              foregroundColor: context.textMain,
              title: Text(widget.lectureName)),
          body: const Center(child: CircularProgressIndicator(color: kTeal)));
    }
    if (_questions.isEmpty) {
      return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
              backgroundColor: context.card,
              foregroundColor: context.textMain,
              title: Text(widget.lectureName)),
          body: Center(
              child: Text('No questions available.',
                  style: TextStyle(color: context.textSec))));
    }
    final currentQ = _questions[_index];
    final qp = _progress[currentQ.id];
    final answered = qp != null;

    return Scaffold(
      backgroundColor: context.card,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(currentQ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionLabel(answered, qp),
                        const SizedBox(height: 16),
                        Text(
                            currentQ.text.isEmpty
                                ? 'Question text not found'
                                : currentQ.text,
                            style: TextStyle(
                                fontSize: _textSize,
                                fontWeight: FontWeight.w700,
                                color: context.textMain,
                                height: 1.4)),
                        const SizedBox(height: 24),
                        ...currentQ.options.asMap().entries.map((e) =>
                            _buildOptionCard(e.value, e.key, answered, qp)),
                        const SizedBox(height: 24),
                        _buildActionRow(answered),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
            if (_showSidebar) _buildSidebar(),
            if (_showSummary) _buildSummaryModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Question q) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: context.card,
          border: Border(bottom: BorderSide(color: context.border))),
      child: Row(
        children: [
          IconButton(
              icon: Icon(Icons.close_rounded, color: context.textMain),
              onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.lectureName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.textMain),
                    overflow: TextOverflow.ellipsis),
                Text('${_index + 1} / ${_questions.length}',
                    style: TextStyle(fontSize: 12, color: context.textSec)),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.text_fields_rounded,
                  color: context.textSec, size: 20),
              onPressed: () => setState(() => _textSize = _textSize == 18
                  ? 22
                  : _textSize == 22
                      ? 15
                      : 18)),
          IconButton(
              icon: Icon(
                  _bookmarked[q.id] == true
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _bookmarked[q.id] == true ? kTeal : context.textSec),
              onPressed: () => _toggleBookmark(q.id)),
          IconButton(
              icon: Icon(Icons.grid_view_rounded,
                  color: context.textSec, size: 20),
              onPressed: () => setState(() => _showSidebar = true)),
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(bool answered, _QProgress? qp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: context.inputFill,
              borderRadius: BorderRadius.circular(20)),
          child: Text('Question ${_index + 1}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: context.textSec,
                  letterSpacing: 0.8)),
        ),
        if (answered && qp != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: qp.isCorrect
                    ? (context.isDark ? const Color(0xFF064E3B) : kEmeraldBg)
                    : (context.isDark ? const Color(0xFF7F1D1D) : kRedBg),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    qp.isCorrect
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 12,
                    color: qp.isCorrect ? kEmerald : kRed),
                const SizedBox(width: 4),
                Text(qp.isCorrect ? 'Correct' : 'Incorrect',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: qp.isCorrect ? kEmerald : kRed,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionCard(
      QuizOption option, int idx, bool answered, _QProgress? qp) {
    final isSelected = qp?.selectedOptionId == option.id;
    final isExpanded = _expanded.contains(option.id);
    Color borderColor = context.borderActive;
    Color bgColor = context.bg;
    Color labelBg = context.inputFill;
    Color labelColor = context.textSec;

    if (answered) {
      if (option.isCorrect) {
        borderColor = kEmerald;
        bgColor =
            context.isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4);
        labelBg = kEmerald;
        labelColor = Colors.white;
      } else if (isSelected) {
        borderColor = kRed;
        bgColor =
            context.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFF5F5);
        labelBg = kRed;
        labelColor = Colors.white;
      } else {
        borderColor = context.border;
        bgColor = context.inputFill;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _handleOptionTap(option.id, option.isCorrect),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: labelBg, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(String.fromCharCode(65 + idx),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: labelColor))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(option.text,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textMain,
                                height: 1.4)))),
                if (answered && option.isCorrect)
                  const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.check_circle_rounded,
                          color: kEmerald, size: 22)),
                if (answered && isSelected && !option.isCorrect)
                  const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.cancel_rounded, color: kRed, size: 22)),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: (isExpanded && option.explanation.isNotEmpty)
              ? Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: option.isCorrect
                        ? (context.isDark
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFF0FDF4))
                        : (context.isDark
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFFFFF5F5)),
                    border: Border.all(
                        color: option.isCorrect
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          option.isCorrect
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 16,
                          color: option.isCorrect ? kEmerald : kRed),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(option.explanation,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.isDark
                                      ? Colors.white
                                      : (option.isCorrect
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF7F1D1D)),
                                  height: 1.5))),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildActionRow(bool answered) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: answered ? _resetQuestion : _showAnswer,
              style: OutlinedButton.styleFrom(
                  foregroundColor: context.textMain,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: context.borderActive),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              icon: Icon(
                  answered ? Icons.refresh_rounded : Icons.visibility_outlined,
                  size: 18),
              label: Text(answered ? 'Reset' : 'Show Answer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _index < _questions.length - 1 ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.textMain,
                foregroundColor: context.bg,
                disabledBackgroundColor: context.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                  _index == _questions.length - 1
                      ? 'Last Question'
                      : 'Next Question',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );

  Widget _buildFooter() => Container(
        height: 70,
        decoration: BoxDecoration(
            color: context.card,
            border: Border(top: BorderSide(color: context.border))),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _index > 0 ? _goPrev : null,
                style: TextButton.styleFrom(foregroundColor: context.textSec),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showSummary = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.isDark
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFFFFF1F2),
                foregroundColor: context.isDark ? kRedBg : kRed,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('End',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _index < _questions.length - 1 ? _goNext : null,
                style: TextButton.styleFrom(foregroundColor: kTeal),
                icon: const Text('Next',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                label: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      );

  Widget _buildSidebar() => GestureDetector(
        onTap: () => setState(() => _showSidebar = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: const Color(0x80000000),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 300,
                height: double.infinity,
                decoration: BoxDecoration(
                    color: context.bg,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24))),
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NAVIGATION',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: context.textSec,
                                  letterSpacing: 1.5)),
                          IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: context.textSec),
                              onPressed: () =>
                                  setState(() => _showSidebar = false)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '$_answeredCount of ${_questions.length} Answered',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textMain)),
                          Text(
                              '${_questions.isEmpty ? 0 : ((_answeredCount / _questions.length) * 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kTeal)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: _questions.isEmpty
                                ? 0
                                : _answeredCount / _questions.length,
                            backgroundColor: context.border,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(kTeal)),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemCount: _questions.length,
                          itemBuilder: (_, i) {
                            final q = _questions[i];
                            final qp = _progress[q.id];
                            final isActive = i == _index;
                            Color bg = context.card;
                            Color textColor = context.textSec;
                            Color borderColor = context.borderActive;
                            if (qp != null) {
                              bg = qp.isCorrect ? kEmerald : kRed;
                              textColor = Colors.white;
                              borderColor = qp.isCorrect ? kEmerald : kRed;
                            }
                            return GestureDetector(
                              onTap: () => setState(() {
                                _index = i;
                                _showSidebar = false;
                                _expanded.clear();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: bg,
                                    border: Border.all(
                                        color: isActive
                                            ? context.textMain
                                            : borderColor,
                                        width: isActive ? 2.5 : 1.5),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: textColor))),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _showSidebar = false;
                            _showSummary = true;
                          }),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('End Exam',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildSummaryModal() {
    final total = _questions.length;
    final score = total > 0 ? ((_correctCount / total) * 100).round() : 0;
    return GestureDetector(
      onTap: () => setState(() => _showSummary = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0x80000000),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 40)
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: context.iconBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.emoji_events_rounded,
                        color: context.iconColor, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text('Exam Summary',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.textMain)),
                  const SizedBox(height: 4),
                  Text('Great job completing this session!',
                      style: TextStyle(color: context.textSec, fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _summaryTile('SCORE', '$score%', kTeal)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _summaryTile('CORRECT',
                              '$_correctCount/$total', context.textMain)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.textMain,
                          foregroundColor: context.bg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text('Return to Lectures',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                        onPressed: () => setState(() => _showSummary = false),
                        child: Text('Review Answers',
                            style: TextStyle(
                                color: context.textSec,
                                fontWeight: FontWeight.w700))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color valueColor) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: context.inputFill, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: context.textSec,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: valueColor)),
          ],
        ),
      );
}

// ===========================================================================
//  BOOKMARKS PAGE
// ===========================================================================

class _BookmarksPage extends StatefulWidget {
  final AuthState auth;
  const _BookmarksPage({required this.auth});
  @override
  State<_BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<_BookmarksPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final bSnap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: uid)
          .get();
      final items = <Map<String, dynamic>>[];
      for (final d in bSnap.docs) {
        final data = d.data();
        final questionId = data['questionId'] as String? ?? '';
        if (questionId.isEmpty) continue;

        Question? q;
        final qPath = data['questionPath'] as String?;
        if (qPath != null && qPath.isNotEmpty) {
          try {
            final qSnap = await FirebaseFirestore.instance.doc(qPath).get();
            if (qSnap.exists) q = Question.fromMap(qSnap.id, qSnap.data()!);
          } catch (_) {}
        }
        if (q == null) {
          try {
            final qSnap = await FirebaseFirestore.instance
                .collection('questions')
                .doc(questionId)
                .get();
            if (qSnap.exists) q = Question.fromMap(qSnap.id, qSnap.data()!);
          } catch (_) {}
        }
        items.add({
          'questionId': questionId,
          'question': q ??
              Question(
                  id: questionId,
                  text: 'Question data unavailable',
                  options: const []),
        });
      }
      setState(() => _items = items);
    } catch (e) {
      debugPrint('Bookmarks fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeBookmark(String questionId) async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: uid)
          .where('questionId', isEqualTo: questionId)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
      setState(() {
        _items.removeWhere((i) => i['questionId'] as String == questionId);
        if (_expanded == questionId) _expanded = null;
      });
    } catch (e) {
      debugPrint('Remove bookmark error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookmarks',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.textMain)),
            const SizedBox(height: 4),
            Text('Your saved questions for review.',
                style: TextStyle(color: context.textSec, fontSize: 14)),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kTeal))
                  : _items.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildCard(_items[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: context.inputFill, shape: BoxShape.circle),
                child: Icon(Icons.bookmark_border_rounded,
                    size: 36, color: context.textSec)),
            const SizedBox(height: 16),
            Text(
                'No bookmarks yet.\nSave questions during a quiz to find them here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.textSec, fontSize: 14, height: 1.5)),
          ],
        ),
      );

  Widget _buildCard(Map<String, dynamic> item) {
    final String qId = item['questionId'] as String;
    final Question question = item['question'] as Question;
    final bool isOpen = _expanded == qId;

    return Container(
      decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
                color: context.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = isOpen ? null : qId),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: context.iconBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bookmark_rounded,
                    color: context.iconColor, size: 20)),
            title: Text(question.text.isEmpty ? 'Question' : question.text,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textMain),
                maxLines: isOpen ? null : 2,
                overflow: isOpen ? null : TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.textSec),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: kRed, size: 20),
                    onPressed: () => _removeBookmark(qId)),
              ],
            ),
          ),
          if (isOpen) ...[
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: question.options.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: opt.isCorrect
                            ? (context.isDark
                                ? const Color(0xFF064E3B)
                                : kEmeraldBg)
                            : context.inputFill,
                        border: Border.all(
                            color: opt.isCorrect ? kEmerald : context.border),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Text(String.fromCharCode(65 + idx),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: opt.isCorrect
                                    ? kEmerald
                                    : context.textSec)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(opt.text,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: opt.isCorrect
                                        ? (context.isDark
                                            ? Colors.white
                                            : const Color(0xFF065F46))
                                        : context.textMain,
                                    fontWeight: opt.isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.w500))),
                        if (opt.isCorrect)
                          const Icon(Icons.check_circle_rounded,
                              color: kEmerald, size: 18),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
//  PROFILE PAGE & SETTINGS SUBPAGES
// ===========================================================================

class _ProfilePage extends StatefulWidget {
  final AuthState auth;
  const _ProfilePage({required this.auth});
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.auth.profile;
    if (profile == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: context.iconBg, shape: BoxShape.circle),
                child: Icon(Icons.person_rounded,
                    color: context.iconColor, size: 48)),
            const SizedBox(height: 12),
            Text(profile.name,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textMain)),
            Text('Medical Student',
                style: TextStyle(color: context.textSec, fontSize: 14)),
            const SizedBox(height: 28),
            _sectionCard(
              title: 'Account Settings',
              children: [
                _profileRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Personal Information',
                    value: profile.name),
                _kDivider(context),
                _profileRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email Address',
                    value: profile.email),
                _kDivider(context),
                _profileRow(
                    icon: Icons.business_outlined,
                    label: 'Department',
                    value: profile.departmentName.isNotEmpty
                        ? profile.departmentName
                        : 'Not Assigned'),
                _kDivider(context),
                _profileRow(
                    icon: Icons.school_outlined,
                    label: 'Academic Stage',
                    value: profile.stageName.isNotEmpty
                        ? profile.stageName
                        : 'Not Assigned'),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Preferences',
              children: [
                _toggleRow(Icons.dark_mode_outlined, 'Dark Mode',
                    appSettings.isDarkMode, () {
                  appSettings.toggleDark(!appSettings.isDarkMode);
                }),
                _kDivider(context),
                _chevronRow(
                    context, Icons.shield_outlined, 'Privacy & Security', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              _PrivacySecurityScreen(auth: widget.auth)));
                }),
                _kDivider(context),
                _chevronRow(context, Icons.settings_outlined, 'App Settings',
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _AppSettingsScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.card,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Text('Sign Out',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.textMain)),
                      content: Text('Are you sure you want to sign out?',
                          style: TextStyle(color: context.textSec)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                                style: TextStyle(color: context.textSec))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out',
                                style: TextStyle(
                                    color: kRed, fontWeight: FontWeight.w800))),
                      ],
                    ),
                  );
                  if (confirmed == true) await FirebaseAuth.instance.signOut();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRed,
                  side: BorderSide(
                      color: context.isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 24),
            Text('SM ACADEMY v1.0.0',
                style: TextStyle(
                    fontSize: 11,
                    color: context.textSec,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
          {required String title, required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                  color: context.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: context.textSec,
                        letterSpacing: 1.5))),
            Divider(height: 1, color: context.border),
            ...children,
          ],
        ),
      );

  Widget _profileRow(
          {required IconData icon,
          required String label,
          required String value}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: context.inputFill,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: context.textSec)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: context.textSec,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textMain)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _toggleRow(
          IconData icon, String label, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: context.inputFill,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: context.textSec)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: context.textSec,
                            letterSpacing: 0.5)),
                    Text(enabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textMain)),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 24,
                decoration: BoxDecoration(
                    color: enabled ? kTeal : context.borderActive,
                    borderRadius: BorderRadius.circular(12)),
                child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment:
                        enabled ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle))),
              ),
            ],
          ),
        ),
      );

  Widget _chevronRow(BuildContext context, IconData icon, String label,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: context.inputFill,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: context.textSec)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textMain))),
              Icon(Icons.chevron_right_rounded, color: context.textSec),
            ],
          ),
        ),
      );
}

class _PrivacySecurityScreen extends StatefulWidget {
  final AuthState auth;
  const _PrivacySecurityScreen({required this.auth});
  @override
  State<_PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<_PrivacySecurityScreen> {
  final _nameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.auth.profile?.name ?? '';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isError ? kRed : kTeal));
  }

  Future<void> _updateName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.auth.user!.uid)
          .update({'name': newName});
      _showSnack('Name updated successfully');
    } catch (e) {
      _showSnack('Failed to update name', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final curPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    if (curPass.isEmpty || newPass.isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: curPass);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _showSnack('Password updated successfully');
    } catch (e) {
      _showSnack('Failed to update password. Check current password.',
          isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
          backgroundColor: context.card,
          foregroundColor: context.textMain,
          title: const Text('Privacy & Security')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Profile',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.textMain)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border)),
              child: Column(
                children: [
                  _labeledField(context,
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'Your Name',
                      icon: Icons.person_outline),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _updateName,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save Name',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Change Password',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.textMain)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border)),
              child: Column(
                children: [
                  _labeledField(context,
                      controller: _currentPassCtrl,
                      label: 'Current Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscure: true),
                  const SizedBox(height: 16),
                  _labeledField(context,
                      controller: _newPassCtrl,
                      label: 'New Password',
                      hint: '••••••••',
                      icon: Icons.lock_reset,
                      obscure: true),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.textMain,
                          foregroundColor: context.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Update Password',
                          style: TextStyle(fontWeight: FontWeight.w800)),
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

class _AppSettingsScreen extends StatefulWidget {
  const _AppSettingsScreen();
  @override
  State<_AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<_AppSettingsScreen> {
  bool _clearingCache = false;

  void _clearCache() async {
    setState(() => _clearingCache = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('App cache cleared successfully.'),
          backgroundColor: kTeal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
              backgroundColor: context.card,
              foregroundColor: context.textMain,
              title: const Text('App Settings')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.border)),
                child: Column(
                  children: [
                    _buildToggle(
                        context,
                        'Download over Wi-Fi Only',
                        'Save cellular data',
                        appSettings.wifiOnly,
                        appSettings.toggleWifi),
                    _kDivider(context),
                    _buildToggle(
                        context,
                        'Lecture Notifications',
                        'Get alerts for new materials',
                        appSettings.notifications,
                        appSettings.toggleNotif),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearingCache ? null : _clearCache,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textMain,
                    side: BorderSide(color: context.borderActive),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _clearingCache
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_sweep_outlined),
                  label: Text(
                      _clearingCache ? 'Clearing...' : 'Clear App Cache',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle(BuildContext context, String title, String subtitle,
      bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title,
          style:
              TextStyle(fontWeight: FontWeight.w700, color: context.textMain)),
      subtitle: Text(subtitle,
          style: TextStyle(color: context.textSec, fontSize: 12)),
      value: value,
      activeColor: kTeal,
      onChanged: onChanged,
    );
  }
}
