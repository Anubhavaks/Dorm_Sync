from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {"message": "Hostel Server is Running!"}

@app.get("/menu")
def get_menu():
    return {
        "breakfast": "Aloo Paratha",
        "lunch": "Dal Tadka & Rice",
        "dinner": "Paneer Butter Masala"
    }
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# This allows your Flutter app to talk to your Python code
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/menu")
def get_menu():
    return {
        "breakfast": "Aloo Paratha",
        "lunch": "Dal Tadka & Rice",
        "dinner": "Paneer Butter Masala"
    }
