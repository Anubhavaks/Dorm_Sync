import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

// Import your pages (Make sure these file names match yours!)
import 'student.dart'; 
import 'warden.dart';

void main() async {
  // Required when doing async work before runApp
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // Check if user is already logged in
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedRole = prefs.getString('role');
  String? savedId = prefs.getString('studentId');

  // Decide which page to show first
  Widget initialPage = LoginPage(); // Default
  if (savedRole == 'warden') {
    initialPage = WardenPage();
  } else if (savedRole == 'student' && savedId != null) {
    initialPage = StudentDashboard(studentId: savedId);
  }

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: initialPage, // <-- Uses the saved state to skip login!
    
    // Your beautiful Material 3 Theme
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
      scaffoldBackgroundColor: Color(0xFFF5F7FA), 
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
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
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo, width: 2)),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
  ));
}

// ==========================================
// LOGIN PAGE WITH SECURE STORAGE
// ==========================================
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isLoading = false;

  Future<void> handleLogin() async {
    setState(() { isLoading = true; });

    String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2";
    var url = Uri.parse('http://$ip:8000/login');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": userController.text, "password": passController.text}),
      );

      var data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // --- SAVE CREDENTIALS LOCALLY ---
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', data['role']);
        await prefs.setString('studentId', data['username']);

        // --- NAVIGATE ---
        if (data['role'] == 'warden') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WardenPage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StudentDashboard(studentId: data['username'])));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid Credentials!"), backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server Error! Check connection.")));
    }

    setState(() { isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.domain, size: 80, color: Colors.indigo),
              SizedBox(height: 20),
              Text("Hostel Mate", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
              SizedBox(height: 40),
              
              TextField(
                controller: userController, 
                decoration: InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))
              ),
              SizedBox(height: 15),
              TextField(
                controller: passController, 
                obscureText: true, 
                decoration: InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))
              ),
              SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleLogin,
                  child: isLoading ? CircularProgressIndicator(color: Colors.white) : Text("LOGIN"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}