// =============================================================================
// SM Academy - Flutter App
// Converted from React/TypeScript web app with all Firebase integrations
// =============================================================================
// Firebase Firestore paths used (same as original web app):
//   departments/                            → list of departments
//   departments/{deptId}/stages/            → stages per department
//   departments/{deptId}/stages/{stageId}/subjects/{subjectId}/lectures/{lectureId}/questions/
//   users/{uid}                             → user profile
//   users/{uid}/progress/{questionId}       → answered questions
//   bookmarks/{uid}_{questionId}            → bookmarked questions
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Firebase Options – paste your own google-services.json values here or keep
// these (they match the original web app's firebaseConfig).
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
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get loading => _loading;

  AuthState() {
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
        });
      } else {
        _profile = null;
        _loading = false;
        notifyListeners();
      }
    });
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
const kTealDark = Color(0xFF0F766E);
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
        borderSide: const BorderSide(color: kSlate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kSlate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kTeal, width: 2),
      ),
    ),
  );
}

// ===========================================================================
// MAIN
// ===========================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);
  runApp(const SmAcademyApp());
}

class SmAcademyApp extends StatefulWidget {
  const SmAcademyApp({super.key});
  @override
  State<SmAcademyApp> createState() => _SmAcademyAppState();
}

class _SmAcademyAppState extends State<SmAcademyApp> {
  final _authState = AuthState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authState,
      builder: (context, _) {
        return MaterialApp(
          title: 'SM Academy',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          home: _authState.loading
              ? const SplashScreen()
              : _authState.user == null
                  ? LoginScreen(authState: _authState)
                  : _authState.profile == null
                      ? const Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(color: kTeal),
                          ),
                        )
                      : MainShell(authState: _authState),
        );
      },
    );
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
                letterSpacing: 4,
              ),
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
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: kSlate700,
        ),
      ),
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
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _logoWidget(size: 90),
                    const SizedBox(height: 12),
                    const Text(
                      'SM ACADEMY',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: kTeal,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kSlate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue your studies',
                      style: TextStyle(fontSize: 14, color: kSlate500),
                    ),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error,
                          style: const TextStyle(color: kRed, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'student@university.edu',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
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
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kWhite,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
                              builder: (_) =>
                                  RegisterScreen(authState: widget.authState),
                            ),
                          ),
                          child: const Text(
                            'Register Now',
                            style: TextStyle(
                              color: kTeal,
                              fontWeight: FontWeight.w800,
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
          'unusedQuestions': 0,
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

  Widget _dropdown({
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kSlate700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled ? onChanged : null,
          items: items,
          hint: Text(hint, style: const TextStyle(color: kSlate400)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: kSlate400, size: 20),
          ),
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
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _logoWidget(size: 80),
                    const SizedBox(height: 12),
                    const Text(
                      'SM ACADEMY',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kTeal,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kSlate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Join our medical learning community',
                      style: TextStyle(fontSize: 14, color: kSlate500),
                    ),
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error,
                          style: const TextStyle(color: kRed, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'john@med.edu',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 14),
                    _fetchingDepts
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: kTeal),
                            ),
                          )
                        : _dropdown(
                            label: 'Department',
                            icon: Icons.business_outlined,
                            value: _selectedDeptId,
                            hint: 'Select Department',
                            items: _departments
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.name),
                                    ))
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
                              child: CircularProgressIndicator(color: kTeal),
                            ),
                          )
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
                                      value: s.id,
                                      child: Text(s.name),
                                    ))
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kWhite,
                                ),
                              )
                            : const Text(
                                'Complete Registration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: kEmerald,
                              fontWeight: FontWeight.w800,
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
          color: kWhite,
          border: Border(top: BorderSide(color: kSlate100)),
        ),
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
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined),
                activeIcon: Icon(Icons.book_rounded),
                label: 'Subjects',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_border_rounded),
                activeIcon: Icon(Icons.bookmark_rounded),
                label: 'Bookmarks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// PAGES
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
            Text(
              'Welcome, ${profile.name}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track your progress and keep learning.',
              style: TextStyle(color: kSlate500, fontSize: 14),
            ),
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
                    offset: const Offset(0, 4),
                  ),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: kTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kSlate900,
                        ),
                      ),
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
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: kSlate900,
                              ),
                            ),
                            const Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kSlate400,
                                letterSpacing: 1,
                              ),
                            ),
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(kTeal, 'Used'),
                      const SizedBox(width: 20),
                      _legendDot(kSlate200, 'Unused'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _statCard(
              Icons.menu_book_rounded,
              'Total Questions',
              displayTotal,
              'Available in your curriculum',
              color: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            _statCard(
              Icons.check_circle_outline_rounded,
              'Used Questions',
              displayUsed,
              'Questions you have attempted',
              color: const Color(0xFFCCFBF1),
              iconColor: kTeal,
            ),
            const SizedBox(height: 12),
            _statCard(
              Icons.circle_outlined,
              'Unused Questions',
              displayUnused,
              'Remaining practice material',
              color: kSlate50,
              iconColor: kSlate500,
            ),
            const SizedBox(height: 28),
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kSlate200),
              ),
              child: const Center(
                child: Text(
                  'No recent activity found.\nStart a quiz to see your progress here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kSlate400, fontSize: 14, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kSlate600,
          ),
        ),
      ],
    );
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kSlate400,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kSlate900,
                    height: 1.2,
                  ),
                ),
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

    final filtered = subjects.where((s) {
      return s.subjectName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subjects',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a subject to view lectures.',
              style: TextStyle(color: kSlate500, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search subjects...',
                prefixIcon: Icon(Icons.search_rounded, color: kSlate400),
                hintStyle: TextStyle(color: kSlate400),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                                    authState: widget.authState,
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

  Widget _emptyState(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  const BoxDecoration(color: kSlate50, shape: BoxShape.circle),
              child:
                  const Icon(Icons.book_outlined, size: 36, color: kSlate400),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: kSlate500, fontSize: 14, height: 1.5),
            ),
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.book_rounded, color: kTeal, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.subjectName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kSlate900,
                    ),
                  ),
                  const Text(
                    'Medical Subject',
                    style: TextStyle(
                      fontSize: 11,
                      color: kSlate400,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
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

class LecturesPage extends StatefulWidget {
  final String subjectId;
  final String departmentId;
  final String stageId;
  final String subjectName;
  final AuthState authState;

  const LecturesPage({
    super.key,
    required this.subjectId,
    required this.departmentId,
    required this.stageId,
    required this.subjectName,
    required this.authState,
  });

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

      final lectures = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return Lecture(
          id: d.id,
          name: data['name'] ?? '',
          order: (data['order'] as num?)?.toInt(),
        );
      }).toList();

      lectures.sort((a, b) {
        final oa = a.order ?? 999999;
        final ob = b.order ?? 999999;
        if (oa != ob) return oa.compareTo(ob);
        return a.name.compareTo(b.name);
      });

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
        title: Text(
          widget.subjectName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _lectures.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                              color: kSlate50, shape: BoxShape.circle),
                          child: const Icon(Icons.book_outlined,
                              size: 36, color: kSlate400),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No lectures available for this subject yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kSlate500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
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
                            authState: widget.authState,
                          ),
                        ),
                      ),
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFBF1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: kTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                lec.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kSlate900,
                                ),
                              ),
                            ),
                            const Text(
                              'Start Quiz',
                              style: TextStyle(
                                fontSize: 11,
                                color: kSlate400,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
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
  _QuestionProgress({
    this.selectedOptionId,
    required this.isCorrect,
    required this.isAnswered,
  });
}

class QuizPage extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final String subjectId;
  final String departmentId;
  final String stageId;
  final AuthState authState;

  const QuizPage({
    super.key,
    required this.lectureId,
    required this.lectureName,
    required this.subjectId,
    required this.departmentId,
    required this.stageId,
    required this.authState,
  });

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
      final questionsPath = FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.departmentId)
          .collection('stages')
          .doc(widget.stageId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('lectures')
          .doc(widget.lectureId)
          .collection('questions');

      final snap = await questionsPath.get();
      final questions =
          snap.docs.map((d) => Question.fromMap(d.id, d.data())).toList();
      setState(() => _questions = questions);

      final progressSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('progress')
          .get();
      for (final d in progressSnap.docs) {
        final data = d.data();
        _progress[d.id] = _QuestionProgress(
          selectedOptionId: data['selectedOptionId'],
          isCorrect: data['isCorrect'] == true,
          isAnswered: true,
        );
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

  Future<void> _saveProgress(
      String questionId, String? optionId, bool isCorrect) async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('progress')
          .doc(questionId)
          .set({
        'questionId': questionId,
        'lectureId': widget.lectureId,
        'selectedOptionId': optionId,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _progress[questionId] = _QuestionProgress(
          selectedOptionId: optionId,
          isCorrect: isCorrect,
          isAnswered: true,
        );
      });

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(profile.uid);
      final currentUnused = profile.stats.unusedQuestions;
      final Map<String, dynamic> updates = {
        'stats.usedQuestions': FieldValue.increment(1),
      };
      if (currentUnused > 0) {
        updates['stats.unusedQuestions'] = FieldValue.increment(-1);
      } else {
        updates['stats.totalQuestions'] = FieldValue.increment(1);
      }
      await userRef.update(updates);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<void> _toggleBookmark(String questionId) async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    final bookmarkId = '${profile.uid}_$questionId';
    final ref =
        FirebaseFirestore.instance.collection('bookmarks').doc(bookmarkId);
    try {
      if (_flagged[questionId] == true) {
        await ref.delete();
        setState(() => _flagged[questionId] = false);
      } else {
        await ref.set({
          'userId': profile.uid,
          'questionId': questionId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _flagged[questionId] = true);
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  void _handleOptionTap(String optionId, bool isCorrect) {
    final q = _questions[_currentIndex];
    final qp = _progress[q.id];

    if (qp?.isAnswered != true) {
      _saveProgress(q.id, optionId, isCorrect);
      setState(() {
        _expandedExplanations.clear();
        _expandedExplanations.add(optionId);
      });
    } else {
      setState(() {
        if (_expandedExplanations.contains(optionId)) {
          _expandedExplanations.remove(optionId);
        } else {
          _expandedExplanations.add(optionId);
        }
      });
    }
  }

  void _showAnswer() {
    final q = _questions[_currentIndex];
    for (final opt in q.options) {
      if (opt.isCorrect) {
        _saveProgress(q.id, null, true);
        setState(() {
          _expandedExplanations.clear();
          _expandedExplanations.add(opt.id);
        });
        break;
      }
    }
  }

  void _resetQuestion() {
    final q = _questions[_currentIndex];
    setState(() {
      _progress.remove(q.id);
      _expandedExplanations.clear();
    });
  }

  int get _answeredCount =>
      _questions.where((q) => _progress[q.id]?.isAnswered == true).length;

  int get _correctCount =>
      _questions.where((q) => _progress[q.id]?.isCorrect == true).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lectureName)),
        body: const Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lectureName)),
        body: const Center(
          child: Text('No questions available.',
              style: TextStyle(color: kSlate500)),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final qProgress = _progress[currentQ.id];
    final isAnswered = qProgress?.isAnswered == true;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _quizHeader(currentQ, isAnswered, qProgress),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: kSlate100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Question ${_currentIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: kSlate500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (isAnswered)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: qProgress!.isCorrect
                                      ? kEmeraldLight
                                      : kRedLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      qProgress.isCorrect
                                          ? Icons.check_circle_outline
                                          : Icons.error_outline,
                                      size: 12,
                                      color:
                                          qProgress.isCorrect ? kEmerald : kRed,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      qProgress.isCorrect
                                          ? 'Correct'
                                          : 'Incorrect',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: qProgress.isCorrect
                                            ? kEmerald
                                            : kRed,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentQ.text,
                          style: TextStyle(
                            fontSize: _textSize,
                            fontWeight: FontWeight.w700,
                            color: kSlate900,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...currentQ.options.asMap().entries.map((entry) {
                          return _buildOptionCard(
                              entry.value, entry.key, isAnswered, qProgress);
                        }),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    isAnswered ? _resetQuestion : _showAnswer,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: kSlate200),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: Icon(
                                  isAnswered
                                      ? Icons.refresh_rounded
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: kSlate600,
                                ),
                                label: Text(
                                  isAnswered ? 'Reset' : 'Show Answer',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: kSlate600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentIndex < _questions.length - 1
                                    ? () => setState(() {
                                          _currentIndex++;
                                          _expandedExplanations.clear();
                                        })
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kSlate900,
                                  foregroundColor: kWhite,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  _currentIndex == _questions.length - 1
                                      ? 'Last Question'
                                      : 'Next Question',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _quizFooter(),
              ],
            ),
            if (_showSidebar) _buildSidebar(),
            if (_showSummary) _buildSummaryModal(),
          ],
        ),
      ),
    );
  }

  Widget _quizHeader(Question q, bool isAnswered, _QuestionProgress? qp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kSlate100)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: kSlate700),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lectureName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kSlate900),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_currentIndex + 1} / ${_questions.length}',
                  style: const TextStyle(fontSize: 12, color: kSlate400),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields_rounded,
                color: kSlate500, size: 20),
            onPressed: () => setState(() {
              _textSize = _textSize == 18
                  ? 22
                  : _textSize == 22
                      ? 15
                      : 18;
            }),
          ),
          IconButton(
            icon: Icon(
              _flagged[q.id] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _flagged[q.id] == true ? kTeal : kSlate400,
            ),
            onPressed: () => _toggleBookmark(q.id),
          ),
          IconButton(
            icon:
                const Icon(Icons.grid_view_rounded, color: kSlate500, size: 20),
            onPressed: () => setState(() => _showSidebar = true),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
      QuizOption opt, int idx, bool isAnswered, _QuestionProgress? qp) {
    final isSelected = qp?.selectedOptionId == opt.id;
    final isExpanded = _expandedExplanations.contains(opt.id);

    Color border = kSlate200;
    Color bg = kWhite;
    Color labelBg = kSlate50;
    Color labelColor = kSlate400;

    if (isAnswered) {
      if (opt.isCorrect) {
        border = kEmerald;
        bg = const Color(0xFFF0FDF4);
        labelBg = kEmerald;
        labelColor = kWhite;
      } else if (isSelected) {
        border = kRed;
        bg = const Color(0xFFFFF5F5);
        labelBg = kRed;
        labelColor = kWhite;
      } else {
        border = kSlate100;
        bg = kSlate50;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _handleOptionTap(opt.id, opt.isCorrect),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: labelBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + idx),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: labelColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(opt.text,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kSlate700,
                            height: 1.4)),
                  ),
                ),
                if (isAnswered && opt.isCorrect)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.check_circle_rounded,
                        color: kEmerald, size: 22),
                  ),
                if (isAnswered && isSelected && !opt.isCorrect)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.cancel_rounded, color: kRed, size: 22),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isExpanded && opt.explanation.isNotEmpty
              ? Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: opt.isCorrect
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFF5F5),
                    border: Border.all(
                        color: opt.isCorrect
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFECACA)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        opt.isCorrect
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 16,
                        color: opt.isCorrect ? kEmerald : kRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(opt.explanation,
                            style: TextStyle(
                                fontSize: 13,
                                color: opt.isCorrect
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF7F1D1D),
                                height: 1.5)),
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _quizFooter() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kSlate100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _currentIndex > 0
                  ? () => setState(() {
                        _currentIndex--;
                        _expandedExplanations.clear();
                      })
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: TextButton.styleFrom(foregroundColor: kSlate600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showSummary = true),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('End',
                style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF1F2),
              foregroundColor: kRed,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: _currentIndex < _questions.length - 1
                  ? () => setState(() {
                        _currentIndex++;
                        _expandedExplanations.clear();
                      })
                  : null,
              icon: const Text('Next',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              label: const Icon(Icons.chevron_right_rounded),
              style: TextButton.styleFrom(foregroundColor: kTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return GestureDetector(
      onTap: () => setState(() => _showSidebar = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 300,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: kSlate50,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Navigation',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: kSlate900,
                                fontSize: 14)),
                        IconButton(
                          icon:
                              const Icon(Icons.close_rounded, color: kSlate400),
                          onPressed: () => setState(() => _showSidebar = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$_answeredCount of ${_questions.length} Answered',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kSlate600)),
                        Text(
                            '${_questions.isEmpty ? 0 : (_answeredCount / _questions.length * 100).round()}%',
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
                        minHeight: 8,
                        backgroundColor: kSlate200,
                        valueColor: const AlwaysStoppedAnimation<Color>(kTeal),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _questions.length,
                        itemBuilder: (context, i) {
                          final qp = _progress[_questions[i].id];
                          final isActive = i == _currentIndex;
                          Color bg = kWhite;
                          Color textColor = kSlate500;
                          Color borderColor = kSlate200;
                          if (qp?.isAnswered == true) {
                            bg = qp!.isCorrect ? kEmerald : kRed;
                            textColor = kWhite;
                            borderColor = qp.isCorrect ? kEmerald : kRed;
                          }
                          return GestureDetector(
                            onTap: () => setState(() {
                              _currentIndex = i;
                              _showSidebar = false;
                              _expandedExplanations.clear();
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bg,
                                border: Border.all(
                                    color: isActive ? kSlate900 : borderColor,
                                    width: isActive ? 2.5 : 1.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: textColor)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showSidebar = false;
                            _showSummary = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed,
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
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
  }

  Widget _buildSummaryModal() {
    final score = _questions.isEmpty
        ? 0
        : (_correctCount / _questions.length * 100).round();
    return GestureDetector(
      onTap: () => setState(() => _showSummary = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: kTeal, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Exam Summary',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kSlate900)),
                  const SizedBox(height: 4),
                  const Text('Great job completing this session!',
                      style: TextStyle(color: kSlate500, fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kSlate50,
                              borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              const Text('SCORE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: kSlate400,
                                      letterSpacing: 1)),
                              Text('$score%',
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: kTeal)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kSlate50,
                              borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              const Text('CORRECT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: kSlate400,
                                      letterSpacing: 1)),
                              Text('$_correctCount/${_questions.length}',
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: kSlate900)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSlate900,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Return to Lectures',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _showSummary = false),
                    child: const Text('Review Answers',
                        style: TextStyle(
                            color: kSlate500, fontWeight: FontWeight.w700)),
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

class BookmarksPage extends StatefulWidget {
  final AuthState authState;
  const BookmarksPage({super.key, required this.authState});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Map<String, dynamic>> _bookmarkedItems = [];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: profile.uid)
          .get();

      final items = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final qId = data['questionId'] as String;
        final qSnap = await FirebaseFirestore.instance
            .collectionGroup('questions')
            .where(FieldPath.documentId, isEqualTo: qId)
            .get();
        if (qSnap.docs.isNotEmpty) {
          final q =
              Question.fromMap(qSnap.docs.first.id, qSnap.docs.first.data());
          items.add({'questionId': qId, 'question': q});
        }
      }
      setState(() => _bookmarkedItems = items);
    } catch (e) {
      debugPrint('Error fetching bookmarks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
            const Text('Bookmarks',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kSlate900)),
            const SizedBox(height: 4),
            const Text('Your saved questions for review.',
                style: TextStyle(color: kSlate500, fontSize: 14)),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kTeal))
                  : _bookmarkedItems.isEmpty
                      ? const Center(child: Text('No bookmarks yet.'))
                      : ListView.separated(
                          itemCount: _bookmarkedItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final q =
                                _bookmarkedItems[i]['question'] as Question;
                            final qId =
                                _bookmarkedItems[i]['questionId'] as String;
                            final isExpanded = _expandedId == qId;
                            return Container(
                              decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(18)),
                              child: Column(
                                children: [
                                  ListTile(
                                    onTap: () => setState(() =>
                                        _expandedId = isExpanded ? null : qId),
                                    title: Text(q.text,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                        maxLines: isExpanded ? null : 2),
                                    trailing: Icon(isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          children: q.options
                                              .map((o) => ListTile(
                                                  title: Text(o.text),
                                                  leading: Icon(
                                                      o.isCorrect
                                                          ? Icons.check_circle
                                                          : Icons
                                                              .circle_outlined,
                                                      color: o.isCorrect
                                                          ? kEmerald
                                                          : kSlate200)))
                                              .toList()),
                                    ),
                                ],
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
}

class ProfilePage extends StatelessWidget {
  final AuthState authState;
  const ProfilePage({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final profile = authState.profile;
    if (profile == null) return const SizedBox();

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
                color: const Color(0xFFCCFBF1),
                shape: BoxShape.circle,
                border: Border.all(color: kWhite, width: 4),
                boxShadow: [
                  BoxShadow(
                      color: kSlate200.withOpacity(0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.person_rounded, color: kTeal, size: 48),
            ),
            const SizedBox(height: 12),
            Text(profile.name,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kSlate900)),
            const Text('Medical Student',
                style: TextStyle(color: kSlate500, fontSize: 14)),
            const SizedBox(height: 28),
            _sectionCard(
              title: 'Account Settings',
              children: [
                _profileRow(Icons.person_outline_rounded,
                    'Personal Information', profile.name),
                _divider(),
                _profileRow(
                    Icons.mail_outline_rounded, 'Email Address', profile.email),
                _divider(),
                _profileRow(
                    Icons.business_outlined,
                    'Department',
                    profile.departmentName.isNotEmpty
                        ? profile.departmentName
                        : 'N/A'),
                _divider(),
                _profileRow(Icons.school_outlined, 'Academic Stage',
                    profile.stageName.isNotEmpty ? profile.stageName : 'N/A'),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Preferences',
              children: [
                _preferenceRow(
                    Icons.notifications_outlined, 'Notifications', true),
                _divider(),
                _preferenceRow(Icons.dark_mode_outlined, 'Dark Mode', false),
                _divider(),
                _chevronRow(Icons.shield_outlined, 'Privacy & Security'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  foregroundColor: kRed,
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
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSlate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: kSlate400)),
          ),
          const Divider(height: 1, color: kSlate100),
          ...children,
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kSlate500),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: kSlate400)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preferenceRow(IconData icon, String label, bool enabled) {
    return ListTile(
      leading: Icon(icon, size: 18, color: kSlate500),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      trailing: Switch(value: enabled, onChanged: (_) {}, activeColor: kTeal),
    );
  }

  Widget _chevronRow(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, size: 18, color: kSlate500),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, color: kSlate400),
    );
  }

  Widget _divider() => const Divider(height: 1, color: kSlate100, indent: 16);
}
