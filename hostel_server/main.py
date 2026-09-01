import security
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
from dotenv import load_dotenv
load_dotenv()
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.vectorstores import Chroma
from langchain_core.documents import Document
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
class PolicyQuery(BaseModel):
    question: str

# 1. Define the Ground-Truth Knowledge Base
hostel_rules = [
    Document(page_content="Curfew Policy: Standard entry closes at 10:00 PM. Students participating in authorized coding competitions (e.g., Hack Heist) may return up to 2:00 AM if an approved Gate Pass is presented.", metadata={"source": "Warden Rulebook v1.2"}),
    Document(page_content="Maintenance Policy: Electrical and flooding issues are dispatched immediately. Routine carpentry is handled Tuesdays and Thursdays.", metadata={"source": "Maintenance SLA"}),
    Document(page_content="Leave Policy: Any leave exceeding 3 days requires an email confirmation from the registered guardian to the warden.", metadata={"source": "Leave Guidelines"})
]

# 2. Convert text to mathematical vectors and store in ChromaDB
embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
vector_db = Chroma.from_documents(hostel_rules, embeddings, collection_name="dorm_policies")
retriever = vector_db.as_retriever(search_kwargs={"k": 1}) # Fetch only the top 1 most relevant rule

# 3. Initialize the LangChain LLM
rag_llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0)

# Seed initial admin and test users if the database is empty
def seed_initial_users():
    db = next(get_db())
    try:
        if not db.query(models.User).first():
            db.add_all([
                models.User(username='warden', password=security.hash_password('admin123'), role='warden'),
                models.User(username='Student_001', password=security.hash_password('pass123'), role='student'),
                models.User(username='Student_002', password=security.hash_password('pass123'), role='student')
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
    # Find the user by username only
    user = db.query(models.User).filter(models.User.username == data.username).first()
    
    # Verify if user exists and if the submitted plain text matches the saved secure hash
    if user and security.verify_password(data.password, user.password):
        # Generate a real, cryptographically signed token containing their username and role
        token = security.create_access_token(data={"sub": user.username, "role": user.role})
        
        return {
            "status": "success", 
            "role": user.role, 
            "username": user.username,
            "access_token": token,
            "token_type": "bearer"
        }
    else:
        raise HTTPException(status_code=401, detail="Invalid Credentials")

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

# --- AGENTIC DISPATCH TOOLS ---
def dispatch_electrician(room_number: str, issue: str, is_emergency: bool) -> dict:
    """Dispatches the electrical team for wiring, sparks, or power issues."""
    assigned = "Raju (Head Electrician)" if is_emergency else "Electrical Team"
    priority = "HIGH PRIORITY (AI Detected)" if is_emergency else "Normal"
    return {"category": "Electrical", "assigned_to": assigned, "priority": priority, "status": "In Progress" if is_emergency else "Pending"}

def dispatch_plumber(room_number: str, issue: str, is_emergency: bool) -> dict:
    """Dispatches the plumbing team for leaks, flooding, or pipe bursts."""
    assigned = "Mario (Head Plumber)" if is_emergency else "Plumbing Team"
    priority = "HIGH PRIORITY (AI Detected)" if is_emergency else "Normal"
    return {"category": "Plumbing", "assigned_to": assigned, "priority": priority, "status": "In Progress" if is_emergency else "Pending"}

def alert_warden_emergency(room_number: str, issue: str) -> dict:
    """Alerts the warden immediately for extreme hazards like fire, massive flooding, or severe security breaches."""
    return {"category": "Hazard", "assigned_to": "Warden (EMERGENCY RESPONSE)", "priority": "HIGH PRIORITY (AI Detected)", "status": "Escalated"}

def general_maintenance(room_number: str, issue: str, category: str) -> dict:
    """Assigns general maintenance for carpentry, cleaning, or routine issues."""
    return {"category": category, "assigned_to": "General Staff", "priority": "Normal", "status": "Pending"}

maintenance_tools = [dispatch_electrician, dispatch_plumber, alert_warden_emergency, general_maintenance]

# --- UPDATED AGENTIC ROUTE ---
@app.post("/create-complaint")
def create_complaint(data: ComplaintRequest, db: Session = Depends(get_db)):
    # 🧠 1. Agentic Routing via Gemini Function Calling
    try:
        prompt = f"""
        A student in Room {data.room_number} reported this issue: "{data.issue}"
        Analyze this complaint. If it is an electrical issue, call dispatch_electrician. 
        If it is a plumbing issue, call dispatch_plumber. 
        If it is a life-threatening hazard (fire, massive flood), call alert_warden_emergency. 
        Otherwise, call general_maintenance.
        """
        
        ai_response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                tools=maintenance_tools,
                temperature=0.1,
            ),
        )
        
        # Check if Gemini triggered a tool execution
        if ai_response.function_calls:
            fc = ai_response.function_calls[0]
            # Map the AI's requested tool to your native Python functions
            if fc.name == "dispatch_electrician":
                result = dispatch_electrician(**fc.args)
            elif fc.name == "dispatch_plumber":
                result = dispatch_plumber(**fc.args)
            elif fc.name == "alert_warden_emergency":
                result = alert_warden_emergency(**fc.args)
            elif fc.name == "general_maintenance":
                result = general_maintenance(**fc.args)
            else:
                result = general_maintenance(data.room_number, data.issue, data.category)
            
            final_category = result["category"]
            final_priority = result["priority"]
            assigned_to = result["assigned_to"]
            current_status = result["status"]
        else:
            # Fallback if no tool was called
            final_priority = "Normal"
            assigned_to = "General Staff"
            final_category = data.category
            current_status = "Pending"

        final_issue_text = f"[{final_priority}] {data.issue}"

    except Exception as ai_error:
        print(f"Gemini routing failed: {ai_error}")
        final_issue_text = f"[Normal] {data.issue}"
        final_category = data.category
        assigned_to = "Unassigned"
        current_status = "Pending"

    # 💾 2. Save intelligent routing data using SQLAlchemy ORM
    new_complaint = models.Complaint(
        student_id=data.student_id,
        student_name=data.student_name,
        issue=final_issue_text,
        category=final_category,
        room=data.room_number,
        status=current_status,
        assigned_to=assigned_to
    )
    db.add(new_complaint)
    db.commit()
    return {"status": "success", "message": f"Ticket intelligently routed to {assigned_to}!"}
@app.post("/update-complaint")
def update_complaint(
    data: UpdateComplaintRequest, 
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user)
):
    # 🔒 Security Check: Strict administrative lock
    if current_user["role"] != "warden":
        raise HTTPException(status_code=403, detail="Access denied. Administrative privileges required.")
        
    complaint = db.query(models.Complaint).filter(
        models.Complaint.student_id == data.student_id,
        models.Complaint.issue == data.issue
    ).first()
    
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint record not found")
        
    complaint.status = data.status
    db.commit()
    return {"status": "success", "message": "Complaint status updated by Warden."}

@app.get("/get-complaints")
def get_complaints(db: Session = Depends(get_db)):
    complaints = db.query(models.Complaint).all()
    return [{
        "student_id": c.student_id, 
        "student_name": c.student_name, 
        "issue": c.issue, 
        "category": c.category, 
        "room": c.room, 
        "status": c.status,
        "assigned_to": getattr(c, 'assigned_to', 'Unassigned')
    } for c in complaints]

@app.post("/ask-policy")
def ask_policy(
    query: PolicyQuery, 
    current_user: dict = Depends(security.get_current_user)
):
    # 1. Retrieve the exact policy chunk from ChromaDB
    retrieved_docs = retriever.invoke(query.question)
    
    if not retrieved_docs:
        return {"answer": "I don't have official guidelines regarding that specific query.", "source": "None"}
        
    context = retrieved_docs[0].page_content
    source_doc = retrieved_docs[0].metadata.get("source", "Unknown Document")
    
    # 2. Generate a strictly grounded answer
    prompt = f"""
    You are the official Dorm_Sync AI assistant. 
    Answer the student's question based STRICTLY on the provided Context. 
    If the Context does not contain the answer, say "Please consult the Warden directly."
    
    Context: '{context}'
    Question: {query.question}
    """
    
    response = rag_llm.invoke(prompt)
    
    return {
        "status": "success",
        "answer": response.content,
        "exact_source": source_doc,
        "retrieved_context": context
    }

# Note the new `current_user: dict = Depends(security.get_current_user)` parameter!
@app.post("/mark-attendance")
def mark_attendance(
    data: AttendanceRequest, 
    db: Session = Depends(get_db), 
    current_user: dict = Depends(security.get_current_user)
):
    # 🔒 Security Check: Ensure the token belongs to a student
    if current_user["role"] != "student":
        raise HTTPException(status_code=403, detail="Access denied. Only students can mark attendance.")
    
    # 🛡️ Integrity Check: Force the student_id to match the authenticated user's token
    # This prevents Student_001 from marking attendance for Student_002!
    authenticated_student = current_user["sub"]

    new_attendance = models.Attendance(
        student_id=authenticated_student,
        status="Present",
        time=data.time,
        location=data.location
    )
    db.add(new_attendance)
    db.commit()
    return {"status": "Marked", "message": f"Attendance verified for {authenticated_student}"}

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
