import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart'; 

// 🌍 GLOBAL CLOUD URL
const String baseUrl = "https://dorm-sync.onrender.com";

class WardenPage extends StatefulWidget {
  const WardenPage({Key? key}) : super(key: key);

  @override
  _WardenPageState createState() => _WardenPageState();
}

class _WardenPageState extends State<WardenPage> {
  int _selectedMenu = 0;
  final secureStorage = const FlutterSecureStorage();

  // --- REAL DATA LISTS ---
  List<dynamic> gatePasses = [];
  List<dynamic> attendance = [];
  List<dynamic> complaints = [];
  List<dynamic> foodRatings = [];

  // --- MOCK STUDENT DIRECTORY DATA ---
  final List<Map<String, dynamic>> studentDirectory = [
    {"id": "S101", "name": "Aarav Patel", "room": "101A", "course": "B.Tech CS, 2nd Year", "status": "Present", "feePaid": true, "phone": "+91 98765 43210", "attendance": 0.92},
    {"id": "S102", "name": "Rahul Sharma", "room": "101B", "course": "B.Tech ME, 3rd Year", "status": "On Leave", "feePaid": false, "phone": "+91 98765 43211", "attendance": 0.85},
    {"id": "S103", "name": "Kabir Das", "room": "102A", "course": "BBA, 1st Year", "status": "Present", "feePaid": true, "phone": "+91 98765 43212", "attendance": 0.98},
    {"id": "S104", "name": "Neha Gupta", "room": "102B", "course": "B.Arch, 4th Year", "status": "Present", "feePaid": true, "phone": "+91 98765 43213", "attendance": 0.88},
    {"id": "S105", "name": "Rohan Verma", "room": "103A", "course": "M.Tech, 1st Year", "status": "Present", "feePaid": true, "phone": "+91 98765 43214", "attendance": 0.95},
    {"id": "S106", "name": "Aditya Singh", "room": "103B", "course": "B.Tech CS, 2nd Year", "status": "Present", "feePaid": false, "phone": "+91 98765 43215", "attendance": 0.75},
  ];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    String? token = await secureStorage.read(key: 'jwt_token');

    try {
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      };

      var r1 = await http.get(Uri.parse('$baseUrl/get-passes'), headers: headers);
      var r2 = await http.get(Uri.parse('$baseUrl/get-attendance'), headers: headers);
      var r3 = await http.get(Uri.parse('$baseUrl/get-complaints'), headers: headers);
      var r4 = await http.get(Uri.parse('$baseUrl/get-ratings'), headers: headers);

      setState(() {
        gatePasses = jsonDecode(r1.body);
        attendance = jsonDecode(r2.body);
        complaints = jsonDecode(r3.body);
        foodRatings = jsonDecode(r4.body);
        isLoading = false;
      });
    } catch (e) { 
      print("Error: $e"); 
      setState(() => isLoading = false);
    }
  }

  Future<void> updateComplaintStatus(String studentId, String issue, String newStatus) async {
    String? token = await secureStorage.read(key: 'jwt_token');
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/update-complaint'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "student_id": studentId, 
          "issue": issue, 
          "status": newStatus
        }),
      );
      
      if (response.statusCode == 200) {
        refreshData(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status Updated to $newStatus"), backgroundColor: const Color(0xFF0D9488))
        );
      }
    } catch (e) { print("WARDEN UPDATE ERROR: $e"); }
  }

  Future<void> updatePassStatus(String studentId, String time, String newStatus) async {
    String? token = await secureStorage.read(key: 'jwt_token');
    try {
      await http.post(
        Uri.parse('$baseUrl/update-pass'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"student_id": studentId, "time": time, "status": newStatus}),
      );
      refreshData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pass $newStatus"), backgroundColor: newStatus == "Approved" ? Colors.green : Colors.red));
    } catch (e) { print(e); }
  }

  void _showPostNoticeDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController msgController = TextEditingController();
    XFile? selectedImage;

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Post Notice to Students"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(hintText: "Title")),
              const SizedBox(height: 10),
              TextField(controller: msgController, decoration: const InputDecoration(hintText: "Message")),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(selectedImage == null ? "Attach Image" : "Image Selected!"),
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setDialogState(() => selectedImage = image);
                  }
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                String? token = await secureStorage.read(key: 'jwt_token');
                var uri = Uri.parse('$baseUrl/post-notice'); 
                var request = http.MultipartRequest('POST', uri);
                
                // Inject secure token into multipart header request lifecycle
                request.headers['Authorization'] = 'Bearer $token';
                request.fields['title'] = titleController.text;
                request.fields['message'] = msgController.text;
                
                if (selectedImage != null) {
                  request.files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
                }
                
                await request.send();
                Navigator.pop(context);
                refreshData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notice Posted!"), backgroundColor: Colors.indigo));
              }, 
              child: const Text("POST")
            )
          ],
        );
      });
    });
  }

  void logout() async {
    await secureStorage.deleteAll();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
  }

  Widget _buildStatCard(IconData icon, Color color, String title, String value, String suffix, {bool hasAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
              if (hasAlert) const Icon(Icons.warning, color: Colors.red)
            ],
          ),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 5),
          RichText(text: TextSpan(children: [
            TextSpan(text: value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            TextSpan(text: suffix, style: const TextStyle(color: Colors.grey, fontSize: 14))
          ]))
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (_selectedMenu == 0) {
      int presentCount = attendance.length;
      int pendingPasses = gatePasses.where((p) => p['status'] == "Pending").length;
      int activeComplaints = complaints.length;
      double optimizedRice = (presentCount * 0.4) * 0.6;
      double optimizedDal = (presentCount * 0.4) * 0.4;
      var urgentComplaint = complaints.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c != null && (c['issue'].toString().contains('[HIGH') || c['issue'].toString().toLowerCase().contains('fire')), 
        orElse: () => null
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text("Analytics Dashboard", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text("Real-time facility overview & AI insights.", style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                ]),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.indigo), onPressed: refreshData),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: _buildStatCard(Icons.person_outline, Colors.green, "Students Present", presentCount.toString(), " / 400")),
                const SizedBox(width: 20),
                Expanded(child: _buildStatCard(Icons.qr_code_scanner, Colors.indigo, "Pending Passes", pendingPasses.toString(), "")),
                const SizedBox(width: 20),
                Expanded(child: _buildStatCard(Icons.build_outlined, Colors.red, "Active Complaints", activeComplaints.toString(), "", hasAlert: urgentComplaint != null)),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: const [Icon(Icons.auto_awesome, color: Colors.purpleAccent), SizedBox(width: 10), Text("AI Food Waste Prediction", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 15),
                      Text("Based on real-time attendance ($presentCount present), the NLP model predicts optimal cooking quantities.", style: const TextStyle(color: Colors.blueGrey, height: 1.5)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${optimizedRice.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Text("Rice", style: TextStyle(color: Colors.grey))]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${optimizedDal.toStringAsFixed(1)} L", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Text("Dal", style: TextStyle(color: Colors.grey))]),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: urgentComplaint == null 
                    ? const Center(child: Text("No High Priority Issues! 🎉", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.warning_amber_rounded, color: Colors.redAccent), SizedBox(width: 10), Text("AI Flagged Maintenance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("Room ${urgentComplaint['room']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900)),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Text("NLP ALERT", style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold))),
                            ]),
                            const SizedBox(height: 10),
                            Text(urgentComplaint['issue'], style: TextStyle(color: Colors.red.shade900, fontSize: 14, height: 1.5, fontWeight: FontWeight.bold)),
                          ]),
                        )
                      ]),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    } 
    
    else if (_selectedMenu == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(40),
        itemCount: gatePasses.length,
        itemBuilder: (context, index) {
          var pass = gatePasses[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(Icons.run_circle, color: pass['status']=="Approved"?Colors.green:pass['status']=="Rejected"?Colors.red:Colors.orange),
              title: Text("${pass['student_id']} - ${pass['reason']}"),
              subtitle: Text("Status: ${pass['status']} | ${pass['time'].toString().replaceAll('\n', ' ')}"),
              trailing: pass['status'] == "Pending" ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => updatePassStatus(pass['student_id'], pass['time'], "Approved")),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => updatePassStatus(pass['student_id'], pass['time'], "Rejected")),
                ],
              ) : null,
            ),
          );
        }
      );
    }

    else if (_selectedMenu == 2) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Maintenance & Complaints", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      SizedBox(height: 5),
                      Text("Ticketing system to track and resolve student issues.", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const TabBar(
                isScrollable: true,
                labelColor: Color(0xFF0D9488),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF0D9488),
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [Tab(text: "Open & In Progress"), Tab(text: "Resolved")],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.builder(
                      itemCount: complaints.length,
                      itemBuilder: (context, index) {
                        var c = complaints[index];
                        String rawIssue = c['issue'].toString();
                        bool isHigh = rawIssue.contains('[HIGH');
                        String cleanIssue = rawIssue.replaceAll(RegExp(r'\[.*?\] '), ''); 
                        
                        return _buildTicketCard(
                          ticketId: "TCK-${100 + index}", 
                          priority: isHigh ? "HIGH" : "MEDIUM",
                          category: c['category'].toString().toUpperCase(),
                          issue: cleanIssue,   
                          rawIssue: rawIssue, 
                          studentName: c['student_name'] ?? "Student",
                          room: c['room'],
                          isHighPriority: isHigh,
                          studentId: c['student_id'],              
                          currentStatus: c['status'] ?? "Pending", 
                        );
                      }
                    ),
                    const Center(child: Text("No resolved tickets yet.", style: TextStyle(color: Colors.grey))),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }

    else if (_selectedMenu == 3) {
      return ListView.builder(
        padding: const EdgeInsets.all(40),
        itemCount: foodRatings.length,
        itemBuilder: (context, index) {
          var rate = foodRatings[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text(rate['rating'].toString(), style: TextStyle(color: Colors.orange.shade900))),
              title: Text("${rate['meal']} Review"),
              subtitle: Text("By: ${rate['student_id']}"),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: List.generate(rate['rating'], (i) => const Icon(Icons.star, size: 16, color: Colors.orange))),
            ),
          );
        }
      );
    }

    else if (_selectedMenu == 4) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Student Directory", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    SizedBox(height: 5),
                    Text("Interactive directory with instant search and filtering.", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 250, height: 40,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: const TextField(decoration: InputDecoration(hintText: "Search name or room...", prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10))),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                      icon: const Icon(Icons.add, size: 18), label: const Text("Add Student", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () {},
                    )
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                const Chip(label: Text("All Students", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF1F2937), side: BorderSide.none),
                const SizedBox(width: 10),
                Chip(label: const Text("B.Tech Only", style: TextStyle(color: Colors.blueGrey)), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300)),
                const SizedBox(width: 10),
                Chip(label: const Text("Fee Pending", style: TextStyle(color: Colors.blueGrey)), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300)),
                const SizedBox(width: 10),
                Chip(label: const Text("On Leave", style: TextStyle(color: Colors.blueGrey)), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 350, 
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.1, 
                ),
                itemCount: studentDirectory.length,
                itemBuilder: (context, index) {
                  return _buildDirectoryCard(studentDirectory[index]);
                },
              ),
            )
          ],
        ),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    int pendingPasses = gatePasses.where((p) => p['status'] == "Pending").length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Row(
        children: [
          Container(
            width: 250,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.admin_panel_settings, color: Colors.indigo)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("Warden Portal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))), Text("Administration", style: TextStyle(fontSize: 12, color: Colors.grey))])
                  ],
                ),
                const SizedBox(height: 40),
                _buildMenuItem(0, Icons.dashboard_customize, "Analytics"),
                const SizedBox(height: 10),
                _buildMenuItem(1, Icons.fact_check_outlined, "Pass Approvals", badgeCount: pendingPasses > 0 ? pendingPasses.toString() : null),
                const SizedBox(height: 10),
                _buildMenuItem(2, Icons.warning_amber_rounded, "All Issues"),
                const SizedBox(height: 10),
                _buildMenuItem(3, Icons.restaurant, "Food Ratings"),
                const SizedBox(height: 10),
                _buildMenuItem(4, Icons.people_alt, "Student Directory"),
                const SizedBox(height: 30),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.campaign), label: const Text("Post Notice"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                  onPressed: _showPostNoticeDialog,
                ),
                
                const Spacer(),
                InkWell(onTap: logout, child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15), child: Row(children: const [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 15), Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]))),
              ],
            ),
          ),

          Expanded(child: _buildMainContent())
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title, {String? badgeCount}) {
    bool isSelected = _selectedMenu == index;
    return InkWell(
      onTap: () => setState(() => _selectedMenu = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(color: isSelected ? Colors.indigo.shade50 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icon, color: isSelected ? Colors.indigo : Colors.grey, size: 20), const SizedBox(width: 15), Text(title, style: TextStyle(color: isSelected ? Colors.indigo : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))]),
            if (badgeCount != null) Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle), child: Text(badgeCount, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard({
    required String ticketId, 
    required String priority, 
    required String category, 
    required String issue, 
    required String rawIssue, 
    required String studentName, 
    required String studentId, 
    required String room, 
    required bool isHighPriority, 
    required String currentStatus
  }) {
    Color priorityColor = isHighPriority ? Colors.red.shade700 : Colors.orange.shade700;
    Color priorityBg = isHighPriority ? Colors.red.shade50 : Colors.orange.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(isHighPriority ? Icons.hourglass_bottom : Icons.warning_amber_rounded, color: Colors.blueGrey, size: 20)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(ticketId, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: priorityBg, borderRadius: BorderRadius.circular(4)), child: Text(priority, style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(category, style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),
                Text(issue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))), const SizedBox(height: 5),
                RichText(text: TextSpan(style: const TextStyle(color: Colors.grey, fontSize: 12), children: [const TextSpan(text: "Reported by "), TextSpan(text: studentName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), TextSpan(text: " (Room $room)")]))
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 35, padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ["Pending", "In Progress", "Resolved"].contains(currentStatus) ? currentStatus : "Pending",
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16), style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                    items: ["Pending", "In Progress", "Resolved"].map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(),
                    onChanged: (newValue) { 
                      if (newValue != null && newValue != currentStatus) { 
                        updateComplaintStatus(studentId, rawIssue, newValue); 
                      } 
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.blueGrey, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0), minimumSize: const Size(0, 35)), onPressed: () {}, child: const Text("Assign Staff", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDirectoryCard(Map<String, dynamic> student) {
    bool isPresent = student['status'] == "Present";
    bool isPaid = student['feePaid'];

    Widget cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.person, color: Colors.indigo, size: 30)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    Text(student['id'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 5),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text("ROOM ${student['room']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                  ],
                ),
              )
            ],
          ),
          const Spacer(),
          Row(children: [const Icon(Icons.school, size: 14, color: Colors.blueGrey), const SizedBox(width: 5), Text(student['course'], style: const TextStyle(fontSize: 12, color: Colors.blueGrey))]),
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.location_on, size: 14, color: isPresent ? Colors.green : Colors.orange), const SizedBox(width: 5), const Text("Status: ", style: TextStyle(fontSize: 12, color: Colors.grey)), Text(student['status'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPresent ? Colors.green : Colors.orange))]),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.blueGrey, side: BorderSide(color: Colors.grey.shade300)), onPressed: () => _showStudentProfileModal(student), child: const Text("View Profile", style: TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(width: 10),
              Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: IconButton(icon: const Icon(Icons.mail_outline, size: 20, color: Colors.blueGrey), onPressed: (){})),
            ],
          )
        ],
      ),
    );

    if (!isPaid) {
      return ClipRect(
        child: Banner(
          message: "UNPAID", location: BannerLocation.topEnd, color: Colors.red.shade600,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  void _showStudentProfileModal(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500, padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Student Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(radius: 40, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.person, color: Colors.indigo, size: 50)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(student['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), child: Text(student['id'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))]),
                          const SizedBox(height: 5),
                          Text(student['course'], style: const TextStyle(color: Colors.blueGrey)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)), child: Row(children: [const Icon(Icons.bed, size: 14, color: Colors.teal), const SizedBox(width: 5), Text("Room ${student['room']}", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12))])),
                              const SizedBox(width: 10),
                              Text(student['status'], style: TextStyle(color: student['status'] == 'Present' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CONTACT INFORMATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 15),
                            Row(children: [const Icon(Icons.phone_iphone, size: 16, color: Colors.blueGrey), const SizedBox(width: 10), Text(student['phone'], style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const SizedBox(height: 10),
                            Row(children: [const Icon(Icons.email_outlined, size: 16, color: Colors.blueGrey), const SizedBox(width: 10), Text("${student['id'].toString().toLowerCase()}@university.edu", style: const TextStyle(color: Colors.blueGrey))]),
                            const SizedBox(height: 25),
                            const Text("GUARDIAN DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 15),
                            Row(children: [const Icon(Icons.face, size: 16, color: Colors.orange), const SizedBox(width: 10), Text("Rajesh ${student['name'].split(' ').last}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: student['feePaid'] ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: student['feePaid'] ? Colors.green.shade200 : Colors.red.shade200)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("FEE STATUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: student['feePaid'] ? Colors.green.shade700 : Colors.red.shade700, letterSpacing: 1)), const SizedBox(height: 5), Text(student['feePaid'] ? "Paid" : "Pending", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: student['feePaid'] ? Colors.green.shade700 : Colors.red.shade700))]),
                              Icon(Icons.account_balance_wallet, color: student['feePaid'] ? Colors.green : Colors.red, size: 30)
                            ]),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(15)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("HOSTEL ATTENDANCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text("${(student['attendance'] * 100).toInt()}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                SizedBox(width: 100, child: LinearProgressIndicator(value: student['attendance'], backgroundColor: Colors.grey.shade200, color: const Color(0xFF0D9488), minHeight: 8, borderRadius: BorderRadius.circular(4)))
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: (){}, child: const Text("Edit Profile Details", style: TextStyle(fontWeight: FontWeight.bold))))
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }
}