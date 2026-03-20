import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const SMAcademyApp(),
    ),
  );
}

class SMAcademyApp extends StatelessWidget {
  const SMAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SM Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0d9488),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1e293b)),
          titleTextStyle: TextStyle(color: Color(0xFF1e293b), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0d9488),
          primary: const Color(0xFF0d9488),
        ),
        useMaterial3: true,
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
  final Map<String, dynamic> stats;

  UserProfile({required this.uid, required this.name, required this.email, required this.stats});

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      name: data['name'] ?? 'Student',
      email: data['email'] ?? '',
      stats: data['stats'] ?? {'usedQuestions': 0, 'totalQuestions': 0},
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
        await fetchUserProfile(user.uid);
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchUserProfile(String uid) async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      _profile = UserProfile.fromMap(doc.data()!, doc.id);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}

// ==========================================
// AUTH WRAPPER
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

// ==========================================
// AUTHENTICATION SCREENS
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFf0fdfa), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(LucideIcons.graduationCap, size: 80, color: Color(0xFF0d9488)),
                ),
                const SizedBox(height: 24),
                const Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                const SizedBox(height: 8),
                const Text("Sign in to continue your progress", style: TextStyle(color: Color(0xFF64748b))),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: const Icon(LucideIcons.mail),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(LucideIcons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0d9488),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Color(0xFF64748b)),
                      children: [TextSpan(text: "Sign Up", style: TextStyle(color: Color(0xFF0d9488), fontWeight: FontWeight.bold))],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCred.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {'usedQuestions': 0, 'totalQuestions': 100}, // Dummy initial stats
        });
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Sign up failed")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.white),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                const SizedBox(height: 8),
                const Text("Join SM Academy today", style: TextStyle(color: Color(0xFF64748b))),
                const SizedBox(height: 48),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: const Icon(LucideIcons.user),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: const Icon(LucideIcons.mail),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(LucideIcons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0d9488),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MAIN NAVIGATION (BOTTOM TABS)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const BookmarksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFe2e8f0), width: 1))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xFF0d9488),
          unselectedItemColor: const Color(0xFF94a3b8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.bookOpen), label: 'Categories'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.bookmark), label: 'Bookmarks'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HOME SCREEN
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context).profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    double used = (profile.stats['usedQuestions'] ?? 0).toDouble();
    double total = (profile.stats['totalQuestions'] ?? 0).toDouble();
    double percentage = total > 0 ? (used / total) : 0;
    
    // إصلاح مشكلة ظهور الكود كنص
    int percentInt = (percentage * 100).round();
    String percentageText = "$percentInt%";

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("SM Academy", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0d9488))),
                    const SizedBox(height: 4),
                    Text("Welcome, ${profile.name}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: const Color(0xFFccfbf1),
                  radius: 24,
                  child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 20, color: Color(0xFF0d9488), fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),
            const Text("Track your progress and keep learning.", style: TextStyle(fontSize: 16, color: Color(0xFF64748b))),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFf1f5f9)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: percentage == 0 ? 0.01 : percentage, // لتجنب الدائرة الفارغة تماماً
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFe2e8f0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0d9488)),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        children: [
                          Text(percentageText, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                          const Text("COMPLETED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94a3b8), letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFf0fdfa), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFccfbf1))),
                          child: const Icon(LucideIcons.trendingUp, color: Color(0xFF0d9488), size: 20),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Overall Progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                              Text("You're making great progress!", style: TextStyle(fontSize: 14, color: Color(0xFF0f766e))),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, color: Color(0xFF0d9488), size: 20),
                      ],
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

// ==========================================
// CATEGORIES SCREEN
// ==========================================
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // قائمة تجريبية للأقسام لكي لا تكون الشاشة فارغة
    final List<Map<String, dynamic>> dummyCategories = [
      {'title': 'Anatomy', 'icon': LucideIcons.bone, 'color': Colors.blue},
      {'title': 'Pathology', 'icon': LucideIcons.microscope, 'color': Colors.red},
      {'title': 'Pharmacology', 'icon': LucideIcons.pill, 'color': Colors.green},
      {'title': 'Physiology', 'icon': LucideIcons.activity, 'color': Colors.orange},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
        builder: (context, snapshot) {
          // إذا لم تكن هناك بيانات حقيقية في فايربيس، سنعرض القائمة التجريبية بتصميم جميل
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1
              ),
              itemCount: dummyCategories.length,
              itemBuilder: (context, index) {
                final cat = dummyCategories[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFe2e8f0)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: (cat['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(cat['icon'], color: cat['color'], size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(cat['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1e293b))),
                    ],
                  ),
                );
              },
            );
          }
          
          // الكود في حال وجود بيانات حقيقية
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFe2e8f0))),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(backgroundColor: Color(0xFFf0fdfa), child: Icon(LucideIcons.book, color: Color(0xFF0d9488))),
                  title: Text(doc['name'] ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFF94a3b8)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// BOOKMARKS SCREEN
// ==========================================
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Bookmarks")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookmarks').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // واجهة فارغة جميلة في حال لم يقم المستخدم بحفظ أي شيء
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFFf1f5f9), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.bookmark, size: 64, color: Color(0xFF94a3b8)),
                  ),
                  const SizedBox(height: 24),
                  const Text("No Bookmarks Yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                  const SizedBox(height: 8),
                  const Text("Save questions to review them later.", style: TextStyle(color: Color(0xFF64748b))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFe2e8f0)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.bookmark, color: const Color(0xFF0d9488)),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text("Saved Question Title Here", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1e293b))),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                      onPressed: () => snapshot.data!.docs[index].reference.delete(),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFccfbf1),
                    child: Text(profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 36, color: Color(0xFF0d9488), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text(profile?.name ?? "Student User", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                  const SizedBox(height: 4),
                  Text(profile?.email ?? "email@example.com", style: const TextStyle(fontSize: 14, color: Color(0xFF64748b))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Settings Options
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFe2e8f0))),
              child: Column(
                children: [
                  _buildProfileTile(icon: LucideIcons.settings, title: "Account Settings"),
                  const Divider(height: 1, color: Color(0xFFe2e8f0)),
                  _buildProfileTile(icon: LucideIcons.bell, title: "Notifications"),
                  const Divider(height: 1, color: Color(0xFFe2e8f0)),
                  _buildProfileTile(icon: LucideIcons.helpCircle, title: "Help & Support"),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfef2f2),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFfecaca))),
              ),
              icon: const Icon(LucideIcons.logOut),
              label: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => auth.signOut(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF475569), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1e293b))),
      trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFF94a3b8), size: 20),
      onTap: () {}, // Action for later
    );
  }
}
