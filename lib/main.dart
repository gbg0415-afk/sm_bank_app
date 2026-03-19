import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const MedQuestApp(),
    ),
  );
}

class MedQuestApp extends StatelessWidget {
  const MedQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal[600],
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==========================================
// MODELS
// ==========================================

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? departmentName;
  final String? stageName;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.departmentName,
    this.stageName,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      name: data['name'] ?? 'Medical Student',
      email: data['email'] ?? '',
      departmentName: data['departmentName'],
      stageName: data['stageName'],
    );
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  factory QuestionOption.fromMap(Map<String, dynamic> data) {
    return QuestionOption(
      id: data['id'] ?? data['text'] ?? '',
      text: data['text'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<QuestionOption> options;
  final String lectureId;
  final String? subjectId;
  final String? explanation;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.lectureId,
    this.subjectId,
    this.explanation,
  });

  factory Question.fromMap(Map<String, dynamic> data, String documentId) {
    var optionsList =
        (data['options'] as List?)
            ?.map((o) => QuestionOption.fromMap(o as Map<String, dynamic>))
            .toList() ??
        [];
    return Question(
      id: documentId,
      text: data['text'] ?? data['questionText'] ?? 'Untitled Question',
      options: optionsList,
      lectureId: data['lectureId'] ?? '',
      subjectId: data['subjectId'],
      explanation: data['explanation'],
    );
  }
}

// ==========================================
// PROVIDERS
// ==========================================

class AuthProvider extends ChangeNotifier {
  User? _firebaseUser;
  UserProfile? _profile;

  User? get firebaseUser => _firebaseUser;
  UserProfile? get profile => _profile;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          _profile = UserProfile.fromMap(doc.data()!, doc.id);
        } else {
          // Fallback if user doc doesn't exist yet
          _profile = UserProfile(
            uid: user.uid,
            name: "Guest User",
            email: user.email ?? "",
          );
        }
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}

// ==========================================
// SCREENS
// ==========================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.firebaseUser == null) {
      return const LoginScreen();
    }
    return const MainNavigationScreen();
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital, size: 80, color: Colors.teal[600]),
              const SizedBox(height: 16),
              const Text(
                "MedQuest",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Master your medical studies",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signInAnonymously();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                },
                child: const Text(
                  "Continue as Guest (Test Mode)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const BookmarksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal[600],
        unselectedItemColor: Colors.grey[400],
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- HOME / DASHBOARD SCREEN ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context).profile;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, ${profile?.name ?? 'Doctor'} 👋",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ready for today's practice?",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[400]!, Colors.teal[700]!],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.science, color: Colors.white, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    "General Pathology",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Lecture 1: Cell Injury & Death",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      // Pass a dummy lecture ID or a real one from your database
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuizScreen(lectureId: 'dummy_lecture_123'),
                        ),
                      );
                    },
                    child: const Text(
                      "Start Quiz",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

// --- QUIZ SCREEN ---
class QuizScreen extends StatefulWidget {
  final String lectureId;
  const QuizScreen({super.key, required this.lectureId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  List<Question> _questions = [];
  int _currentIndex = 0;
  int _score = 0;

  bool _isAnswerChecked = false;
  String? _selectedOptionId;
  Set<String> _bookmarkedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    _fetchUserBookmarks();
  }

  Future<void> _fetchQuestions() async {
    try {
      // In a real app, you'd filter by lectureId: .where('lectureId', isEqualTo: widget.lectureId)
      // For testing, we fetch any questions or use mock data if DB is empty.
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .limit(10)
          .get();

      if (snap.docs.isEmpty) {
        // Mock Data for demonstration if Firestore is empty
        _questions = [
          Question(
            id: 'q1',
            text: 'What is the powerhouse of the cell?',
            lectureId: widget.lectureId,
            explanation:
                'Mitochondria generate most of the chemical energy needed to power the cell.',
            options: [
              QuestionOption(id: 'o1', text: 'Nucleus', isCorrect: false),
              QuestionOption(id: 'o2', text: 'Mitochondria', isCorrect: true),
              QuestionOption(id: 'o3', text: 'Ribosome', isCorrect: false),
            ],
          ),
          Question(
            id: 'q2',
            text: 'Which organ is primarily responsible for filtering blood?',
            lectureId: widget.lectureId,
            explanation:
                'The kidneys filter blood to remove wastes and produce urine.',
            options: [
              QuestionOption(id: 'o1', text: 'Heart', isCorrect: false),
              QuestionOption(id: 'o2', text: 'Liver', isCorrect: false),
              QuestionOption(id: 'o3', text: 'Kidney', isCorrect: true),
            ],
          ),
        ];
      } else {
        _questions = snap.docs
            .map((doc) => Question.fromMap(doc.data(), doc.id))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print("Error fetching questions: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserBookmarks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('bookmarks')
        .where('userId', isEqualTo: user.uid)
        .get();

    setState(() {
      _bookmarkedQuestionIds = snap.docs
          .map((d) => d.data()['questionId'] as String)
          .toSet();
    });
  }

  Future<void> _toggleBookmark(Question q) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('bookmarks')
        .doc('${user.uid}_${q.id}');

    if (_bookmarkedQuestionIds.contains(q.id)) {
      await docRef.delete();
      setState(() => _bookmarkedQuestionIds.remove(q.id));
    } else {
      await docRef.set({
        'userId': user.uid,
        'questionId': q.id,
        'questionPath': 'questions/${q.id}', // Save path for easy retrieval
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _bookmarkedQuestionIds.add(q.id));
    }
  }

  void _checkAnswer() {
    if (_selectedOptionId == null) return;

    setState(() {
      _isAnswerChecked = true;
      final correctOption = _questions[_currentIndex].options.firstWhere(
        (o) => o.isCorrect,
        orElse: () => QuestionOption(id: '', text: '', isCorrect: false),
      );
      if (_selectedOptionId == correctOption.id) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswerChecked = false;
        _selectedOptionId = null;
      });
    } else {
      // Quiz Finished
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuizResultScreen(score: _score, total: _questions.length),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Quiz"), backgroundColor: Colors.teal),
        body: const Center(child: Text("No questions found for this lecture.")),
      );
    }

    final question = _questions[_currentIndex];
    final isBookmarked = _bookmarkedQuestionIds.contains(question.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          "Question ${_currentIndex + 1} of ${_questions.length}",
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.teal : Colors.grey,
            ),
            onPressed: () => _toggleBookmark(question),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.text,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...question.options.map((option) {
                      bool isSelected = _selectedOptionId == option.id;
                      bool showCorrect = _isAnswerChecked && option.isCorrect;
                      bool showWrong =
                          _isAnswerChecked && isSelected && !option.isCorrect;

                      Color borderColor = Colors.grey[300]!;
                      Color bgColor = Colors.white;
                      Color textColor = Colors.black87;

                      if (_isAnswerChecked) {
                        if (showCorrect) {
                          borderColor = Colors.green;
                          bgColor = Colors.green[50]!;
                          textColor = Colors.green[800]!;
                        } else if (showWrong) {
                          borderColor = Colors.red;
                          bgColor = Colors.red[50]!;
                          textColor = Colors.red[800]!;
                        }
                      } else if (isSelected) {
                        borderColor = Colors.teal;
                        bgColor = Colors.teal[50]!;
                        textColor = Colors.teal[800]!;
                      }

                      return GestureDetector(
                        onTap: _isAnswerChecked
                            ? null
                            : () {
                                setState(() => _selectedOptionId = option.id);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (_isAnswerChecked && showCorrect)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              if (_isAnswerChecked && showWrong)
                                const Icon(Icons.cancel, color: Colors.red),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (_isAnswerChecked &&
                        question.explanation != null &&
                        question.explanation!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Explanation",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              question.explanation!,
                              style: TextStyle(
                                color: Colors.blue[900],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  onPressed: _selectedOptionId == null
                      ? null
                      : (_isAnswerChecked ? _nextQuestion : _checkAnswer),
                  child: Text(
                    _isAnswerChecked
                        ? (_currentIndex == _questions.length - 1
                              ? "Finish Quiz"
                              : "Next Question")
                        : "Check Answer",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- QUIZ RESULT SCREEN ---
class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;

  const QuizResultScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    double percentage = total == 0 ? 0 : (score / total) * 100;
    bool passed = percentage >= 60;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 100,
                color: passed ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                passed ? "Great Job!" : "Keep Practicing!",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You scored $score out of $total",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Return to Dashboard",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- BOOKMARKS SCREEN ---
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  bool _isLoading = true;
  List<Question> _bookmarkedQuestions = [];

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: user.uid)
          .get();

      List<Question> questions = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        String? path = data['questionPath'];
        String qId = data['questionId'];

        DocumentSnapshot qSnap;
        if (path != null) {
          qSnap = await FirebaseFirestore.instance.doc(path).get();
        } else {
          qSnap = await FirebaseFirestore.instance
              .collection('questions')
              .doc(qId)
              .get();
        }

        if (qSnap.exists) {
          questions.add(
            Question.fromMap(qSnap.data() as Map<String, dynamic>, qSnap.id),
          );
        }
      }

      setState(() {
        _bookmarkedQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching bookmarks: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(String questionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('bookmarks')
        .doc('${user.uid}_$questionId')
        .delete();
    setState(() {
      _bookmarkedQuestions.removeWhere((q) => q.id == questionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "Saved Questions",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "Review and master the concepts you've flagged.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _bookmarkedQuestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No bookmarks yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _bookmarkedQuestions.length,
                      itemBuilder: (context, index) {
                        final q = _bookmarkedQuestions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: ExpansionTile(
                            iconColor: Colors.teal,
                            collapsedIconColor: Colors.grey,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.teal[600],
                                size: 20,
                              ),
                            ),
                            title: Text(
                              q.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.text,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...q.options.map(
                                      (o) => Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: o.isCorrect
                                              ? Colors.green[50]
                                              : Colors.white,
                                          border: Border.all(
                                            color: o.isCorrect
                                                ? Colors.green[300]!
                                                : Colors.grey[200]!,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                o.text,
                                                style: TextStyle(
                                                  color: o.isCorrect
                                                      ? Colors.green[800]
                                                      : Colors.black87,
                                                  fontWeight: o.isCorrect
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (o.isCorrect)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green[500],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (q.explanation != null &&
                                        q.explanation!.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.lightbulb_outline,
                                                  color: Colors.amber[600],
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  "Explanation",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              q.explanation!,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () =>
                                                _removeBookmark(q.id),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            label: const Text("Remove"),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red[400],
                                              backgroundColor: Colors.red[50],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => QuizScreen(
                                                  lectureId: q.lectureId,
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.menu_book,
                                              size: 18,
                                            ),
                                            label: const Text("Practice"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal[600],
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

// --- PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.profile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.teal[100],
                child: Icon(Icons.person, size: 48, color: Colors.teal[600]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              profile.email.isNotEmpty ? profile.email : "Guest User",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildSection("Account Settings", [
              _buildListTile(
                Icons.person_outline,
                "Personal Information",
                profile.name,
              ),
              _buildListTile(
                Icons.business,
                "Department",
                profile.departmentName ?? "Not Assigned",
              ),
              _buildListTile(
                Icons.school,
                "Academic Stage",
                profile.stageName ?? "Not Assigned",
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection("Preferences", [
              _buildListTile(
                Icons.notifications_none,
                "Notifications",
                "Enabled",
                isToggle: true,
              ),
              _buildListTile(
                Icons.dark_mode_outlined,
                "Dark Mode",
                "Disabled",
                isToggle: true,
              ),
            ]),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text("Sign Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[600],
                elevation: 0,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red[100]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "MedQuest v1.0.0",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String subtitle, {
    bool isToggle = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.grey[600], size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
          letterSpacing: 0.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      trailing: isToggle
          ? Switch(
              value: subtitle == "Enabled",
              onChanged: (val) {},
              activeThumbColor: Colors.teal,
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
