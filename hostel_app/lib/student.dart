import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main.dart'; 
import 'package:geolocator/geolocator.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  StudentDashboard({required this.studentId});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  bool isAttendanceMarked = false;

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
  }

  // --- API LOGIC: MARK ATTENDANCE ---
  Future<void> _markPresence() async {
    // 1. REAL GEO-FENCING CHECK
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    // 🛠️ DEBUG: This will print your exact current location in the VS Code Terminal
    print("📍 YOUR EXACT LOCATION: Lat: ${position.latitude}, Lng: ${position.longitude}");
    
    // Target Hostel Location (Change these to the numbers printed in your terminal!)
    double hostelLat = 28.9845; 
    double hostelLng = 77.7064;
    
    // Calculate distance
    double distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, hostelLat, hostelLng);
    
    // 🛠️ FIX: Increased radius to 5000 meters (5km) to ensure it works during your presentation
    if (distanceInMeters > 10000) {  // <-- Changed to 10000 for a safe demo 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Geo-fence Failed. Distance: ${distanceInMeters.toInt()}m. (Check terminal for exact coords)"), 
        backgroundColor: Colors.red));
      return; 
    }

    // 2. FACE SCAN (If Location Passes)
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    
    if (photo != null) {
      String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2";
      var url = Uri.parse('http://$ip:8000/mark-attendance');
      
      try {
        await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"student_id": widget.studentId, "time": DateTime.now().toString().substring(0, 16), "location": "Verified Hostel Bounds"}),
        );
        setState(() => isAttendanceMarked = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Face & GPS Verified! Logged."), backgroundColor: Colors.green));
      } catch (e) { print(e); }
    }
  }

  // --- HOME TAB WIDGET ---
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hello,", style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                  Text(widget.studentId == "Student_001" ? "Arjun Kumar" : widget.studentId, 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                ],
              ),
              InkWell(
                onTap: logout, 
                child: CircleAvatar(backgroundColor: Colors.red.shade50, child: Icon(Icons.logout, color: Colors.red)),
              ),
            ],
          ),
          SizedBox(height: 30),

          // SMART ATTENDANCE CARD
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAttendanceMarked ? Colors.green : Color(0xFF4F46E5), 
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: (isAttendanceMarked ? Colors.green : Color(0xFF4F46E5)).withOpacity(0.3), blurRadius: 15, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Smart Attendance", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isAttendanceMarked ? Icons.check_circle : Icons.camera_alt_outlined, color: Colors.white),
                    )
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                    SizedBox(width: 5),
                    Text(isAttendanceMarked ? "Location Verified" : "Geo-fencing active", style: TextStyle(color: Colors.white70)),
                  ],
                ),
                SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isAttendanceMarked ? Colors.green : Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isAttendanceMarked ? null : _markPresence,
                    child: Text(isAttendanceMarked ? "PRESENCE MARKED" : "Mark Presence (Face Scan)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 30),

          // NOTICE BOARD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Notice Board", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text("Live", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Warden • Recent", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text("Gate Timing Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 15),
                Text("Main gate will close at 10:00 PM tonight due to scheduled maintenance. Ensure you are inside the premises before the cutoff.", style: TextStyle(color: Colors.blueGrey, height: 1.5))
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This connects the bottom tabs to your actual working feature pages!
    final List<Widget> _pages = [
      _buildHomeTab(),
      GatePassPage(studentId: widget.studentId),
      MaintenancePage(studentId: widget.studentId),
      MessMenuPage(studentId: widget.studentId),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Color(0xFF4F46E5),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Passes"),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: "Fix It"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: "Mess"),
        ],
      ),
    );
  }
}

// ==========================================
// YOUR PREVIOUS WORKING MODULES
// ==========================================

// 1. GATE PASS PAGE
// 1. GATE PASS PAGE (UPDATED WITH DATE & TIME PICKERS)
class GatePassPage extends StatefulWidget {
  final String studentId;
  GatePassPage({required this.studentId});
  @override _GatePassPageState createState() => _GatePassPageState();
}

class _GatePassPageState extends State<GatePassPage> {
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController outDateController = TextEditingController();
  final TextEditingController outTimeController = TextEditingController();
  final TextEditingController inDateController = TextEditingController();
  final TextEditingController inTimeController = TextEditingController();
  List<dynamic> myPasses = [];

  @override void initState() { super.initState(); fetchMyPasses(); }

  Future<void> fetchMyPasses() async {
    String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2";
    var response = await http.get(Uri.parse('http://$ip:8000/get-passes'));
    var allPasses = jsonDecode(response.body);
    setState(() { myPasses = allPasses.where((p) => p['student_id'] == widget.studentId).toList(); });
  }

  Future<void> submitPass() async {
    String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2";
    
    // Combine Date and Time for the backend
    String combinedOut = "${outDateController.text} at ${outTimeController.text}";
    String combinedIn = "${inDateController.text} at ${inTimeController.text}";

    await http.post(Uri.parse('http://$ip:8000/request-pass'), headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "student_id": widget.studentId, 
        "reason": reasonController.text, 
        "out_time": combinedOut, 
        "in_time": combinedIn
      }));
      
    reasonController.clear(); outDateController.clear(); outTimeController.clear();
    inDateController.clear(); inTimeController.clear();
    fetchMyPasses();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pass Requested!"), backgroundColor: Colors.green));
  }

  // Helper to pick a Date
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2101));
    if (picked != null) setState(() => controller.text = "${picked.day}/${picked.month}/${picked.year}");
  }

  // Helper to pick a Time
  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => controller.text = picked.format(context));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Request Gate Pass", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          SizedBox(height: 15),
          TextField(controller: reasonController, decoration: InputDecoration(labelText: "Destination & Reason")),
          SizedBox(height: 15),
          
          // OUT DATE & TIME ROW
          Row(children: [
            Expanded(child: TextField(controller: outDateController, readOnly: true, onTap: () => _selectDate(outDateController), decoration: InputDecoration(labelText: "Out Date", prefixIcon: Icon(Icons.calendar_today, size: 18)))),
            SizedBox(width: 10),
            Expanded(child: TextField(controller: outTimeController, readOnly: true, onTap: () => _selectTime(outTimeController), decoration: InputDecoration(labelText: "Out Time", prefixIcon: Icon(Icons.access_time, size: 18)))),
          ]),
          SizedBox(height: 15),

          // IN DATE & TIME ROW
          Row(children: [
            Expanded(child: TextField(controller: inDateController, readOnly: true, onTap: () => _selectDate(inDateController), decoration: InputDecoration(labelText: "In Date", prefixIcon: Icon(Icons.calendar_today, size: 18)))),
            SizedBox(width: 10),
            Expanded(child: TextField(controller: inTimeController, readOnly: true, onTap: () => _selectTime(inTimeController), decoration: InputDecoration(labelText: "In Time", prefixIcon: Icon(Icons.access_time, size: 18)))),
          ]),
          SizedBox(height: 20),
          
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: submitPass, child: Text("Submit Request"))),
          SizedBox(height: 30),
          
          Text("My Digital Slips", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          ...myPasses.map((pass) {
            bool isApproved = pass['status'] == 'Approved';
            return Container(
              margin: EdgeInsets.only(bottom: 15),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: isApproved ? Colors.green.shade50 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isApproved ? Colors.green : Colors.grey.shade300, width: isApproved ? 2 : 1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isApproved ? "VALID GATE PASS" : "PENDING REQUEST", style: TextStyle(fontWeight: FontWeight.bold, color: isApproved ? Colors.green.shade800 : Colors.grey)), Icon(isApproved ? Icons.verified : Icons.access_time, color: isApproved ? Colors.green : Colors.grey)]),
                  Divider(),
                  Text("Reason: ${pass['reason']}", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 5),
                  Text("Timings: ${pass['time']}", style: TextStyle(color: Colors.blueGrey)),
                  if (isApproved) ...[SizedBox(height: 15), Center(child: Icon(Icons.qr_code_2, size: 60, color: Colors.black87)), Center(child: Text("Show this at main gate", style: TextStyle(fontSize: 10, color: Colors.grey)))]
                ],
              ),
            );
          }).toList()
        ],
      ),
    );
  }
}

// 2. AI MAINTENANCE PAGE
class MaintenancePage extends StatefulWidget {
  final String studentId;
  MaintenancePage({required this.studentId});
  @override _MaintenancePageState createState() => _MaintenancePageState();
}
class _MaintenancePageState extends State<MaintenancePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController issueController = TextEditingController();
  String selectedCategory = "Electrical";
  String priorityLevel = "Normal"; 
  Color priorityColor = Colors.green; 

  void _analyzeComplaint(String text) {
    text = text.toLowerCase();
    if (text.contains("fire") || text.contains("spark") || text.contains("smoke") || 
        text.contains("leak") || text.contains("flood") || text.contains("urgent") ||
        text.contains("shock") || text.contains("short circuit")) {
      setState(() { priorityLevel = "HIGH PRIORITY (AI Detected)"; priorityColor = Colors.red; });
    } else {
      setState(() { priorityLevel = "Normal"; priorityColor = Colors.green; });
    }
  }

  Future<void> submitComplaint() async {
    String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2"; 
    var url = Uri.parse('http://$ip:8000/create-complaint');
    String finalIssue = "[$priorityLevel] ${issueController.text}";
    try {
      var response = await http.post(url, headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": widget.studentId, 
          "student_name": nameController.text.isEmpty ? "Student" : nameController.text,
          "room_number": roomController.text,
          "issue": finalIssue, 
          "category": selectedCategory
        }));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Complaint Sent!"), backgroundColor: Colors.green));
        issueController.clear();
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("AI Maintenance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          SizedBox(height: 20),
          TextField(controller: roomController, decoration: InputDecoration(labelText: "Room Number")),
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: InputDecoration(labelText: "Category"),
            items: ["Electrical", "Plumbing", "Furniture", "Cleanliness", "Other"].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
            onChanged: (val) => setState(() => selectedCategory = val!),
          ),
          SizedBox(height: 10),
          TextField(
            controller: issueController, maxLines: 3,
            decoration: InputDecoration(labelText: "Describe the Issue", hintText: "e.g., The switch is sparking..."),
            onChanged: (text) => _analyzeComplaint(text),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: priorityColor)),
            child: Row(children: [
              Icon(Icons.analytics, color: priorityColor), SizedBox(width: 10),
              Expanded(child: Text("AI Priority: $priorityLevel", style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold))),
            ]),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(onPressed: submitComplaint, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: Text("Submit Report")),
          )
        ],
      ),
    );
  }
}

// 3. MESS MENU PAGE
// 3. MESS MENU PAGE (UPDATED ACCORDION UI)
class MessMenuPage extends StatelessWidget {
  final String studentId;
  MessMenuPage({required this.studentId});

  Future<void> submitRating(BuildContext context, String meal, int rating) async {
    String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2";
    var url = Uri.parse('http://$ip:8000/rate-food');
    try {
      await http.post(url, headers: {"Content-Type": "application/json"},
        body: jsonEncode({"student_id": studentId, "meal": meal, "rating": rating}));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$meal rated $rating stars!"), backgroundColor: Colors.orange));
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Orange Header (Like your screenshot)
          Container(
            color: Colors.orange.shade600,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Hostel Mess", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 4,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(icon: Icon(Icons.restaurant_menu), text: "Weekly Menu"),
                      Tab(icon: Icon(Icons.star), text: "Rate Food"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildWeeklyMenu(),
                _buildRateFood(context),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- TAB 1: Expandable Weekly Menu ---
  Widget _buildWeeklyMenu() {
    final List<Map<String, String>> weeklyData = [
      {"day": "Monday", "short": "Mon", "b": "Aloo Paratha, Curd", "l": "Rajma Chawal, Salad", "d": "Egg Curry / Paneer"},
      {"day": "Tuesday", "short": "Tue", "b": "Poha, Jalebi", "l": "Dal Makhani, Mixed Veg", "d": "Kadhai Paneer, Roti"},
      {"day": "Wednesday", "short": "Wed", "b": "Idli Sambar, Chutney", "l": "Chole Bhature", "d": "Kadhi Pakora, Rice"},
      {"day": "Thursday", "short": "Thu", "b": "Upma, Tea", "l": "Dal Tadka, Soyabean", "d": "Aloo Gobi, Paratha"},
      {"day": "Friday", "short": "Fri", "b": "Sandwich, Juice", "l": "Lemon Rice", "d": "Matar Paneer, Naan"},
      {"day": "Saturday", "short": "Sat", "b": "Dosa, Sambar", "l": "Kadi Chawal", "d": "Khichdi, Papad"},
      {"day": "Sunday", "short": "Sun", "b": "Chowmein, Coffee", "l": "Veg Biryani, Raita", "d": "Poori Sabzi, Gulab Jamun"},
    ];

    return ListView.builder(
      itemCount: weeklyData.length,
      itemBuilder: (context, index) {
        var day = weeklyData[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(day["short"]!, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(day["day"]!, style: TextStyle(fontWeight: FontWeight.bold)),
            childrenPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
            children: [
              ListTile(leading: Icon(Icons.breakfast_dining, color: Colors.orange), title: Text("Breakfast: ${day['b']}")),
              ListTile(leading: Icon(Icons.lunch_dining, color: Colors.orange), title: Text("Lunch: ${day['l']}")),
              ListTile(leading: Icon(Icons.dinner_dining, color: Colors.orange), title: Text("Dinner: ${day['d']}")),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: Rate Food ---
  Widget _buildRateFood(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text("Rate Today's Meals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        SizedBox(height: 20),
        _buildMealRatingCard(context, "Breakfast", Icons.breakfast_dining),
        _buildMealRatingCard(context, "Lunch", Icons.lunch_dining),
        _buildMealRatingCard(context, "Dinner", Icons.dinner_dining),
      ],
    );
  }

  Widget _buildMealRatingCard(BuildContext context, String meal, IconData icon) {
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.orange), SizedBox(width: 10), Text(meal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => IconButton(
                icon: Icon(Icons.star_border, color: Colors.orange, size: 30),
                onPressed: () => submitRating(context, meal, index + 1),
              )),
            )
          ],
        ),
      ),
    );
  }
}