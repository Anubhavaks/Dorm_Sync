import os
import shutil
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends
from pydantic import BaseModel
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from google import genai
from google.genai import types

import models
from database import engine, get_db

# --- INITIALIZATION ---
app = FastAPI()

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

# Initialize the Gemini Client
client = genai.Client()

# Automatically create tables in PostgreSQL if they don't exist
models.Base.metadata.create_all(bind=engine)

# Seed initial admin and test users if the database is empty
def seed_initial_users():
    db = next(get_db())
    try:
        if not db.query(models.User).first():
            db.add_all([
                models.User(username='warden', password='admin123', role='warden'),
                models.User(username='Student_001', password='pass123', role='student'),
                models.User(username='Student_002', password='pass123', role='student')
            ])
            db.commit()
    except Exception as e:
        print(f"Error seeding database: {e}")
    finally:
        db.close()

seed_initial_users()

# --- DATA MODELS ---
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

class ComplaintRequest(BaseModel):
    student_id: str
    student_name: str 
    issue: str
    category: str
    room_number: str

class UpdateComplaintRequest(BaseModel):
    student_id: str
    issue: str
    status: str

class AttendanceRequest(BaseModel):
    student_id: str
    time: str
    location: str

class RatingRequest(BaseModel):
    student_id: str
    meal: str
    rating: int

# --- AI MODELS ---
class AICaughtDetails(BaseModel):
    category: str
    is_high_priority: bool

# --- API ROUTES ---

@app.get("/")
def home():
    return {"message": "Dorm_Sync API is Live and Running on PostgreSQL! 🚀 Go to /docs to view the dashboard."}

@app.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(
        models.User.username == data.username, 
        models.User.password == data.password
    ).first()
    
    if user:
        return {"status": "success", "role": user.role, "username": user.username}
    else:
        return {"status": "fail", "message": "Invalid Credentials"}

@app.post("/request-pass")
def request_pass(data: PassRequest, db: Session = Depends(get_db)):
    combined_time = f"Out: {data.out_time}\nIn: {data.in_time}"
    new_pass = models.Pass(
        student_id=data.student_id,
        reason=data.reason,
        time=combined_time,
        status="Pending"
    )
    db.add(new_pass)
    db.commit()
    return {"message": "Pass Requested"}

@app.get("/get-passes")
def get_passes(db: Session = Depends(get_db)):
    passes = db.query(models.Pass).all()
    return [{"student_id": p.student_id, "reason": p.reason, "time": p.time, "status": p.status} for p in passes]

@app.post("/update-pass")
def update_pass(data: PassUpdate, db: Session = Depends(get_db)):
    db_pass = db.query(models.Pass).filter(
        models.Pass.student_id == data.student_id,
        models.Pass.time == data.time
    ).first()
    
    if not db_pass:
        raise HTTPException(status_code=404, detail="Pass record not found")
        
    db_pass.status = data.status
    db.commit()
    return {"message": f"Pass {data.status}"}

@app.post("/post-notice")
async def post_notice(title: str = Form(...), message: str = Form(...), image: UploadFile = File(None), db: Session = Depends(get_db)):
    filename = "null"
    if image:
        filename = image.filename
        with open(f"uploads/{filename}", "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
    
    current_date = datetime.now().strftime("%Y-%m-%d")
    new_notice = models.Notice(
        title=title,
        message=message,
        image_path=filename,
        date=current_date
    )
    db.add(new_notice)
    db.commit()
    return {"status": "Posted"}

@app.get("/get-notices")
def get_notices(db: Session = Depends(get_db)):
    notices = db.query(models.Notice).all()
    return [{"title": n.title, "message": n.message, "image_path": n.image_path, "date": n.date} for n in notices]

@app.post("/create-complaint")
def create_complaint(data: ComplaintRequest, db: Session = Depends(get_db)):
    # 🧠 1. Intercept text and query Gemini
    try:
        prompt = f"""
        Analyze this hostel maintenance complaint: "{data.issue}"
        Determine its correct technical category (e.g., Electrical, Plumbing, Carpentry, Cleaning, Other) 
        and decide if it qualifies as an urgent hazard (fire, spark, flooding, shock, urgent security issue, etc.).
        """
        
        ai_response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=AICaughtDetails,
                temperature=0.1,
            ),
        )
        
        ai_data = AICaughtDetails.model_validate_json(ai_response.text)
        priority_label = "HIGH PRIORITY (AI Detected)" if ai_data.is_high_priority else "Normal"
        final_issue_text = f"[{priority_label}] {data.issue}"
        final_category = ai_data.category

    except Exception as ai_error:
        print(f"Gemini processing failed: {ai_error}")
        final_issue_text = f"[Normal] {data.issue}"
        final_category = data.category

    # 💾 2. Save using SQLAlchemy ORM
    new_complaint = models.Complaint(
        student_id=data.student_id,
        student_name=data.student_name,
        issue=final_issue_text,
        category=final_category,
        room=data.room_number,
        status="Pending"
    )
    db.add(new_complaint)
    db.commit()
    return {"status": "success", "message": "Ticket logged and analyzed!"}

@app.post("/update-complaint")
def update_complaint(data: UpdateComplaintRequest, db: Session = Depends(get_db)):
    complaint = db.query(models.Complaint).filter(
        models.Complaint.student_id == data.student_id,
        models.Complaint.issue == data.issue
    ).first()
    
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint record not found")
        
    complaint.status = data.status
    db.commit()
    return {"status": "success"}

@app.get("/get-complaints")
def get_complaints(db: Session = Depends(get_db)):
    complaints = db.query(models.Complaint).all()
    return [{
        "student_id": c.student_id, 
        "student_name": c.student_name, 
        "issue": c.issue, 
        "category": c.category, 
        "room": c.room, 
        "status": c.status
    } for c in complaints]

@app.post("/mark-attendance")
def mark_attendance(data: AttendanceRequest, db: Session = Depends(get_db)):
    new_attendance = models.Attendance(
        student_id=data.student_id,
        status="Present",
        time=data.time,
        location=data.location
    )
    db.add(new_attendance)
    db.commit()
    return {"status": "Marked"}

@app.get("/get-attendance")
def get_attendance(db: Session = Depends(get_db)):
    attendance_records = db.query(models.Attendance).all()
    return [{
        "student_id": a.student_id, 
        "status": a.status, 
        "time": a.time, 
        "location": a.location
    } for a in attendance_records]

@app.post("/rate-food")
def rate_food(data: RatingRequest, db: Session = Depends(get_db)):
    new_rating = models.Rating(
        student_id=data.student_id,
        meal=data.meal,
        rating=data.rating
    )
    db.add(new_rating)
    db.commit()
    return {"status": "Rated"}

@app.get("/get-ratings")
def get_ratings(db: Session = Depends(get_db)):
    ratings = db.query(models.Rating).all()
    return [{"student_id": r.student_id, "meal": r.meal, "rating": r.rating} for r in ratings]