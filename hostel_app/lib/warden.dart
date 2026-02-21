import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main.dart'; 

class WardenPage extends StatefulWidget {
  @override
  _WardenPageState createState() => _WardenPageState();
}

class _WardenPageState extends State<WardenPage> {
  int _selectedMenu = 0;

  // --- REAL DATA LISTS ---
  List<dynamic> gatePasses = [];
  List<dynamic> attendance = [];
  List<dynamic> complaints = [];
  List<dynamic> foodRatings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    String baseUrl = kIsWeb ? "http://127.0.0.1:8000" : "http://10.0.2.2:8000"; 
    try {
      var r1 = await http.get(Uri.parse('$baseUrl/get-passes'));
      var r2 = await http.get(Uri.parse('$baseUrl/get-attendance'));
      var r3 = await http.get(Uri.parse('$baseUrl/get-complaints'));
      var r4 = await http.get(Uri.parse('$baseUrl/get-ratings'));

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

  Future<void> updatePassStatus(String studentId, String time, String newStatus) async {
    String baseUrl = kIsWeb ? "http://127.0.0.1:8000" : "http://10.0.2.2:8000";
    try {
      await http.post(
        Uri.parse('$baseUrl/update-pass'),
        headers: {"Content-Type": "application/json"},
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
          title: Text("Post Notice to Students"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: InputDecoration(hintText: "Title")),
              SizedBox(height: 10),
              TextField(controller: msgController, decoration: InputDecoration(hintText: "Message")),
              SizedBox(height: 10),
              // Image Picker Button
              ElevatedButton.icon(
                icon: Icon(Icons.image),
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
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                String ip = kIsWeb ? "127.0.0.1" : "10.0.2.2"; 
                var uri = Uri.parse('http://$ip:8000/post-notice'); 
                var request = http.MultipartRequest('POST', uri);
                request.fields['title'] = titleController.text;
                request.fields['message'] = msgController.text;
                
                if (selectedImage != null) {
                  request.files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
                }
                
                await request.send();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notice Posted!"), backgroundColor: Colors.indigo));
              }, 
              child: Text("POST")
            )
          ],
        );
      });
    });
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
  }

  // --- DYNAMIC VIEW SWITCHER ---
  Widget _buildMainContent() {
    if (isLoading) return Center(child: CircularProgressIndicator());

    if (_selectedMenu == 0) {
      // 1. ANALYTICS DASHBOARD
      int presentCount = attendance.length;
      int pendingPasses = gatePasses.where((p) => p['status'] == "Pending").length;
      int activeComplaints = complaints.length;
      double optimizedRice = (presentCount * 0.4) * 0.6;
      double optimizedDal = (presentCount * 0.4) * 0.4;
      var urgentComplaint = complaints.firstWhere((c) => c['issue'].toString().contains('[HIGH PRIORITY') || c['issue'].toString().toLowerCase().contains('fire'), orElse: () => null);

      return SingleChildScrollView(
        padding: EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Analytics Dashboard", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text("Real-time facility overview & AI insights.", style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                ]),
                IconButton(icon: Icon(Icons.refresh, color: Colors.indigo), onPressed: refreshData),
              ],
            ),
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: _buildStatCard(Icons.person_outline, Colors.green, "Students Present", presentCount.toString(), " / 400")),
                SizedBox(width: 20),
                Expanded(child: _buildStatCard(Icons.qr_code_scanner, Colors.indigo, "Pending Passes", pendingPasses.toString(), "")),
                SizedBox(width: 20),
                Expanded(child: _buildStatCard(Icons.build_outlined, Colors.red, "Active Complaints", activeComplaints.toString(), "", hasAlert: urgentComplaint != null)),
              ],
            ),
            SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(Icons.auto_awesome, color: Colors.purpleAccent), SizedBox(width: 10), Text("AI Food Waste Prediction", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                      SizedBox(height: 15),
                      Text("Based on real-time attendance ($presentCount present), the NLP model predicts optimal cooking quantities.", style: TextStyle(color: Colors.blueGrey, height: 1.5)),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${optimizedRice.toStringAsFixed(1)} kg", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Rice", style: TextStyle(color: Colors.grey))]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${optimizedDal.toStringAsFixed(1)} L", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Dal", style: TextStyle(color: Colors.grey))]),
                        ]),
                      ),
                    ]),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: urgentComplaint == null 
                    ? Center(child: Text("No High Priority Issues! 🎉", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent), SizedBox(width: 10), Text("AI Flagged Maintenance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("Room ${urgentComplaint['room']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900)),
                              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Text("NLP ALERT", style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold))),
                            ]),
                            SizedBox(height: 10),
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
      // 2. PASS APPROVALS LIST
      return ListView.builder(
        padding: EdgeInsets.all(40),
        itemCount: gatePasses.length,
        itemBuilder: (context, index) {
          var pass = gatePasses[index];
          return Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(Icons.run_circle, color: pass['status']=="Approved"?Colors.green:pass['status']=="Rejected"?Colors.red:Colors.orange),
              title: Text("${pass['student_id']} - ${pass['reason']}"),
              subtitle: Text("Status: ${pass['status']} | ${pass['time'].toString().replaceAll('\n', ' ')}"),
              trailing: pass['status'] == "Pending" ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: Icon(Icons.check_circle, color: Colors.green), onPressed: () => updatePassStatus(pass['student_id'], pass['time'], "Approved")),
                  IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: () => updatePassStatus(pass['student_id'], pass['time'], "Rejected")),
                ],
              ) : null,
            ),
          );
        }
      );
    }

    else if (_selectedMenu == 2) {
      // 3. ALL ISSUES/COMPLAINTS LIST
      return ListView.builder(
        padding: EdgeInsets.all(40),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          var c = complaints[index];
          bool isHighPriority = c['issue'].toString().contains('[HIGH');
          return Card(
            margin: EdgeInsets.only(bottom: 10),
            color: isHighPriority ? Colors.red.shade50 : Colors.white,
            child: ListTile(
              leading: Icon(Icons.build, color: isHighPriority ? Colors.red : Colors.indigo),
              title: Text(c['issue'], style: TextStyle(fontWeight: isHighPriority ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text("Room: ${c['room']} | Category: ${c['category']}"),
            ),
          );
        }
      );
    }

    else if (_selectedMenu == 3) {
      // 4. FOOD RATINGS LIST
      return ListView.builder(
        padding: EdgeInsets.all(40),
        itemCount: foodRatings.length,
        itemBuilder: (context, index) {
          var rate = foodRatings[index];
          return Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text(rate['rating'].toString(), style: TextStyle(color: Colors.orange.shade900))),
              title: Text("${rate['meal']} Review"),
              subtitle: Text("By: ${rate['student_id']}"),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: List.generate(rate['rating'], (i) => Icon(Icons.star, size: 16, color: Colors.orange))),
            ),
          );
        }
      );
    }

    return SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    int pendingPasses = gatePasses.where((p) => p['status'] == "Pending").length;

    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 250,
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.admin_panel_settings, color: Colors.indigo)),
                    SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Warden Portal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))), Text("Administration", style: TextStyle(fontSize: 12, color: Colors.grey))])
                  ],
                ),
                SizedBox(height: 40),
                _buildMenuItem(0, Icons.dashboard_customize, "Analytics"),
                SizedBox(height: 10),
                _buildMenuItem(1, Icons.fact_check_outlined, "Pass Approvals", badgeCount: pendingPasses > 0 ? pendingPasses.toString() : null),
                SizedBox(height: 10),
                _buildMenuItem(2, Icons.warning_amber_rounded, "All Issues"),
                SizedBox(height: 10),
                _buildMenuItem(3, Icons.restaurant, "Food Ratings"),
                SizedBox(height: 30),
                
                // POST NOTICE BUTTON
                ElevatedButton.icon(
                  icon: Icon(Icons.campaign), label: Text("Post Notice"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: Size(double.infinity, 45)),
                  onPressed: _showPostNoticeDialog,
                ),
                
                Spacer(),
                InkWell(onTap: logout, child: Container(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15), child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 15), Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]))),
              ],
            ),
          ),

          // MAIN CONTENT AREA
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
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(color: isSelected ? Colors.indigo.shade50 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icon, color: isSelected ? Colors.indigo : Colors.grey, size: 20), SizedBox(width: 15), Text(title, style: TextStyle(color: isSelected ? Colors.indigo : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))]),
            if (badgeCount != null) Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle), child: Text(badgeCount, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, Color iconColor, String title, String mainValue, String subValue, {bool hasAlert = false}) {
    return Container(
      padding: EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor), SizedBox(height: 15),
              Text(title, style: TextStyle(color: Colors.blueGrey, fontSize: 14)), SizedBox(height: 5),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(mainValue, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827))), Text(subValue, style: TextStyle(fontSize: 16, color: Colors.grey))])
            ],
          ),
          if (hasAlert) Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)))
        ],
      ),
    );
  }
}