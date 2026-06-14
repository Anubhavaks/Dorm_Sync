from fastapi import FastAPI, File, UploadFile, Form
from pydantic import BaseModel
import sqlite3
import os
import shutil
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
@app.get("/")
def home():
    return {"message": "Dorm_Sync API is Live and Running! 🚀 Go to /docs to view the dashboard."}

# Enable CORS for Mobile/Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create "uploads" folder
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- DATABASE SETUP ---
def init_db():
    conn = sqlite3.connect("hostel.db")
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users (username TEXT, password TEXT, role TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS passes (student_id TEXT, reason TEXT, time TEXT, status TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS notices (title TEXT, message TEXT, image_path TEXT, date TEXT)''')
    # Updated: Added student_name column
    # Look for your complaints table in init_db() and replace it with this:
    c.execute('''CREATE TABLE IF NOT EXISTS complaints (student_id TEXT, student_name TEXT, issue TEXT, category TEXT, room TEXT, status TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS attendance (student_id TEXT, status TEXT, time TEXT, location TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS ratings (student_id TEXT, meal TEXT, rating INTEGER)''')
    c.execute("SELECT COUNT(*) FROM users")
    if c.fetchone()[0] == 0:
        c.execute("INSERT INTO users VALUES ('warden', 'admin123', 'warden')")
        c.execute("INSERT INTO users VALUES ('Student_001', 'pass123', 'student')")
        c.execute("INSERT INTO users VALUES ('Student_002', 'pass123', 'student')")
    conn.commit()
    conn.close()

init_db()

# --- DATA MODELS (Updated to match Frontend) ---
class LoginRequest(BaseModel):
    username: str
    password: str

class PassRequest(BaseModel):
    student_id: str
    reason: str
    out_time: str
    in_time: str

class PassUpdate(BaseModel):
    student_id: str
    time: str
    status: str

# UPDATED: Matches your MaintenancePage JSON exactly
class ComplaintRequest(BaseModel):
    student_id: str
    student_name: str  # <--- Added this to fix 422 Error
    issue: str
    category: str
    room_number: str
    # floor: str = None  # Optional: If you send floor, uncomment this

# UPDATED: Matches your AttendancePage JSON exactly
class AttendanceRequest(BaseModel):
    student_id: str
    time: str
    location: str

class RatingRequest(BaseModel):
    student_id: str
    meal: str
    rating: int

# --- API ROUTES ---

@app.get("/")
def home():
    return {"message": "Hostel Mate AI Server Running"}

@app.post("/login")
def login(data: LoginRequest):
    conn = sqlite3.connect("hostel.db")
    # Check the database for the user
    user = conn.execute("SELECT role FROM users WHERE username = ? AND password = ?", (data.username, data.password)).fetchone()
    
    if user:
        return {"status": "success", "role": user[0], "username": data.username}
    else:
        return {"status": "fail", "message": "Invalid Credentials"}

@app.post("/request-pass")
def request_pass(data: PassRequest):
    conn = sqlite3.connect("hostel.db")
    combined_time = f"Out: {data.out_time}\nIn: {data.in_time}"
    conn.execute("INSERT INTO passes VALUES (?, ?, ?, ?)", (data.student_id, data.reason, combined_time, "Pending"))
    conn.commit()
    return {"message": "Pass Requested"}

@app.get("/get-passes")
def get_passes():
    conn = sqlite3.connect("hostel.db")
    # Return structure matches Warden Dashboard expectations
    rows = conn.execute("SELECT * FROM passes").fetchall()
    return [{"student_id": r[0], "reason": r[1], "time": r[2], "status": r[3]} for r in rows]

@app.post("/update-pass")
def update_pass(data: PassUpdate):
    conn = sqlite3.connect("hostel.db")
    conn.execute("UPDATE passes SET status = ? WHERE student_id = ? AND time = ?", (data.status, data.student_id, data.time))
    conn.commit()
    return {"message": f"Pass {data.status}"}

@app.post("/post-notice")
async def post_notice(title: str = Form(...), message: str = Form(...), image: UploadFile = File(None)):
    filename = "null"
    if image:
        filename = image.filename
        with open(f"uploads/{filename}", "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
    
    conn = sqlite3.connect("hostel.db")
    conn.execute("INSERT INTO notices VALUES (?, ?, ?, date('now'))", (title, message, filename))
    conn.commit()
    return {"status": "Posted"}

@app.get("/get-notices")
def get_notices():
    conn = sqlite3.connect("hostel.db")
    rows = conn.execute("SELECT * FROM notices").fetchall()
    return [{"title": r[0], "message": r[1], "image_path": r[2], "date": r[3]} for r in rows]

# UPDATED COMPLAINT ROUTE
@app.post("/create-complaint")
def create_complaint(data: dict): # Assuming you are using a dict or Pydantic model
    conn = sqlite3.connect("hostel.db")
    c = conn.cursor()
    # Notice the extra "Pending" added at the end!
    c.execute("INSERT INTO complaints VALUES (?, ?, ?, ?, ?, ?)", 
              (data['student_id'], data['student_name'], data['issue'], data['category'], data['room_number'], "Pending"))
    conn.commit()
    conn.close()
    return {"status": "success"}

class UpdateComplaintRequest(BaseModel):
    student_id: str
    issue: str
    status: str

@app.post("/update-complaint")
def update_complaint(data: UpdateComplaintRequest):
    conn = sqlite3.connect("hostel.db")
    c = conn.cursor()
    c.execute("UPDATE complaints SET status = ? WHERE student_id = ? AND issue = ?", (data.status, data.student_id, data.issue))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/get-complaints")
def get_complaints():
    conn = sqlite3.connect("hostel.db")
    rows = conn.execute("SELECT * FROM complaints").fetchall()
    # Updated return to match the 5 columns
    return [{"student_id": r[0], "student_name": r[1], "issue": r[2], "category": r[3], "room": r[4]} for r in rows]

# UPDATED ATTENDANCE ROUTE
@app.post("/mark-attendance")
def mark_attendance(data: AttendanceRequest):
    conn = sqlite3.connect("hostel.db")
    # Saving location now too
    conn.execute("INSERT INTO attendance VALUES (?, ?, ?, ?)", (data.student_id, "Present", data.time, data.location))
    conn.commit()
    return {"status": "Marked"}

@app.get("/get-attendance")
def get_attendance():
    conn = sqlite3.connect("hostel.db")
    rows = conn.execute("SELECT * FROM attendance").fetchall()
    return [{"student_id": r[0], "status": r[1], "time": r[2], "location": r[3]} for r in rows]

@app.post("/rate-food")
def rate_food(data: RatingRequest):
    conn = sqlite3.connect("hostel.db")
    conn.execute("INSERT INTO ratings VALUES (?, ?, ?)", (data.student_id, data.meal, data.rating))
    conn.commit()
    return {"status": "Rated"}

@app.get("/get-ratings")
def get_ratings():
    conn = sqlite3.connect("hostel.db")
    rows = conn.execute("SELECT * FROM ratings").fetchall()
    return [{"student_id": r[0], "meal": r[1], "rating": r[2]} for r in rows]