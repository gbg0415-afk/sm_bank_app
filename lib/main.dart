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
  WidgetsFlutterBinding.ensureInitialized();
  try {
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
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_authState.loading) return const SplashScreen();
    if (_authState.error != null)
      return Scaffold(
          body:
              Center(child: Text("Initialization Error: ${_authState.error}")));
    if (_authState.user == null) return LoginScreen(authState: _authState);
    if (_authState.profile == null)
      return const Scaffold(
          backgroundColor: kSlate50,
          body: Center(child: CircularProgressIndicator(color: kTeal)));
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
            const Text('SM ACADEMY',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4)),
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
          child: Icon(Icons.school, size: size * 0.6, color: kTeal)),
    ),
  );
}

Widget _buildTextField(
    {required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text}) {
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
        style: const TextStyle(color: kSlate900),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kSlate400),
            prefixIcon: Icon(icon, color: kSlate400, size: 20)),
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
          email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
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
                    ]),
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
                    const SizedBox(height: 28),
                    if (_error.isNotEmpty) ...[
                      Text(_error,
                          style: const TextStyle(color: kRed, fontSize: 13)),
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
                            child: _loading
                                ? const CircularProgressIndicator()
                                : const Text('Sign In'))),
                    const SizedBox(height: 20),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                    authState: widget.authState))),
                        child: const Text('Register Now')),
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
// REGISTER SCREEN (Fixed Department & Stage Fetching)
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

  // FIXED: Fetching from 'departments' collection
  Future<void> _fetchDepartments() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('departments').get();
      setState(() {
        _departments = snap.docs
            .map((d) => Department(
                id: d.id,
                name: (d.data()['name'] ?? 'Unknown Department') as String))
            .toList();
        _fetchingDepts = false;
      });
    } catch (e) {
      debugPrint('Error fetching departments: $e');
      setState(() => _fetchingDepts = false);
    }
  }

  // FIXED: Fetching from 'departments/{id}/stages' sub-collection
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
            .map((d) => Stage(
                id: d.id,
                name: (d.data()['name'] ?? 'Unknown Stage') as String))
            .toList();
        _fetchingStages = false;
      });
    } catch (e) {
      debugPrint('Error fetching stages: $e');
      setState(() => _fetchingStages = false);
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
    try {
      final dept = _departments.firstWhere((d) => d.id == _selectedDeptId);
      final stage = _stages.firstWhere((s) => s.id == _selectedStageId);
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
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _logoWidget(size: 80),
              const SizedBox(height: 12),
              const Text('Create Account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 28),
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: kRed)),
              _buildTextField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  hint: 'John Doe',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'john@med.edu',
                  icon: Icons.mail_outline_rounded),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: true),
              const SizedBox(height: 16),

              // Department Dropdown
              _fetchingDepts
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedDeptId,
                      hint: const Text('Select Department'),
                      items: _departments
                          .map((d) => DropdownMenuItem(
                              value: d.id, child: Text(d.name)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedDeptId = val);
                        if (val != null) _fetchStages(val);
                      },
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.business)),
                    ),
              const SizedBox(height: 16),

              // Stage Dropdown
              _fetchingStages
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedStageId,
                      hint: Text(_selectedDeptId == null
                          ? 'Select Department First'
                          : 'Select Stage'),
                      items: _stages
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedStageId = val),
                      decoration:
                          const InputDecoration(prefixIcon: Icon(Icons.school)),
                    ),

              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: const Text('Register'))),
            ],
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
      ProfilePage(authState: widget.authState)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Subjects'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bookmark), label: 'Bookmarks'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ===========================================================================
// HOME & CATEGORIES (Keep Existing Logic)
// ===========================================================================
class HomePage extends StatelessWidget {
  final AuthState authState;
  const HomePage({super.key, required this.authState});
  @override
  Widget build(BuildContext context) {
    final profile = authState.profile;
    if (profile == null) return const SizedBox();
    return const Center(child: Text('Home Page Content'));
  }
}

class CategoriesPage extends StatefulWidget {
  final AuthState authState;
  const CategoriesPage({super.key, required this.authState});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.authState.profile;
    if (profile == null) return const SizedBox();
    return const Center(child: Text('Subjects Page Content'));
  }
}

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
  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
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
  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}

// ===========================================================================
// BOOKMARKS PAGE (Fixed Fetching)
// ===========================================================================
class BookmarksPage extends StatefulWidget {
  final AuthState authState;
  const BookmarksPage({super.key, required this.authState});
  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Question> _bookmarkedQuestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  // FIXED: Fetching from 'bookmarks' collection and resolving Question data
  Future<void> _fetchBookmarks() async {
    final profile = widget.authState.profile;
    if (profile == null) return;
    try {
      // 1. Get all bookmark entries for this user
      final bookmarkSnap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: profile.uid)
          .get();

      final List<Question> questions = [];

      // 2. For each bookmark, find the actual question text/options
      for (final doc in bookmarkSnap.docs) {
        final qId = doc.data()['questionId'] as String;

        // Use collectionGroup to find the question document anywhere in the hierarchy
        final qSnap = await FirebaseFirestore.instance
            .collectionGroup('questions')
            .where(FieldPath.documentId, isEqualTo: qId)
            .get();

        if (qSnap.docs.isNotEmpty) {
          questions.add(Question.fromMap(qId, qSnap.docs.first.data()));
        }
      }

      setState(() {
        _bookmarkedQuestions = questions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching bookmarks: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookmarks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarkedQuestions.isEmpty
              ? const Center(child: Text('No bookmarks found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _bookmarkedQuestions.length,
                  itemBuilder: (context, i) {
                    final q = _bookmarkedQuestions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(q.text,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    );
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(p.name,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign Out')),
        ],
      ),
    );
  }
}
