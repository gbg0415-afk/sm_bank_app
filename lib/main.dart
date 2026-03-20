import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

// --- MODELS ---

class UserStats {
  final int total;
  final int used;
  final int unused;

  UserStats({required this.total, required this.used, required this.unused});

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      total: map['totalQuestions'] ?? 0,
      used: map['usedQuestions'] ?? 0,
      unused: map['unusedQuestions'] ?? 0,
    );
  }
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String departmentId;
  final String departmentName;
  final String stageId;
  final String stageName;
  final UserStats stats;
  final List<dynamic> assignedSubjects;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.departmentId,
    required this.departmentName,
    required this.stageId,
    required this.stageName,
    required this.stats,
    required this.assignedSubjects,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      departmentId: data['departmentId'] ?? '',
      departmentName: data['departmentName'] ?? '',
      stageId: data['stageId'] ?? '',
      stageName: data['stageName'] ?? '',
      stats: UserStats.fromMap(data['stats'] ?? {}),
      assignedSubjects: data['assignedSubjects'] ?? [],
    );
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;

  QuestionOption({required this.id, required this.text, required this.isCorrect, required this.explanation});

  factory QuestionOption.fromMap(Map<String, dynamic> map) {
    return QuestionOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
      explanation: map['explanation'] ?? '',
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<QuestionOption> options;
  final String lectureId;

  Question({required this.id, required this.text, required this.options, required this.lectureId});

  factory Question.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Question(
      id: doc.id,
      text: data['questionText'] ?? data['text'] ?? '',
      lectureId: data['lectureId'] ?? '',
      options: (data['options'] as List).map((o) => QuestionOption.fromMap(o)).toList(),
    );
  }
}

// --- AUTH SERVICE ---

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserProfile? _profile;

  UserProfile? get profile => _profile;
  User? get user => _auth.currentUser;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _db.collection('users').doc(user.uid).snapshots().listen((snap) {
          if (snap.exists) {
            _profile = UserProfile.fromFirestore(snap);
            notifyListeners();
          }
        });
      } else {
        _profile = null;
        notifyListeners();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String name, String email, String password, String deptId, String deptName, String stageId, String stageName) async {
    UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _db.collection('users').doc(res.user!.uid).set({
      'uid': res.user!.uid,
      'name': name,
      'email': email,
      'departmentId': deptId,
      'departmentName': deptName,
      'stageId': stageId,
      'stageName': stageName,
      'assignedSubjects': [],
      'stats': {'totalQuestions': 0, 'usedQuestions': 0, 'unusedQuestions': 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() async => await _auth.signOut();
}

// --- MAIN APP ---

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
      title: 'SM Academy',
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
    final auth = Provider.of<AuthService>(context);
    if (auth.user != null) return const MainLayout();
    return const LoginPage();
  }
}

// --- NAVIGATION LAYOUT ---

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const CategoriesPage(),
    const BookmarksPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D9488),
        unselectedItemColor: Colors.blueGrey, // Fixed: slate replacement
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.book), label: 'Subjects'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.bookmark), label: 'Bookmarks'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- HOME PAGE ---

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthService>(context).profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('SM Academy', style: TextStyle(fontWeight: FontWeight.w900))), // Fixed: black replacement
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${profile.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(sections: [
                      PieChartSectionData(value: profile.stats.used.toDouble(), color: const Color(0xFF0D9488), radius: 50, title: ''),
                      PieChartSectionData(value: profile.stats.unused.toDouble(), color: Colors.grey[200], radius: 50, title: ''),
                    ])),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(child: Text("Track your progress across all your assigned medical subjects.")),
                ],
              ),
            ).animate().fadeIn().slideY(),
            const SizedBox(height: 20),
            _buildStatCard('Total Questions', profile.stats.total.toString(), LucideIcons.bookOpen, Colors.blue),
            _buildStatCard('Used Questions', profile.stats.used.toString(), LucideIcons.checkCircle2, Colors.teal),
            _buildStatCard('Unused Questions', profile.stats.unused.toString(), LucideIcons.circleDashed, Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon, Color col) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col)),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- SUBJECTS & LECTURES ---

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthService>(context).profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('My Subjects')),
      body: profile.assignedSubjects.isEmpty 
        ? const Center(child: Text("No subjects assigned yet."))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profile.assignedSubjects.length,
            itemBuilder: (context, index) {
              final sub = profile.assignedSubjects[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(LucideIcons.book, color: Color(0xFF0D9488)),
                  title: Text(sub['subjectName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LecturesPage(subject: sub))),
                ),
              );
            },
          ),
    );
  }
}

class LecturesPage extends StatelessWidget {
  final dynamic subject;
  const LecturesPage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subject['subjectName'])),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('departments')
            .doc(subject['departmentId'])
            .collection('stages')
            .doc(subject['stageId'])
            .collection('subjects')
            .doc(subject['subjectId'])
            .collection('lectures')
            .orderBy('order')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No lectures found."));
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final lec = snapshot.data!.docs[index];
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(LucideIcons.playCircle, color: Color(0xFF0D9488)),
                  title: Text(lec['name']),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizPage(
                        lectureId: lec.id,
                        path: lec.reference.path,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- QUIZ SYSTEM ---

class QuizPage extends StatefulWidget {
  final String lectureId;
  final String path;
  const QuizPage({super.key, required this.lectureId, required this.path});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Question> questions = [];
  int currentIndex = 0;
  bool loading = true;
  Map<String, dynamic> userAnswers = {}; 

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  _loadQuiz() async {
    final snap = await FirebaseFirestore.instance.doc(widget.path).collection('questions').get();
    setState(() {
      questions = snap.docs.map((d) => Question.fromFirestore(d)).toList();
      loading = false;
    });
  }

  _handleAnswer(QuestionOption opt) async {
    final q = questions[currentIndex];
    if (userAnswers.containsKey(q.id)) return;

    setState(() {
      userAnswers[q.id] = {'selectedId': opt.id, 'isCorrect': opt.isCorrect};
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('progress').doc(q.id).set({
      'selectedOptionId': opt.id,
      'isCorrect': opt.isCorrect,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'stats.usedQuestions': FieldValue.increment(1),
      'stats.unusedQuestions': FieldValue.increment(-1),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (questions.isEmpty) return const Scaffold(body: Center(child: Text("No questions found")));

    final q = questions[currentIndex];
    final ans = userAnswers[q.id];

    return Scaffold(
      appBar: AppBar(title: Text('Question ${currentIndex + 1}/${questions.length}')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (currentIndex + 1) / questions.length),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  ...q.options.map((opt) {
                    bool isSelected = ans?['selectedId'] == opt.id;
                    Color borderCol = Colors.grey[300]!;
                    Color bgCol = Colors.white;

                    if (ans != null) {
                      if (opt.isCorrect) {
                        borderCol = Colors.green;
                        bgCol = Colors.green[50]!;
                      } else if (isSelected) {
                        borderCol = Colors.red;
                        bgCol = Colors.red[50]!;
                      }
                    }

                    return GestureDetector(
                      onTap: () => _handleAnswer(opt),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgCol,
                          border: Border.all(color: borderCol, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (ans != null && (isSelected || opt.isCorrect))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(opt.explanation, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ).animate().fadeIn(),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                  onPressed: currentIndex < questions.length - 1 ? () => setState(() => currentIndex++) : () => Navigator.pop(context),
                  child: Text(currentIndex < questions.length - 1 ? "Next" : "Finish"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- LOGIN PAGE ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.bookOpen, size: 80, color: Color(0xFF0D9488)),
            const SizedBox(height: 20),
            const Text("SM Academy", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0D9488))),
            const SizedBox(height: 40),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(LucideIcons.mail))),
            const SizedBox(height: 16),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(LucideIcons.lock))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                onPressed: () async {
                  setState(() => loading = true);
                  try {
                    await Provider.of<AuthService>(context, listen: false).signIn(_email.text, _pass.text);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                  setState(() => loading = false);
                },
                child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Sign In"),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
              child: const Text("Create an account"),
            )
          ],
        ),
      ),
    );
  }
}

// --- REGISTER PAGE ---

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text("Register", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(LucideIcons.user))),
            const SizedBox(height: 16),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(LucideIcons.mail))),
            const SizedBox(height: 16),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(LucideIcons.lock))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                onPressed: () async {
                  setState(() => loading = true);
                  try {
                    // Simplified registration for main.dart template
                    await Provider.of<AuthService>(context, listen: false).register(
                      _name.text, _email.text, _pass.text, "dept_01", "General Medicine", "stage_01", "Level 1"
                    );
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                  setState(() => loading = false);
                },
                child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- BOOKMARKS & PROFILE ---

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Bookmarks Page")));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: CircleAvatar(radius: 50, child: Icon(LucideIcons.user, size: 50))),
          const SizedBox(height: 20),
          Center(child: Text(auth.profile?.name ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 40),
          ListTile(leading: const Icon(LucideIcons.mail), title: const Text("Email"), subtitle: Text(auth.profile?.email ?? "")),
          ListTile(leading: const Icon(LucideIcons.building), title: const Text("Department"), subtitle: Text(auth.profile?.departmentName ?? "")),
          ListTile(leading: const Icon(LucideIcons.graduationCap), title: const Text("Stage"), subtitle: Text(auth.profile?.stageName ?? "")),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => auth.signOut(),
          ),
        ],
      ),
    );
  }
}
