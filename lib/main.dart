// =============================================================================
// SM Academy - Flutter App
// Converted from React/TypeScript web app with all Firebase integrations
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Firebase Options
// ---------------------------------------------------------------------------
const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBAzEF3ygdped8Mi9Gc4snGzJXZF3lJA6U',
  authDomain: 'my-web-bank.firebaseapp.com',
  projectId: 'my-web-bank',
  storageBucket: 'my-web-bank.firebasestorage.app',
  messagingSenderId: '1094324213312',
  appId: '1:1094324213312:web:3996a953b2a569ee2a31a5',
);

// ===========================================================================
// MODELS
// ===========================================================================

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

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final rawSubjects = data['assignedSubjects'] as List<dynamic>? ?? [];
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      departmentId: data['departmentId'] ?? '',
      departmentName: data['departmentName'] ?? '',
      stageId: data['stageId'] ?? '',
      stageName: data['stageName'] ?? '',
      assignedSubjects: rawSubjects
          .map((s) => AssignedSubject.fromMap(s as Map<String, dynamic>))
          .toList(),
      stats: UserStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class UserStats {
  final int totalQuestions;
  final int usedQuestions;
  final int unusedQuestions;

  UserStats({
    required this.totalQuestions,
    required this.usedQuestions,
    required this.unusedQuestions,
  });

  factory UserStats.fromMap(Map<String, dynamic> data) {
    return UserStats(
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      usedQuestions: (data['usedQuestions'] as num?)?.toInt() ?? 0,
      unusedQuestions: (data['unusedQuestions'] as num?)?.toInt() ?? 0,
    );
  }
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

  factory AssignedSubject.fromMap(Map<String, dynamic> data) {
    return AssignedSubject(
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      departmentId: data['departmentId'] ?? '',
      stageId: data['stageId'] ?? '',
    );
  }
}

class Department {
  final String id;
  final String name;
  Department({required this.id, required this.name});
}

class Stage {
  final String id;
  final String name;
  Stage({required this.id, required this.name});
}

class Lecture {
  final String id;
  final String name;
  final int? order;
  Lecture({required this.id, required this.name, this.order});
}

class QuizOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;
  QuizOption({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });
  factory QuizOption.fromMap(Map<String, dynamic> data) {
    return QuizOption(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      isCorrect: data['isCorrect'] == true,
      explanation: data['explanation'] ?? '',
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<QuizOption> options;
  Question({required this.id, required this.text, required this.options});

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    final rawOpts = data['options'] as List<dynamic>? ?? [];
    return Question(
      id: id,
      text: data['questionText'] ??
          data['text'] ??
          data['title'] ??
          data['question'] ??
          '',
      options: rawOpts
          .map((o) => QuizOption.fromMap(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ===========================================================================
// AUTH STATE
// ===========================================================================

class AuthState extends ChangeNotifier {
  User? _user;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  AuthState() {
    _init();
  }

  void _init() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
        _user = u;
        _profileSub?.cancel();
        if (u != null) {
          final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
          _profileSub = ref.snapshots().listen((snap) {
            if (snap.exists && snap.data() != null) {
              _profile = UserProfile.fromMap(snap.id, snap.data()!);
            } else {
              _profile = null;
            }
            _loading = false;
            notifyListeners();
          }, onError: (err) {
            _error = err.toString();
            _loading = false;
            notifyListeners();
          });
        } else {
          _profile = null;
          _loading = false;
          notifyListeners();
        }
      }, onError: (err) {
        _error = err.toString();
        _loading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
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
// COLORS & THEME
// ===========================================================================
const kTeal = Color(0xFF0D9488);
const kSlate900 = Color(0xFF0F172A);
const kSlate700 = Color(0xFF334155);
const kSlate600 = Color(0xFF475569);
const kSlate500 = Color(0xFF64748B);
const kSlate400 = Color(0xFF94A3B8);
const kSlate200 = Color(0xFFE2E8F0);
const kSlate100 = Color(0xFFF1F5F9);
const kSlate50 = Color(0xFFF8FAFC);
const kEmerald = Color(0xFF059669);
const kEmeraldLight = Color(0xFFD1FAE5);
const kRed = Color(0xFFDC2626);
const kRedLight = Color(0xFFFEE2E2);
const kWhite = Colors.white;

ThemeData _buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: kSlate50,
    colorScheme: const ColorScheme.light(
      primary: kTeal,
      onPrimary: kWhite,
      surface: kWhite,
      onSurface: kSlate900,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kWhite,
      foregroundColor: kSlate900,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSlate50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kSlate200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kSlate200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kTeal, width: 2)),
    ),
  );
}

// ===========================================================================
// MAIN ENTRY
// ===========================================================================
void main() async {
  // Ensure framework is ready
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Attempt Firebase Init with error handling to prevent silent hang
    await Firebase.initializeApp(options: _firebaseOptions)
        .timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(const SmAcademyApp());
}

class SmAcademyApp extends StatefulWidget {
  const SmAcademyApp({super.key});
  @override
  State<SmAcademyApp> createState() => _SmAcademyAppState();
}

class _SmAcademyAppState extends State<SmAcademyApp> {
  final AuthState _authState = AuthState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authState,
      builder: (context, _) {
        return MaterialApp(
          title: 'SM Academy',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          // Ensuring home always returns a valid Scaffold to avoid white screen
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_authState.loading) {
      return const SplashScreen();
    }

    if (_authState.error != null) {
      return Scaffold(
        body: Center(child: Text("Initialization Error: ${_authState.error}")),
      );
    }

    if (_authState.user == null) {
      return LoginScreen(authState: _authState);
    }

    if (_authState.profile == null) {
      return const Scaffold(
        backgroundColor: kSlate50,
        body: Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }

    return MainShell(authState: _authState);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTeal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _logoWidget(size: 100, bgColor: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'SM ACADEMY',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// HELPERS
// ===========================================================================
Widget _logoWidget({double size = 80, Color bgColor = kSlate50}) {
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
        child: Icon(Icons.school, size: size * 0.6, color: kTeal),
      ),
    ),
  );
}

Widget _buildTextField({
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
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kSlate700)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: kSlate900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kSlate400),
          prefixIcon: Icon(icon, color: kSlate400, size: 20),
        ),
      ),
    ],
  );
}

// ===========================================================================
// LOGIN SCREEN
// ===========================================================================
class LoginScreen extends StatefulWidget {
  final AuthState authState;
  const LoginScreen({super.key, required this.authState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: kSlate200.withOpacity(0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    _logoWidget(size: 90),
                    const SizedBox(height: 12),
                    const Text('SM ACADEMY',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: kTeal,
                            letterSpacing: 3)),
                    const SizedBox(height: 16),
                    const Text('Welcome Back',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kSlate900)),
                    const SizedBox(height: 6),
                    const Text('Sign in to continue your studies',
                        style: TextStyle(fontSize: 14, color: kSlate500)),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error,
                            style: const TextStyle(color: kRed, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'student@university.edu',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildTextField(
                        controller: _passCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          foregroundColor: kWhite,
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
                                    strokeWidth: 2, color: kWhite))
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(color: kSlate500)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => RegisterScreen(
                                      authState: widget.authState))),
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
// REGISTER SCREEN
// ===========================================================================
class RegisterScreen extends StatefulWidget {
  final AuthState authState;
  const RegisterScreen({super.key, required this.authState});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  List<Department> _departments = [];
  List<Stage> _stages = [];
  String? _selectedDeptId;
  String? _selectedStageId;

  bool _loading = false;
  bool _fetchingDepts = true;
  bool _fetchingStages = false;
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
        _departments = snap.docs
            .map((d) =>
                Department(id: d.id, name: (d.data()['name'] ?? '') as String))
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching departments: $e');
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
          .collection('stages')
          .get();
      setState(() {
        _stages = snap.docs
            .map((d) =>
                Stage(id: d.id, name: (d.data()['name'] ?? '') as String))
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    } finally {
      if (mounted) setState(() => _fetchingStages = false);
    }
  }

  Future<void> _register() async {
    if (_selectedDeptId == null || _selectedStageId == null) {
      setState(() => _error = 'Please select your department and stage');
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
          email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
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
      setState(() => _error = e.message ?? 'Registration failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _dropdown(
      {required String label,
      required IconData icon,
      required String? value,
      required List<DropdownMenuItem<String>> items,
      required void Function(String?) onChanged,
      bool enabled = true,
      String hint = 'Select'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kSlate700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled ? onChanged : null,
          items: items,
          hint: Text(hint, style: const TextStyle(color: kSlate400)),
          decoration: InputDecoration(
              prefixIcon: Icon(icon, color: kSlate400, size: 20)),
          borderRadius: BorderRadius.circular(16),
          isExpanded: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: kSlate200.withOpacity(0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    _logoWidget(size: 80),
                    const SizedBox(height: 12),
                    const Text('SM ACADEMY',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kTeal,
                            letterSpacing: 3)),
                    const SizedBox(height: 16),
                    const Text('Create Account',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kSlate900)),
                    const SizedBox(height: 6),
                    const Text('Join our medical learning community',
                        style: TextStyle(fontSize: 14, color: kSlate500)),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error,
                            style: const TextStyle(color: kRed, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        hint: 'John Doe',
                        icon: Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'john@med.edu',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _buildTextField(
                        controller: _passCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    const SizedBox(height: 14),
                    _fetchingDepts
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(color: kTeal)))
                        : _dropdown(
                            label: 'Department',
                            icon: Icons.business_outlined,
                            value: _selectedDeptId,
                            hint: 'Select Department',
                            items: _departments
                                .map((d) => DropdownMenuItem(
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
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(color: kTeal)))
                        : _dropdown(
                            label: 'Academic Stage',
                            icon: Icons.school_outlined,
                            value: _selectedStageId,
                            hint: _selectedDeptId == null
                                ? 'Select Department First'
                                : 'Select Stage',
                            enabled: _selectedDeptId != null,
                            items: _stages
                                .map((s) => DropdownMenuItem(
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
                            foregroundColor: kWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kWhite))
                            : const Text('Complete Registration',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ',
                            style: TextStyle(color: kSlate500)),
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
// MAIN SHELL
// ===========================================================================
class MainShell extends StatefulWidget {
  final AuthState authState;
  const MainShell({super.key, required this.authState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(authState: widget.authState),
      CategoriesPage(authState: widget.authState),
      BookmarksPage(authState: widget.authState),
      ProfilePage(authState: widget.authState),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate50,
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            color: kWhite, border: Border(top: BorderSide(color: kSlate100))),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kTeal,
            unselectedItemColor: kSlate400,
            backgroundColor: kWhite,
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
// HOME PAGE
// ===========================================================================
class HomePage extends StatelessWidget {
  final AuthState authState;
  const HomePage({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final profile = authState.profile;
    if (profile == null) return const SizedBox();

    final stats = profile.stats;
    final displayUsed = stats.usedQuestions.clamp(0, 9999999);
    final displayUnused = stats.unusedQuestions.clamp(0, 9999999);
    final displayTotal =
        (displayUsed + displayUnused).clamp(stats.totalQuestions, 9999999);
    final pct =
        displayTotal > 0 ? (displayUsed / displayTotal * 100).round() : 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${profile.name}',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kSlate900)),
            const SizedBox(height: 4),
            const Text('Track your progress and keep learning.',
                style: TextStyle(color: kSlate500, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kSlate100),
                boxShadow: [
                  BoxShadow(
                      color: kSlate200.withOpacity(0.4),
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
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.trending_up_rounded,
                              color: kTeal, size: 20)),
                      const SizedBox(width: 12),
                      const Text('Overall Progress',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kSlate900)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 160,
                          width: 160,
                          child: CircularProgressIndicator(
                              value: displayTotal > 0
                                  ? displayUsed / displayTotal
                                  : 0,
                              strokeWidth: 14,
                              backgroundColor: kSlate200,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(kTeal),
                              strokeCap: StrokeCap.round),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$pct%',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: kSlate900)),
                            const Text('Completed',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kSlate400,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      "You've completed $displayUsed out of $displayTotal questions. Keep going to master your curriculum!",
                      style: const TextStyle(
                          color: kSlate500, fontSize: 13, height: 1.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _legendDot(kTeal, 'Used'),
                    const SizedBox(width: 20),
                    _legendDot(kSlate200, 'Unused')
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _statCard(Icons.menu_book_rounded, 'Total Questions', displayTotal,
                'Available in your curriculum',
                color: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB)),
            const SizedBox(height: 12),
            _statCard(Icons.check_circle_outline_rounded, 'Used Questions',
                displayUsed, 'Questions you have attempted',
                color: const Color(0xFFCCFBF1), iconColor: kTeal),
            const SizedBox(height: 12),
            _statCard(Icons.circle_outlined, 'Unused Questions', displayUnused,
                'Remaining practice material',
                color: kSlate50, iconColor: kSlate500),
            const SizedBox(height: 28),
            const Text('Recent Activity',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kSlate900)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kSlate200)),
              child: const Center(
                  child: Text(
                      'No recent activity found.\nStart a quiz to see your progress here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: kSlate400, fontSize: 14, height: 1.5))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: kSlate600))
    ]);
  }

  Widget _statCard(IconData icon, String label, int value, String desc,
      {required Color color, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSlate100),
          boxShadow: [
            BoxShadow(
                color: kSlate200.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kSlate400,
                        letterSpacing: 0.5)),
                Text('$value',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: kSlate900,
                        height: 1.2)),
                Text(desc,
                    style: const TextStyle(fontSize: 11, color: kSlate400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CATEGORIES PAGE
// ===========================================================================
class CategoriesPage extends StatefulWidget {
  final AuthState authState;
  const CategoriesPage({super.key, required this.authState});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final profile = widget.authState.profile;
    if (profile == null) return const SizedBox();
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
            const Text('Subjects',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kSlate900)),
            const SizedBox(height: 4),
            const Text('Select a subject to view lectures.',
                style: TextStyle(color: kSlate500, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                  hintText: 'Search subjects...',
                  prefixIcon: Icon(Icons.search_rounded, color: kSlate400),
                  hintStyle: TextStyle(color: kSlate400),
                  contentPadding: EdgeInsets.symmetric(vertical: 12)),
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
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return _SubjectCard(
                              subject: s,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LecturesPage(
                                          subjectId: s.subjectId,
                                          departmentId: s.departmentId,
                                          stageId: s.stageId,
                                          subjectName: s.subjectName,
                                          authState: widget.authState))),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: kSlate50, shape: BoxShape.circle),
                child: const Icon(Icons.book_outlined,
                    size: 36, color: kSlate400)),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: kSlate500, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
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
            color: kWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kSlate100),
            boxShadow: [
              BoxShadow(
                  color: kSlate200.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(
          children: [
            Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.book_rounded, color: kTeal, size: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.subjectName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kSlate900)),
                  const Text('Medical Subject',
                      style: TextStyle(
                          fontSize: 11,
                          color: kSlate400,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// LECTURES PAGE
// ===========================================================================
class LecturesPage extends StatefulWidget {
  final String subjectId;
  final String departmentId;
  final String stageId;
  final String subjectName;
  final AuthState authState;

  const LecturesPage(
      {super.key,
      required this.subjectId,
      required this.departmentId,
      required this.stageId,
      required this.subjectName,
      required this.authState});

  @override
  State<LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<LecturesPage> {
  List<Lecture> _lectures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLectures();
  }

  Future<void> _fetchLectures() async {
    try {
      final path = FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.departmentId)
          .collection('stages')
          .doc(widget.stageId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('lectures');

      QuerySnapshot snap;
      try {
        snap = await path.orderBy('order').get();
      } catch (_) {
        snap = await path.get();
      }

      final lectures = snap.docs
          .map((d) => Lecture(
              id: d.id,
              name: (d.data() as Map<String, dynamic>)['name'] ?? '',
              order: ((d.data() as Map<String, dynamic>)['order'] as num?)
                  ?.toInt()))
          .toList();
      lectures.sort((a, b) => (a.order ?? 9999).compareTo(b.order ?? 9999));

      setState(() => _lectures = lectures);
    } catch (e) {
      debugPrint('Error fetching lectures: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.subjectName,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _lectures.isEmpty
              ? Center(
                  child: Text('No lectures available.',
                      style: TextStyle(color: kSlate500)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _lectures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final lec = _lectures[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => QuizPage(
                                  lectureId: lec.id,
                                  lectureName: lec.name,
                                  subjectId: widget.subjectId,
                                  departmentId: widget.departmentId,
                                  stageId: widget.stageId,
                                  authState: widget.authState))),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kSlate100)),
                        child: Row(
                          children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFCCFBF1),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: kTeal,
                                    size: 24)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(lec.name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: kSlate900))),
                            const Icon(Icons.chevron_right_rounded,
                                color: kSlate400),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ===========================================================================
// QUIZ PAGE & LOGIC
// ===========================================================================

class _QuestionProgress {
  final String? selectedOptionId;
  final bool isCorrect;
  final bool isAnswered;
  _QuestionProgress(
      {this.selectedOptionId,
      required this.isCorrect,
      required this.isAnswered});
}

class QuizPage extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final String subjectId;
  final String departmentId;
  final String stageId;
  final AuthState authState;

  const QuizPage(
      {super.key,
      required this.lectureId,
      required this.lectureName,
      required this.subjectId,
      required this.departmentId,
      required this.stageId,
      required this.authState});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Question> _questions = [];
  bool _loading = true;
  int _currentIndex = 0;
  final Map<String, _QuestionProgress> _progress = {};
  final Map<String, bool> _flagged = {};
  final Set<String> _expandedExplanations = {};
  bool _showSidebar = false;
  bool _showSummary = false;
  double _textSize = 18;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.departmentId)
          .collection('stages')
          .doc(widget.stageId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('lectures')
          .doc(widget.lectureId)
          .collection('questions')
          .get();
      final questions =
          snap.docs.map((d) => Question.fromMap(d.id, d.data())).toList();
      setState(() => _questions = questions);

      final pSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('progress')
          .get();
      for (final d in pSnap.docs) {
        _progress[d.id] = _QuestionProgress(
            selectedOptionId: d.data()['selectedOptionId'],
            isCorrect: d.data()['isCorrect'] == true,
            isAnswered: true);
      }

      final bSnap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: profile.uid)
          .get();
      for (final d in bSnap.docs) {
        _flagged[d.data()['questionId'] as String] = true;
      }
    } catch (e) {
      debugPrint('Error fetching quiz: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProgress(String qId, String? oId, bool corr) async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('progress')
          .doc(qId)
          .set({
        'questionId': qId,
        'selectedOptionId': oId,
        'isCorrect': corr,
        'timestamp': FieldValue.serverTimestamp()
      });
      setState(() => _progress[qId] = _QuestionProgress(
          selectedOptionId: oId, isCorrect: corr, isAnswered: true));
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(profile.uid);
      final updates = {'stats.usedQuestions': FieldValue.increment(1)};
      if (profile.stats.unusedQuestions > 0)
        updates['stats.unusedQuestions'] = FieldValue.increment(-1);
      await userRef.update(updates);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<void> _toggleBookmark(String qId) async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    final ref = FirebaseFirestore.instance
        .collection('bookmarks')
        .doc('${profile.uid}_$qId');
    try {
      if (_flagged[qId] == true) {
        await ref.delete();
        setState(() => _flagged[qId] = false);
      } else {
        await ref.set({
          'userId': profile.uid,
          'questionId': qId,
          'addedAt': FieldValue.serverTimestamp()
        });
        setState(() => _flagged[qId] = true);
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  void _handleOptionTap(String oId, bool corr) {
    final qId = _questions[_currentIndex].id;
    if (_progress[qId]?.isAnswered != true) {
      _saveProgress(qId, oId, corr);
      setState(() => _expandedExplanations.add(oId));
    } else {
      setState(() => _expandedExplanations.contains(oId)
          ? _expandedExplanations.remove(oId)
          : _expandedExplanations.add(oId));
    }
  }

  void _showAnswer() {
    final q = _questions[_currentIndex];
    final corrOpt = q.options.firstWhere((o) => o.isCorrect);
    if (_progress[q.id]?.isAnswered != true) _saveProgress(q.id, null, true);
    setState(() => _expandedExplanations.add(corrOpt.id));
  }

  void _resetQuestion() {
    setState(() {
      _progress.remove(_questions[_currentIndex].id);
      _expandedExplanations.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(
          appBar: AppBar(title: Text(widget.lectureName)),
          body: const Center(child: CircularProgressIndicator(color: kTeal)));
    if (_questions.isEmpty)
      return Scaffold(
          appBar: AppBar(title: Text(widget.lectureName)),
          body: const Center(child: Text('No questions available.')));

    final q = _questions[_currentIndex];
    final p = _progress[q.id];
    final ans = p?.isAnswered == true;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _quizHeader(q, ans, p),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text,
                        style: TextStyle(
                            fontSize: _textSize,
                            fontWeight: FontWeight.w700,
                            color: kSlate900,
                            height: 1.4)),
                    const SizedBox(height: 24),
                    ...q.options
                        .asMap()
                        .entries
                        .map((e) => _buildOptionCard(e.value, e.key, ans, p)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: ans ? _resetQuestion : _showAnswer,
                              icon:
                                  Icon(ans ? Icons.refresh : Icons.visibility),
                              label: Text(ans ? 'Reset' : 'Show Answer'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: _currentIndex < _questions.length - 1
                                  ? () => setState(() => _currentIndex++)
                                  : null,
                              child: Text(_currentIndex == _questions.length - 1
                                  ? 'Last Question'
                                  : 'Next Question'))),
                    ]),
                  ]),
            )),
            _quizFooter(),
          ]),
          if (_showSidebar) _buildSidebar(),
          if (_showSummary) _buildSummaryModal(),
        ]),
      ),
    );
  }

  Widget _quizHeader(Question q, bool ans, _QuestionProgress? p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          color: kWhite, border: Border(bottom: BorderSide(color: kSlate100))),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        Expanded(
            child: Text(widget.lectureName,
                style: const TextStyle(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis)),
        IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () =>
                setState(() => _textSize = _textSize == 18 ? 22 : 18)),
        IconButton(
            icon: Icon(
                _flagged[q.id] == true ? Icons.bookmark : Icons.bookmark_border,
                color: _flagged[q.id] == true ? kTeal : kSlate400),
            onPressed: () => _toggleBookmark(q.id)),
        IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () => setState(() => _showSidebar = true)),
      ]),
    );
  }

  Widget _buildOptionCard(
      QuizOption opt, int idx, bool ans, _QuestionProgress? p) {
    final sel = p?.selectedOptionId == opt.id;
    final exp = _expandedExplanations.contains(opt.id);
    Color border = kSlate200;
    Color bg = kWhite;
    if (ans) {
      if (opt.isCorrect) {
        border = kEmerald;
        bg = const Color(0xFFF0FDF4);
      } else if (sel) {
        border = kRed;
        bg = const Color(0xFFFFF5F5);
      }
    }
    return Column(children: [
      GestureDetector(
        onTap: () => _handleOptionTap(opt.id, opt.isCorrect),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            CircleAvatar(
                radius: 14,
                backgroundColor: kSlate100,
                child: Text(String.fromCharCode(65 + idx),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: kSlate400))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(opt.text,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
      if (exp && opt.explanation.isNotEmpty)
        Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: kSlate50, borderRadius: BorderRadius.circular(12)),
            child: Text(opt.explanation,
                style: const TextStyle(fontSize: 13, height: 1.5))),
    ]);
  }

  Widget _quizFooter() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
          color: kWhite, border: Border(top: BorderSide(color: kSlate100))),
      child: Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: _currentIndex > 0
                    ? () => setState(() => _currentIndex--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'))),
        ElevatedButton(
            onPressed: () => setState(() => _showSummary = true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kRedLight, foregroundColor: kRed),
            child: const Text('End')),
        Expanded(
            child: TextButton.icon(
                onPressed: _currentIndex < _questions.length - 1
                    ? () => setState(() => _currentIndex++)
                    : null,
                icon: const Text('Next'),
                label: const Icon(Icons.chevron_right))),
      ]),
    );
  }

  Widget _buildSidebar() {
    return GestureDetector(
      onTap: () => setState(() => _showSidebar = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 300,
            color: kWhite,
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Column(children: [
                const Text('Questions',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: _questions.length,
                    itemBuilder: (context, i) {
                      final done =
                          _progress[_questions[i].id]?.isAnswered == true;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _currentIndex = i;
                          _showSidebar = false;
                        }),
                        child: Container(
                            decoration: BoxDecoration(
                                color: done ? kTeal : kSlate100,
                                borderRadius: BorderRadius.circular(8)),
                            child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        color: done ? kWhite : kSlate900)))),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryModal() {
    final correctCount =
        _questions.where((q) => _progress[q.id]?.isCorrect == true).length;
    final score = _questions.isEmpty
        ? 0
        : (correctCount / _questions.length * 100).round();
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: kWhite, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Result',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Text('$score%',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w900, color: kTeal)),
            Text('$correctCount / ${_questions.length} Correct'),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish'))),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// BOOKMARKS PAGE
// ===========================================================================
class BookmarksPage extends StatefulWidget {
  final AuthState authState;
  const BookmarksPage({super.key, required this.authState});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: profile.uid)
          .get();
      final List<Map<String, dynamic>> items = [];
      for (final d in snap.docs) {
        final qId = d.data()['questionId'] as String;
        final qSnap = await FirebaseFirestore.instance
            .collectionGroup('questions')
            .where(FieldPath.documentId, isEqualTo: qId)
            .get();
        if (qSnap.docs.isNotEmpty) {
          items.add(
              {'id': qId, 'q': Question.fromMap(qId, qSnap.docs.first.data())});
        }
      }
      setState(() => _items = items);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Bookmarks',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No bookmarks.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final q = _items[i]['q'] as Question;
                    return Card(child: ListTile(title: Text(q.text)));
                  },
                ),
    );
  }
}

// ===========================================================================
// PROFILE PAGE
// ===========================================================================
class ProfilePage extends StatelessWidget {
  final AuthState authState;
  const ProfilePage({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final p = authState.profile;
    if (p == null) return const SizedBox();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const CircleAvatar(
              radius: 44,
              backgroundColor: kSlate100,
              child: Icon(Icons.person, size: 48, color: kTeal)),
          const SizedBox(height: 12),
          Text(p.name,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Medical Student', style: TextStyle(color: kSlate500)),
          const SizedBox(height: 28),
          _sectionCard(title: 'Account', children: [
            _profileRow(Icons.person, 'Name', p.name),
            _divider(),
            _profileRow(Icons.email, 'Email', p.email),
            _divider(),
            _profileRow(Icons.business, 'Dept', p.departmentName),
            _divider(),
            _profileRow(Icons.school, 'Stage', p.stageName),
          ]),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign Out'))),
        ]),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSlate100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: kSlate400))),
        ...children,
      ]),
    );
  }

  Widget _profileRow(IconData icon, String label, String val) {
    return ListTile(
        leading: Icon(icon, size: 18),
        title:
            Text(label, style: const TextStyle(fontSize: 10, color: kSlate400)),
        subtitle:
            Text(val, style: const TextStyle(fontWeight: FontWeight.w700)));
  }

  Widget _divider() => const Divider(height: 1, indent: 16);
}
