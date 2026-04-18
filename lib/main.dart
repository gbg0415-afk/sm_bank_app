// =============================================================================
//  SM Academy – Flutter App
//  Single-file implementation converted from the React/TypeScript web app.
//
//  Firebase Firestore paths (identical to original web app):
//    departments/                                          → departments list
//    departments/{deptId}/years/                           → stages per dept
//    departments/{deptId}/years/{stageId}/subjects/
//      /{subjectId}/lectures/{lectureId}/questions/        → quiz questions
//    users/{uid}                                           → user profile
//    users/{uid}/progress/{questionId}                     → answered Qs
//    bookmarks/{uid}_{questionId}                          → bookmarks
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
// Firebase configuration – mirrors the original web app's firebaseConfig.
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
//  DESIGN TOKENS  (all declared at top-level, before any class)
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
//  AUTH STATE  (ChangeNotifier – no extra packages)
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
//  THEME
// ===========================================================================

ThemeData _buildTheme() => ThemeData(
      useMaterial3: true,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kRed, width: 2),
        ),
      ),
    );

// ===========================================================================
//  ENTRY POINT
// ===========================================================================

bool _firebaseInitError = false;

Future<void> main() async {
  // Ensure framework is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Catch uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  // Ensure Firebase is properly initialized before starting the app
  try {
    await Firebase.initializeApp(options: _firebaseOptions);
    // Correct Firestore settings to prevent timeout issues
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
    _firebaseInitError = true;
  }

  runApp(const _SmAcademyRoot());
}

class _SmAcademyRoot extends StatefulWidget {
  const _SmAcademyRoot();

  @override
  State<_SmAcademyRoot> createState() => _SmAcademyRootState();
}

class _SmAcademyRootState extends State<_SmAcademyRoot> {
  // AuthState is created safely since Firebase is fully initialized in main.
  AuthState? _auth;

  @override
  void initState() {
    super.initState();
    if (!_firebaseInitError) {
      _auth = AuthState();
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SM Academy',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: Builder(
        builder: (_) {
          // Show error screen if Firebase failed to initialise.
          if (_firebaseInitError || _auth == null) {
            return const Scaffold(
              backgroundColor: kSlate50,
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: kRed, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Failed to connect to server.\nPlease check your internet connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kSlate700, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Firebase is ready – delegate routing to AuthState.
          return ListenableBuilder(
            listenable: _auth!,
            builder: (_, __) {
              // Auth state still loading → keep showing splash.
              if (_auth!.loading) return const _SplashScreen();
              // Not logged in → Login screen.
              if (_auth!.user == null) return _LoginScreen(auth: _auth!);
              // Logged in but Firestore profile not yet arrived.
              if (_auth!.profile == null) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: kTeal),
                  ),
                );
              }
              // Fully loaded → Main app.
              return _MainShell(auth: _auth!);
            },
          );
        },
      ),
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
    return const Scaffold(
      backgroundColor: kTeal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppLogo(size: 100, bgColor: kWhite),
            SizedBox(height: 24),
            Text(
              'SM ACADEMY',
              style: TextStyle(
                color: kWhite,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              color: kWhite,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  SHARED WIDGETS & HELPERS
// ===========================================================================

/// App logo loaded from CDN, with a fallback icon.
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
          child: Icon(
            Icons.school_rounded,
            size: size * 0.55,
            color: kTeal,
          ),
        ),
      ),
    );
  }
}

/// A labelled text input with a leading icon.
Widget _labeledField({
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

/// Red error banner displayed on auth screens.
Widget _errorBanner(String message) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: kRed, fontSize: 13),
      ),
    );

/// Thin divider used inside profile / settings cards.
const Widget _kDivider = Divider(height: 1, color: kSlate100, indent: 16);

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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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
      // AuthState listener handles navigation automatically.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Login failed. Please try again.');
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo & title
                    const _AppLogo(size: 88),
                    const SizedBox(height: 12),
                    const Text(
                      'SM ACADEMY',
                      style: TextStyle(
                        fontSize: 24,
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

                    // Error
                    if (_error.isNotEmpty) ...<Widget>[
                      _errorBanner(_error),
                      const SizedBox(height: 16),
                    ],

                    // Fields
                    _labeledField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'student@university.edu',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _labeledField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 24),

                    // Sign-in button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          foregroundColor: kWhite,
                          disabledBackgroundColor: kTeal,
                          disabledForegroundColor: kWhite,
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

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: kSlate500),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _RegisterScreen(auth: widget.auth),
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

  List<Department> _departments = <Department>[];
  List<Stage> _stages = <Stage>[];
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // -- Firebase fetches ----------------------------------------------------

  // Fetch departments from Firebase 'departments' collection dynamically.
  Future<void> _fetchDepartments() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('departments').get();
      setState(() {
        _departments = snap.docs.map((d) {
          // Use the Document ID as the exact department name
          return Department(id: d.id, name: d.id);
        }).toList();
      });
    } catch (e) {
      debugPrint('Departments fetch error: $e');
    } finally {
      if (mounted) setState(() => _fetchingDepts = false);
    }
  }

  // Fetch academic stages from departments/{deptId}/years.
  Future<void> _fetchStages(String deptId) async {
    setState(() {
      _fetchingStages = true;
      _stages = <Stage>[];
      _selectedStageId = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('departments')
          .doc(deptId)
          .collection('years') // Path updated to match exact database structure
          .get();
      setState(() {
        _stages = snap.docs.map((d) {
          // Use the Document ID as the exact stage name
          return Stage(id: d.id, name: d.id);
        }).toList();
      });
    } catch (e) {
      debugPrint('Stages fetch error: $e');
    } finally {
      if (mounted) setState(() => _fetchingStages = false);
    }
  }

  // -- Registration --------------------------------------------------------

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

      // Write user document – same structure as original web app.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(<String, dynamic>{
        'uid': cred.user!.uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'departmentId': _selectedDeptId,
        'departmentName': dept.name,
        'stageId': _selectedStageId,
        'stageName': stage.name,
        'assignedSubjects': <dynamic>[],
        'stats': <String, dynamic>{
          'totalQuestions': 0,
          'usedQuestions': 0,
          'unusedQuestions': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      // AuthState listener navigates automatically on success.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -- Dropdown helper -----------------------------------------------------

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
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          items: items,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          hint: Text(hint, style: const TextStyle(color: kSlate400)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: kSlate400, size: 20),
          ),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo & title
                    const _AppLogo(size: 80),
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

                    // Error
                    if (_error.isNotEmpty) ...<Widget>[
                      _errorBanner(_error),
                      const SizedBox(height: 16),
                    ],

                    // Fields
                    _labeledField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _labeledField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'john@med.edu',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _labeledField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 14),

                    // Department – fetched dynamically from Firebase
                    _fetchingDepts
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(color: kTeal),
                            ),
                          )
                        : _dropdown(
                            label: 'Department',
                            icon: Icons.business_outlined,
                            value: _selectedDeptId,
                            hint: 'Select Department',
                            items: _departments
                                .map((d) => DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text(d.name),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDeptId = val;
                                _selectedStageId = null;
                                _stages = <Stage>[];
                              });
                              if (val != null) _fetchStages(val);
                            },
                          ),
                    const SizedBox(height: 14),

                    // Academic Stage – fetched dynamically from Firebase
                    _fetchingStages
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
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
                                .map((s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedStageId = val),
                          ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_loading || _fetchingDepts) ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kEmerald,
                          foregroundColor: kWhite,
                          disabledBackgroundColor: kEmerald,
                          disabledForegroundColor: kWhite,
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
                                'Complete Registration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: kSlate500),
                        ),
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
//  MAIN SHELL  (bottom-nav container)
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
    _pages = <Widget>[
      _HomePage(auth: widget.auth),
      _CategoriesPage(auth: widget.auth),
      _BookmarksPage(auth: widget.auth),
      _ProfilePage(auth: widget.auth),
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
          top: false,
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kTeal,
            unselectedItemColor: kSlate400,
            backgroundColor: kWhite,
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            items: const <BottomNavigationBarItem>[
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
//  HOME PAGE
// ===========================================================================

class _HomePage extends StatelessWidget {
  final AuthState auth;
  const _HomePage({required this.auth});

  @override
  Widget build(BuildContext context) {
    final profile = auth.profile;
    if (profile == null) return const SizedBox.shrink();

    final stats = profile.stats;

    // Guard against negative values.
    final int displayUsed = stats.usedQuestions < 0 ? 0 : stats.usedQuestions;
    final int displayUnused =
        stats.unusedQuestions < 0 ? 0 : stats.unusedQuestions;
    final int displayTotal =
        (displayUsed + displayUnused) > stats.totalQuestions
            ? displayUsed + displayUnused
            : stats.totalQuestions;
    final int pct =
        displayTotal > 0 ? ((displayUsed / displayTotal) * 100).round() : 0;
    final double progress = displayTotal > 0 ? displayUsed / displayTotal : 0.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
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

            // Progress card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kSlate100),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            backgroundColor: kSlate200,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(kTeal),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: kSlate900,
                              ),
                            ),
                            const Text(
                              'COMPLETED',
                              style: TextStyle(
                                fontSize: 10,
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
                    "You've completed $displayUsed out of $displayTotal questions. "
                    'Keep going to master your curriculum!',
                    style: const TextStyle(
                      color: kSlate500,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _legendDot(kTeal, 'Used'),
                      const SizedBox(width: 20),
                      _legendDot(kSlate200, 'Unused'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stat cards
            _statCard(
              icon: Icons.menu_book_rounded,
              label: 'Total Questions',
              value: displayTotal,
              desc: 'Available in your curriculum',
              cardColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            _statCard(
              icon: Icons.check_circle_outline_rounded,
              label: 'Used Questions',
              value: displayUsed,
              desc: 'Questions you have attempted',
              cardColor: const Color(0xFFCCFBF1),
              iconColor: kTeal,
            ),
            const SizedBox(height: 12),
            _statCard(
              icon: Icons.circle_outlined,
              label: 'Unused Questions',
              value: displayUnused,
              desc: 'Remaining practice material',
              cardColor: kSlate50,
              iconColor: kSlate500,
            ),
            const SizedBox(height: 28),

            // Recent activity
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
                  'No recent activity found.\n'
                  'Start a quiz to see your progress here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kSlate400,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        children: <Widget>[
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

  Widget _statCard({
    required IconData icon,
    required String label,
    required int value,
    required String desc,
    required Color cardColor,
    required Color iconColor,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSlate100),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 11, color: kSlate400),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ===========================================================================
//  CATEGORIES PAGE  (assigned subjects)
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
          children: <Widget>[
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
                hintStyle: TextStyle(color: kSlate400),
                prefixIcon: Icon(Icons.search_rounded, color: kSlate400),
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
                          itemBuilder: (ctx, i) {
                            final s = filtered[i];
                            return _SubjectCard(
                              subject: s,
                              onTap: () => Navigator.push<void>(
                                ctx,
                                MaterialPageRoute<void>(
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
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: kSlate50,
                shape: BoxShape.circle,
              ),
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
          color: kWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSlate100),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
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
                children: <Widget>[
                  Text(
                    subject.subjectName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kSlate900,
                    ),
                  ),
                  const Text(
                    'MEDICAL SUBJECT',
                    style: TextStyle(
                      fontSize: 10,
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

// ===========================================================================
//  LECTURES PAGE
// ===========================================================================

class _LecturesPage extends StatefulWidget {
  final String subjectId;
  final String departmentId;
  final String stageId;
  final String subjectName;
  final AuthState auth;

  const _LecturesPage({
    required this.subjectId,
    required this.departmentId,
    required this.stageId,
    required this.subjectName,
    required this.auth,
  });

  @override
  State<_LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<_LecturesPage> {
  List<Lecture> _lectures = <Lecture>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLectures();
  }

  Future<void> _fetchLectures() async {
    // Path correctly matches database structure: departments/{deptId}/years/{stageId}/subjects/{subjectId}/lectures
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
          order: ((data['order'] as num?) ?? 999999).toInt(),
        );
      }).toList();

      list.sort((a, b) {
        final cmp = a.order.compareTo(b.order);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });

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
      appBar: AppBar(
        title: Text(
          widget.subjectName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
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
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: kSlate50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.book_outlined,
                  size: 36,
                  color: kSlate400,
                ),
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
      );
}

class _LectureCard extends StatelessWidget {
  final Lecture lecture;
  final String subjectId;
  final String departmentId;
  final String stageId;
  final AuthState auth;

  const _LectureCard({
    required this.lecture,
    required this.subjectId,
    required this.departmentId,
    required this.stageId,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
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
          color: kWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSlate100),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
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
                lecture.name,
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
            const Icon(Icons.chevron_right_rounded, color: kSlate400),
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

  const _QuizPage({
    required this.lectureId,
    required this.lectureName,
    required this.subjectId,
    required this.departmentId,
    required this.stageId,
    required this.auth,
  });

  @override
  State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  List<Question> _questions = <Question>[];
  bool _loading = true;
  int _index = 0;
  final Map<String, _QProgress> _progress = <String, _QProgress>{};
  final Map<String, bool> _bookmarked = <String, bool>{};
  // IDs of options whose explanation panels are currently open.
  final Set<String> _expanded = <String>{};
  bool _showSidebar = false;
  bool _showSummary = false;
  double _textSize = 18;

  // -- Data fetching --------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;

    try {
      // Questions path updated to correctly use years:
      // departments/{deptId}/years/{stageId}/subjects/{subjectId}/lectures/{lectureId}/questions
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

      final questions =
          qSnap.docs.map((d) => Question.fromMap(d.id, d.data())).toList();
      setState(() => _questions = questions);

      // users/{uid}/progress
      final pSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      for (final d in pSnap.docs) {
        final data = d.data();
        _progress[d.id] = _QProgress(
          selectedOptionId: data['selectedOptionId'] as String?,
          isCorrect: data['isCorrect'] == true,
        );
      }

      // bookmarks where userId == uid
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

  // -- Answer handling ------------------------------------------------------

  Future<void> _saveAnswer(
    String questionId,
    String optionId,
    bool isCorrect,
  ) async {
    final uid = widget.auth.user?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(questionId)
          .set(<String, dynamic>{
        'questionId': questionId,
        'lectureId': widget.lectureId,
        'selectedOptionId': optionId,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _progress[questionId] =
            _QProgress(selectedOptionId: optionId, isCorrect: isCorrect);
      });

      // Update user stats
      final unusedCount = widget.auth.profile?.stats.unusedQuestions ?? 0;
      final updates = <String, dynamic>{
        'stats.usedQuestions': FieldValue.increment(1),
      };
      if (unusedCount > 0) {
        updates['stats.unusedQuestions'] = FieldValue.increment(-1);
      } else {
        updates['stats.totalQuestions'] = FieldValue.increment(1);
      }
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
      // First time answering this question
      _saveAnswer(q.id, optionId, isCorrect);
      setState(() {
        _expanded
          ..clear()
          ..add(optionId);
      });
    } else {
      // Already answered – toggle the explanation for this option
      setState(() {
        if (_expanded.contains(optionId)) {
          _expanded.remove(optionId);
        } else {
          _expanded.add(optionId);
        }
      });
    }
  }

  void _showAnswer() {
    final q = _questions[_index];
    for (final opt in q.options) {
      if (opt.isCorrect) {
        _saveAnswer(q.id, opt.id, true);
        setState(() {
          _expanded
            ..clear()
            ..add(opt.id);
        });
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

    // Delete by querying userId + questionId exactly as requested
    final bookmarksRef = FirebaseFirestore.instance.collection('bookmarks');
    try {
      if (_bookmarked[questionId] == true) {
        // Query for all bookmark docs matching this user + question and delete them.
        final existingDocs = await bookmarksRef
            .where('userId', isEqualTo: uid)
            .where('questionId', isEqualTo: questionId)
            .get();
        for (final d in existingDocs.docs) {
          await d.reference.delete();
        }
        setState(() => _bookmarked[questionId] = false);
      } else {
        // Save bookmark with exactly the requested fields and correct paths.
        final questionPath =
            'departments/${widget.departmentId}/years/${widget.stageId}/subjects/${widget.subjectId}/lectures/${widget.lectureId}/questions/$questionId';

        await bookmarksRef.doc('${uid}_$questionId').set(<String, dynamic>{
          'userId': uid,
          'questionId': questionId,
          'questionPath': questionPath,
          'AddedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _bookmarked[questionId] = true);
      }
    } catch (e) {
      debugPrint('Bookmark toggle error: $e');
    }
  }

  // -- Computed values ------------------------------------------------------

  int get _answeredCount =>
      _questions.where((q) => _progress.containsKey(q.id)).length;

  int get _correctCount =>
      _questions.where((q) => _progress[q.id]?.isCorrect == true).length;

  void _goNext() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _expanded.clear();
      });
    }
  }

  void _goPrev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _expanded.clear();
      });
    }
  }

  // -- Build ----------------------------------------------------------------

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
          child: Text(
            'No questions available for this lecture.',
            style: TextStyle(color: kSlate500),
          ),
        ),
      );
    }

    final currentQ = _questions[_index];
    final qp = _progress[currentQ.id];
    final answered = qp != null;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildHeader(currentQ, answered, qp),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildQuestionLabel(answered, qp),
                        const SizedBox(height: 16),
                        Text(
                          currentQ.text.isEmpty
                              ? 'Question text not found'
                              : currentQ.text,
                          style: TextStyle(
                            fontSize: _textSize,
                            fontWeight: FontWeight.w700,
                            color: kSlate900,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...currentQ.options.asMap().entries.map(
                              (e) => _buildOptionCard(
                                  e.value, e.key, answered, qp),
                            ),
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

  // -- Sub-widgets ----------------------------------------------------------

  Widget _buildHeader(Question q, bool answered, _QProgress? qp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kSlate100)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close_rounded, color: kSlate700),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.lectureName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kSlate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_index + 1} / ${_questions.length}',
                  style: const TextStyle(fontSize: 12, color: kSlate400),
                ),
              ],
            ),
          ),
          // Cycle text size
          IconButton(
            icon: const Icon(
              Icons.text_fields_rounded,
              color: kSlate500,
              size: 20,
            ),
            onPressed: () => setState(() {
              _textSize = _textSize == 18
                  ? 22
                  : _textSize == 22
                      ? 15
                      : 18;
            }),
          ),
          // Bookmark
          IconButton(
            icon: Icon(
              _bookmarked[q.id] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _bookmarked[q.id] == true ? kTeal : kSlate400,
            ),
            onPressed: () => _toggleBookmark(q.id),
          ),
          // Question grid
          IconButton(
            icon: const Icon(
              Icons.grid_view_rounded,
              color: kSlate500,
              size: 20,
            ),
            onPressed: () => setState(() => _showSidebar = true),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(bool answered, _QProgress? qp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kSlate100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Question ${_index + 1}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: kSlate500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (answered && qp != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: qp.isCorrect ? kEmeraldBg : kRedBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  qp.isCorrect
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 12,
                  color: qp.isCorrect ? kEmerald : kRed,
                ),
                const SizedBox(width: 4),
                Text(
                  qp.isCorrect ? 'Correct' : 'Incorrect',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: qp.isCorrect ? kEmerald : kRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionCard(
    QuizOption option,
    int idx,
    bool answered,
    _QProgress? qp,
  ) {
    final isSelected = qp?.selectedOptionId == option.id;
    final isExpanded = _expanded.contains(option.id);

    Color borderColor = kSlate200;
    Color bgColor = kWhite;
    Color labelBg = kSlate50;
    Color labelColor = kSlate400;

    if (answered) {
      if (option.isCorrect) {
        borderColor = kEmerald;
        bgColor = const Color(0xFFF0FDF4);
        labelBg = kEmerald;
        labelColor = kWhite;
      } else if (isSelected) {
        borderColor = kRed;
        bgColor = const Color(0xFFFFF5F5);
        labelBg = kRed;
        labelColor = kWhite;
      } else {
        borderColor = kSlate100;
        bgColor = kSlate50;
      }
    }

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: () => _handleOptionTap(option.id, option.isCorrect),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                        color: labelColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      option.text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kSlate700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (answered && option.isCorrect)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: kEmerald,
                      size: 22,
                    ),
                  ),
                if (answered && isSelected && !option.isCorrect)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.cancel_rounded, color: kRed, size: 22),
                  ),
              ],
            ),
          ),
        ),

        // Expandable explanation
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: (isExpanded && option.explanation.isNotEmpty)
              ? Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: option.isCorrect
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFF5F5),
                    border: Border.all(
                      color: option.isCorrect
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        option.isCorrect
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 16,
                        color: option.isCorrect ? kEmerald : kRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: option.isCorrect
                                ? const Color(0xFF065F46)
                                : const Color(0xFF7F1D1D),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionRow(bool answered) => Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: answered ? _resetQuestion : _showAnswer,
              style: OutlinedButton.styleFrom(
                foregroundColor: kSlate600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: kSlate200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                answered ? Icons.refresh_rounded : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(answered ? 'Reset' : 'Show Answer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _index < _questions.length - 1 ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kSlate900,
                foregroundColor: kWhite,
                disabledForegroundColor: kSlate500,
                disabledBackgroundColor: kSlate200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _index == _questions.length - 1
                    ? 'Last Question'
                    : 'Next Question',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );

  Widget _buildFooter() => Container(
        height: 70,
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: kSlate100)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                onPressed: _index > 0 ? _goPrev : null,
                style: TextButton.styleFrom(foregroundColor: kSlate600),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text(
                  'Previous',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showSummary = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                foregroundColor: kRed,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text(
                'End',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _index < _questions.length - 1 ? _goNext : null,
                style: TextButton.styleFrom(foregroundColor: kTeal),
                icon: const Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
                decoration: const BoxDecoration(
                  color: kSlate50,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'NAVIGATION',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: kSlate500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: kSlate400,
                            ),
                            onPressed: () =>
                                setState(() => _showSidebar = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            '$_answeredCount of ${_questions.length} Answered',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kSlate600,
                            ),
                          ),
                          Text(
                            '${_questions.isEmpty ? 0 : ((_answeredCount / _questions.length) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: kTeal,
                            ),
                          ),
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
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(kTeal),
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
                          itemBuilder: (_, i) {
                            final q = _questions[i];
                            final qp = _progress[q.id];
                            final isActive = i == _index;

                            Color bg = kWhite;
                            Color textColor = kSlate500;
                            Color borderColor = kSlate200;

                            if (qp != null) {
                              bg = qp.isCorrect ? kEmerald : kRed;
                              textColor = kWhite;
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
                                    color: isActive ? kSlate900 : borderColor,
                                    width: isActive ? 2.5 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
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
                          onPressed: () => setState(() {
                            _showSidebar = false;
                            _showSummary = true;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRed,
                            foregroundColor: kWhite,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text(
                            'End Exam',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
                color: kWhite,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x33000000), blurRadius: 40),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: kTeal,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Exam Summary',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kSlate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Great job completing this session!',
                    style: TextStyle(color: kSlate500, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _summaryTile('SCORE', '$score%', kTeal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryTile(
                          'CORRECT',
                          '$_correctCount/$total',
                          kSlate900,
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Return to Lectures',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => setState(() => _showSummary = false),
                      child: const Text(
                        'Review Answers',
                        style: TextStyle(
                          color: kSlate500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
          color: kSlate50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: kSlate400,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
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
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  // Fetch all bookmarks for the current user and display them properly.
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

        // 1. Try the saved questionPath first (new-style bookmarks saved by this app).
        final qPath = data['questionPath'] as String?;
        if (qPath != null && qPath.isNotEmpty) {
          try {
            final qSnap = await FirebaseFirestore.instance.doc(qPath).get();
            if (qSnap.exists) {
              q = Question.fromMap(qSnap.id, qSnap.data()!);
            }
          } catch (_) {}
        }

        // 2. Fallback: top-level questions collection (legacy bookmarks).
        if (q == null) {
          try {
            final qSnap = await FirebaseFirestore.instance
                .collection('questions')
                .doc(questionId)
                .get();
            if (qSnap.exists) {
              q = Question.fromMap(qSnap.id, qSnap.data()!);
            }
          } catch (_) {}
        }

        // 3. Always add the item – if question data is unavailable, show a
        //    placeholder so the bookmark is never silently hidden.
        items.add(<String, dynamic>{
          'questionId': questionId,
          'question': q ??
              Question(
                id: questionId,
                text: 'Question data unavailable',
                options: const <QuizOption>[],
              ),
        });
      }

      setState(() => _items = items);
    } catch (e) {
      debugPrint('Bookmarks fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Delete bookmark by querying userId + questionId fields.
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
          children: <Widget>[
            const Text(
              'Bookmarks',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your saved questions for review.',
              style: TextStyle(color: kSlate500, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kTeal),
                    )
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
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: kSlate50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 36,
                color: kSlate400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No bookmarks yet.\n'
              'Save questions during a quiz to find them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kSlate500, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );

  Widget _buildCard(Map<String, dynamic> item) {
    final String qId = item['questionId'] as String;
    final Question question = item['question'] as Question;
    final bool isOpen = _expanded == qId;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kSlate100),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            onTap: () => setState(() => _expanded = isOpen ? null : qId),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: kTeal,
                size: 20,
              ),
            ),
            title: Text(
              question.text.isEmpty ? 'Question' : question.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kSlate900,
              ),
              maxLines: isOpen ? null : 2,
              overflow: isOpen ? null : TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: kSlate400,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: kRed,
                    size: 20,
                  ),
                  onPressed: () => _removeBookmark(qId),
                ),
              ],
            ),
          ),
          if (isOpen) ...<Widget>[
            const Divider(height: 1, color: kSlate100),
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
                      color: opt.isCorrect ? kEmeraldBg : kSlate50,
                      border: Border.all(
                        color: opt.isCorrect ? kEmerald : kSlate100,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          String.fromCharCode(65 + idx),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: opt.isCorrect ? kEmerald : kSlate500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            opt.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: opt.isCorrect
                                  ? const Color(0xFF065F46)
                                  : kSlate700,
                              fontWeight: opt.isCorrect
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (opt.isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: kEmerald,
                            size: 18,
                          ),
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
//  PROFILE PAGE
// ===========================================================================

class _ProfilePage extends StatefulWidget {
  final AuthState auth;
  const _ProfilePage({required this.auth});

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  // Track toggle states so buttons are interactive.
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.auth.profile;
    if (profile == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),

            // Avatar
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: kTeal, size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              profile.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const Text(
              'Medical Student',
              style: TextStyle(color: kSlate500, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // Account settings
            _sectionCard(
              title: 'Account Settings',
              children: <Widget>[
                _profileRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Personal Information',
                  value: profile.name,
                ),
                _kDivider,
                _profileRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email Address',
                  value: profile.email,
                ),
                _kDivider,
                _profileRow(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: profile.departmentName.isNotEmpty
                      ? profile.departmentName
                      : 'Not Assigned',
                ),
                _kDivider,
                _profileRow(
                  icon: Icons.school_outlined,
                  label: 'Academic Stage',
                  value: profile.stageName.isNotEmpty
                      ? profile.stageName
                      : 'Not Assigned',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preferences
            _sectionCard(
              title: 'Preferences',
              children: <Widget>[
                // Pass live state so tapping actually toggles the switch.
                _toggleRow(Icons.notifications_outlined, 'Notifications',
                    _notificationsEnabled, () {
                  setState(
                      () => _notificationsEnabled = !_notificationsEnabled);
                }),
                _kDivider,
                _toggleRow(
                    Icons.dark_mode_outlined, 'Dark Mode', _darkModeEnabled,
                    () {
                  setState(() => _darkModeEnabled = !_darkModeEnabled);
                }),
                _kDivider,
                _chevronRow(
                    context, Icons.shield_outlined, 'Privacy & Security'),
                _kDivider,
                _chevronRow(context, Icons.settings_outlined, 'App Settings'),
              ],
            ),
            const SizedBox(height: 20),

            // Sign-out with confirmation dialog.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: kSlate500)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out',
                              style: TextStyle(
                                  color: kRed, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRed,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SM ACADEMY v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: kSlate400,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // -- Card helpers ---------------------------------------------------------

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSlate100),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: kSlate400,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Divider(height: 1, color: kSlate100),
            ...children,
          ],
        ),
      );

  Widget _profileRow({
    required IconData icon,
    required String label,
    required String value,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kSlate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: kSlate500),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: kSlate400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kSlate700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // _toggleRow accepts an onTap callback so the switch is interactive.
  Widget _toggleRow(
          IconData icon, String label, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSlate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: kSlate500),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: kSlate400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      enabled ? 'Enabled' : 'Disabled',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kSlate700,
                      ),
                    ),
                  ],
                ),
              ),
              // Interactive toggle switch.
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 42,
                  height: 24,
                  decoration: BoxDecoration(
                    color: enabled ? kTeal : kSlate200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment:
                        enabled ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: kWhite,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // _chevronRow accepts BuildContext and shows an informational dialog on tap.
  Widget _chevronRow(BuildContext context, IconData icon, String label) =>
      GestureDetector(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Text(
                '$label settings will be available in a future update.',
                style: const TextStyle(color: kSlate500),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK',
                      style:
                          TextStyle(color: kTeal, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSlate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: kSlate500),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kSlate700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kSlate400),
            ],
          ),
        ),
      );
}
