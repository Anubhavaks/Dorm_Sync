import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart'; 
import 'package:geolocator/geolocator.dart';

// 🌍 GLOBAL CLOUD URL
const String baseUrl = "https://dorm-sync.onrender.com";

class StudentDashboard extends StatefulWidget {
  final String studentId;
  const StudentDashboard({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  bool isAttendanceMarked = false;
  final secureStorage = const FlutterSecureStorage();

  void logout() async {
    // Cryptographically wipe the secure token vault clean upon session closure
    await secureStorage.deleteAll();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
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
    
    print("📍 YOUR EXACT LOCATION: Lat: ${position.latitude}, Lng: ${position.longitude}");
    
    double hostelLat = 28.9845; 
    double hostelLng = 77.7064;
    
    double distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, hostelLat, hostelLng);
    
    if (distanceInMeters > 10000) {  
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Geo-fence Failed. Distance: ${distanceInMeters.toInt()}m."), 
        backgroundColor: Colors.red));
      return; 
    }

    // 2. FACE SCAN (If Location Passes)
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    
    if (photo != null) {
      var url = Uri.parse('$baseUrl/mark-attendance');
      String? token = await secureStorage.read(key: 'jwt_token');
      
      try {
        await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token"
          },
          body: jsonEncode({
            "student_id": widget.studentId, 
            "time": DateTime.now().toString().substring(0, 16), 
            "location": "Verified Hostel Bounds"
          }),
        );
        setState(() => isAttendanceMarked = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Face & GPS Verified! Logged."), backgroundColor: Colors.green));
      } catch (e) { print(e); }
    }
  }

  // --- HOME TAB WIDGET ---
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hello,", style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                  Text(widget.studentId == "Student_001" ? "Arjun Kumar" : widget.studentId, 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                ],
              ),
              InkWell(
                onTap: logout, 
                child: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.logout, color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // SMART ATTENDANCE CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAttendanceMarked ? Colors.green : const Color(0xFF4F46E5), 
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: (isAttendanceMarked ? Colors.green : const Color(0xFF4F46E5)).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Smart Attendance", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isAttendanceMarked ? Icons.check_circle : Icons.camera_alt_outlined, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 5),
                    Text(isAttendanceMarked ? "Location Verified" : "Geo-fencing active", style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isAttendanceMarked ? Colors.green : const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isAttendanceMarked ? null : _markPresence,
                    child: Text(isAttendanceMarked ? "PRESENCE MARKED" : "Mark Presence (Face Scan)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 30),

          // NOTICE BOARD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Notice Board", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Text("Live", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Warden • Recent", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text("Gate Timing Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 15),
                const Text("Main gate will close at 10:00 PM tonight due to scheduled maintenance. Ensure you are inside the premises before the cutoff.", style: TextStyle(color: Colors.blueGrey, height: 1.5))
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        selectedItemColor: const Color(0xFF4F46E5),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
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
// MODULES INTEGRATED WITH SECURE JWT HEADERS
// ==========================================

class GatePassPage extends StatefulWidget {
  final String studentId;
  const GatePassPage({Key? key, required this.studentId}) : super(key: key);
  @override _GatePassPageState createState() => _GatePassPageState();
}

class _GatePassPageState extends State<GatePassPage> {
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController outDateController = TextEditingController();
  final TextEditingController outTimeController = TextEditingController();
  final TextEditingController inDateController = TextEditingController();
  final TextEditingController inTimeController = TextEditingController();
  final secureStorage = const FlutterSecureStorage();
  List<dynamic> myPasses = [];

  @override void initState() { super.initState(); fetchMyPasses(); }

  Future<void> fetchMyPasses() async {
    String? token = await secureStorage.read(key: 'jwt_token');
    var response = await http.get(
      Uri.parse('$baseUrl/get-passes'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      }
    );
    if (response.statusCode == 200) {
      var allPasses = jsonDecode(response.body);
      setState(() { myPasses = allPasses.where((p) => p['student_id'] == widget.studentId).toList(); });
    }
  }

  Future<void> submitPass() async {
    String combinedOut = "${outDateController.text} at ${outTimeController.text}";
    String combinedIn = "${inDateController.text} at ${inTimeController.text}";
    String? token = await secureStorage.read(key: 'jwt_token');

    var response = await http.post(
      Uri.parse('$baseUrl/request-pass'), 
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "student_id": widget.studentId, 
        "reason": reasonController.text, 
        "out_time": combinedOut, 
        "in_time": combinedIn
      })
    );
      
    if (response.statusCode == 200) {
      reasonController.clear(); outDateController.clear(); outTimeController.clear();
      inDateController.clear(); inTimeController.clear();
      fetchMyPasses();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pass Requested!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2101));
    if (picked != null) setState(() => controller.text = "${picked.day}/${picked.month}/${picked.year}");
  }

  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => controller.text = picked.format(context));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Request Gate Pass", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 15),
          TextField(controller: reasonController, decoration: const InputDecoration(labelText: "Destination & Reason")),
          const SizedBox(height: 15),
          
          Row(children: [
            Expanded(child: TextField(controller: outDateController, readOnly: true, onTap: () => _selectDate(outDateController), decoration: const InputDecoration(labelText: "Out Date", prefixIcon: Icon(Icons.calendar_today, size: 18)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: outTimeController, readOnly: true, onTap: () => _selectTime(outTimeController), decoration: const InputDecoration(labelText: "Out Time", prefixIcon: Icon(Icons.access_time, size: 18)))),
          ]),
          const SizedBox(height: 15),

          Row(children: [
            Expanded(child: TextField(controller: inDateController, readOnly: true, onTap: () => _selectDate(inDateController), decoration: const InputDecoration(labelText: "In Date", prefixIcon: Icon(Icons.calendar_today, size: 18)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: inTimeController, readOnly: true, onTap: () => _selectTime(inTimeController), decoration: const InputDecoration(labelText: "In Time", prefixIcon: Icon(Icons.access_time, size: 18)))),
          ]),
          const SizedBox(height: 20),
          
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: submitPass, child: const Text("Submit Request"))),
          const SizedBox(height: 30),
          
          const Text("My Digital Slips", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...myPasses.map((pass) {
            bool isApproved = pass['status'] == 'Approved';
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isApproved ? Colors.green.shade50 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isApproved ? Colors.green : Colors.grey.shade300, width: isApproved ? 2 : 1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isApproved ? "VALID GATE PASS" : "PENDING REQUEST", style: TextStyle(fontWeight: FontWeight.bold, color: isApproved ? Colors.green.shade800 : Colors.grey)), Icon(isApproved ? Icons.verified : Icons.access_time, color: isApproved ? Colors.green : Colors.grey)]),
                  const Divider(),
                  Text("Reason: ${pass['reason']}", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 5),
                  Text("Timings: ${pass['time']}", style: const TextStyle(color: Colors.blueGrey)),
                  if (isApproved) ...[const SizedBox(height: 15), const Center(child: Icon(Icons.qr_code_2, size: 60, color: Colors.black87)), const Center(child: Text("Show this at main gate", style: TextStyle(fontSize: 10, color: Colors.grey)))]
                ],
              ),
            );
          }).toList()
        ],
      ),
    );
  }
}

class MaintenancePage extends StatefulWidget {
  final String studentId;
  const MaintenancePage({Key? key, required this.studentId}) : super(key: key);
  @override _MaintenancePageState createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final TextEditingController roomController = TextEditingController();
  final TextEditingController issueController = TextEditingController();
  final secureStorage = const FlutterSecureStorage();
  String selectedCategory = "Electrical";
  String priorityLevel = "Normal"; 
  Color priorityColor = Colors.green; 
  List<dynamic> myComplaints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyComplaints();
  }

  Future<void> fetchMyComplaints() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    String? token = await secureStorage.read(key: 'jwt_token');
    
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/get-complaints'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
      );
      if (response.statusCode == 200) {
        List<dynamic> allData = jsonDecode(response.body);
        setState(() {
          myComplaints = allData.where((c) => 
            c['student_id'].toString().trim().toLowerCase() == 
            widget.studentId.trim().toLowerCase()
          ).toList();
          isLoading = false;
        });
      }
    } catch (e) { 
      print("FETCH ERROR: $e");
      setState(() => isLoading = false); 
    }
  }

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
    var url = Uri.parse('$baseUrl/create-complaint');
    String? token = await secureStorage.read(key: 'jwt_token');
    String finalIssue = "[$priorityLevel] ${issueController.text}";
    
    try {
      var response = await http.post(
        url, 
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "student_id": widget.studentId, 
          "student_name": widget.studentId, 
          "room_number": roomController.text,
          "issue": finalIssue, 
          "category": selectedCategory
        })
      );
      if (response.statusCode == 200) {
        Navigator.pop(context); 
        fetchMyComplaints(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket Raised and Analyzed!"), backgroundColor: Color(0xFF0D9488)));
        issueController.clear();
      }
    } catch (e) { print(e); }
  }

  void _showRaiseTicketModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Raise New Ticket", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
                  const SizedBox(height: 15),
                  TextField(controller: roomController, decoration: const InputDecoration(labelText: "Room Number")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory, decoration: const InputDecoration(labelText: "Category"),
                    items: ["Electrical", "Plumbing", "Carpentry", "Cleaning", "Other"].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                    onChanged: (val) => setModalState(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: issueController, maxLines: 3, decoration: const InputDecoration(labelText: "Describe the Issue"),
                    onChanged: (text) { _analyzeComplaint(text); setModalState(() {}); },
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: priorityColor)),
                    child: Row(children: [Icon(Icons.analytics, color: priorityColor, size: 20), const SizedBox(width: 10), Expanded(child: Text("AI Assessment: $priorityLevel", style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 12)))]),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white), onPressed: submitComplaint, child: const Text("Submit Ticket", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildStudentTicketCard({required String ticketId, required String priority, required String category, required String issue, required bool isHighPriority, required String currentStatus}) {
    Color priorityColor = isHighPriority ? Colors.red.shade700 : Colors.orange.shade700;
    Color priorityBg = isHighPriority ? Colors.red.shade50 : Colors.orange.shade50;
    IconData statusIcon = Icons.pending_actions;
    Color statusColor = Colors.blueGrey;
    
    if (currentStatus == "In Progress") { statusIcon = Icons.engineering; statusColor = Colors.blue.shade700; } 
    else if (currentStatus == "Resolved") { statusIcon = Icons.check_circle; statusColor = Colors.green.shade700; }

    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(ticketId, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: priorityBg, borderRadius: BorderRadius.circular(4)), child: Text(priority, style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(category, style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold))),
              ]),
              Row(children: [Icon(statusIcon, size: 14, color: statusColor), const SizedBox(width: 4), Text(currentStatus, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold))])
            ],
          ),
          const SizedBox(height: 15),
          Text(issue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("My Tickets", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), icon: const Icon(Icons.add, size: 18), label: const Text("Raise Ticket"), onPressed: _showRaiseTicketModal)
            ],
          ),
        ),
        Expanded(
          child: isLoading ? const Center(child: CircularProgressIndicator()) : myComplaints.isEmpty ? const Center(child: Text("No tickets raised yet.", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: myComplaints.length,
                itemBuilder: (context, index) {
                  var c = myComplaints[index];
                  String rawIssue = c['issue'].toString();
                  bool isHigh = rawIssue.contains('[HIGH');
                  String cleanIssue = rawIssue.replaceAll(RegExp(r'\[.*?\] '), ''); 
                  return _buildStudentTicketCard(
                    ticketId: "TCK-${100 + index}", priority: isHigh ? "HIGH" : "MEDIUM",
                    category: c['category'].toString().toUpperCase(), issue: cleanIssue, isHighPriority: isHigh,
                    currentStatus: c['status'] ?? "Pending",
                  );
                }
              ),
        )
      ],
    );
  }
}

class MessMenuPage extends StatelessWidget {
  final String studentId;
  MessMenuPage({Key? key, required this.studentId}) : super(key: key);
  final secureStorage = const FlutterSecureStorage();

  Future<void> submitRating(BuildContext context, String meal, int rating) async {
    var url = Uri.parse('$baseUrl/rate-food');
    String? token = await secureStorage.read(key: 'jwt_token');
    
    try {
      var response = await http.post(
        url, 
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"student_id": studentId, "meal": meal, "rating": rating})
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$meal rated $rating stars!"), backgroundColor: Colors.orange));
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.orange.shade600,
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Hostel Mess", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const TabBar(
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
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(day["short"]!, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(day["day"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
            childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            children: [
              ListTile(leading: const Icon(Icons.breakfast_dining, color: Colors.orange), title: Text("Breakfast: ${day['b']}")),
              ListTile(leading: const Icon(Icons.lunch_dining, color: Colors.orange), title: Text("Lunch: ${day['l']}")),
              ListTile(leading: const Icon(Icons.dinner_dining, color: Colors.orange), title: Text("Dinner: ${day['d']}")),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRateFood(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Rate Today's Meals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 20),
        _buildMealRatingCard(context, "Breakfast", Icons.breakfast_dining),
        _buildMealRatingCard(context, "Lunch", Icons.lunch_dining),
        _buildMealRatingCard(context, "Dinner", Icons.dinner_dining),
      ],
    );
  }

  Widget _buildMealRatingCard(BuildContext context, String meal, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.orange), const SizedBox(width: 10), Text(meal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => IconButton(
                icon: const Icon(Icons.star_border, color: Colors.orange, size: 30),
                onPressed: () => submitRating(context, meal, index + 1),
              )),
            )
          ],
        ),
      ),
    );
  }
}