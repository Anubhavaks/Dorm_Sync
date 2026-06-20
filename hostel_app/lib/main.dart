import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import your pages (File naming conventions verified)
import 'student.dart'; 
import 'warden.dart';

void main() async {
  // Required when performing async initialization tasks prior to running the UI app layout
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // Initialize the hardware-backed secure storage vault
  const secureStorage = FlutterSecureStorage();
  
  // Check if a secure active session already exists on boot
  String? savedRole = await secureStorage.read(key: 'user_role');
  String? savedId = await secureStorage.read(key: 'username');
  String? token = await secureStorage.read(key: 'jwt_token');

  // Route calculation based on state session keys
  Widget initialPage = LoginPage(); 
  if (token != null && savedRole != null) {
    if (savedRole == 'warden') {
      initialPage = WardenPage();
    } else if (savedRole == 'student' && savedId != null) {
      initialPage = StudentDashboard(studentId: savedId);
    }
  }

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: initialPage, 
    
    // Enterprise Material 3 Theme Configuration
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA), 
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.indigo, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
  ));
}

// ==========================================
// SECURE LOGIN PAGE WITH CRYPTOGRAPHIC STORAGE
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final secureStorage = const FlutterSecureStorage();
  bool isLoading = false;

  Future<void> handleLogin() async {
    if (userController.text.trim().isEmpty || passController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fields cannot be empty!"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() { isLoading = true; });

    // Switched from local testing loop to your live production cloud gateway address
    var url = Uri.parse('https://dorm-sync.onrender.com/login');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": userController.text.trim(), 
          "password": passController.text.trim()
        }),
      );

      var data = jsonDecode(response.body);

      // Backend now strictly throws 401/error objects or sets a state context message
      if (response.statusCode == 200 && data['status'] == 'success') {
        
        // --- SECURE CRYPTO HARDWARE STORAGE WRITE ---
        await secureStorage.write(key: 'jwt_token', value: data['access_token']);
        await secureStorage.write(key: 'user_role', value: data['role']);
        await secureStorage.write(key: 'username', value: data['username']);

        // --- DASHBOARD ROUTING INTERACTION ---
        if (data['role'] == 'warden') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WardenPage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StudentDashboard(studentId: data['username'])));
        }
      } else {
        String errMsg = data['detail'] ?? "Invalid Credentials!";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server Error! Check production connection.")));
    }

    setState(() { isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.domain, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text("Dorm_Sync", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 40),
              
              TextField(
                controller: userController, 
                decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passController, 
                obscureText: true, 
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleLogin,
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOGIN"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}