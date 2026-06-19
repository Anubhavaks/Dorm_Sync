from sqlalchemy import Column, Integer, String
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)
    role = Column(String)

class Pass(Base):
    __tablename__ = "passes"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String, index=True)
    reason = Column(String)
    time = Column(String)
    status = Column(String, default="Pending")

class Notice(Base):
    __tablename__ = "notices"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    message = Column(String)
    image_path = Column(String)
    date = Column(String)

class Complaint(Base):
    __tablename__ = "complaints"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String, index=True)
    student_name = Column(String)
    issue = Column(String)
    category = Column(String)
    room = Column(String)
    status = Column(String, default="Pending")

class Attendance(Base):
    __tablename__ = "attendance"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String, index=True)
    status = Column(String)
    time = Column(String)
    location = Column(String)

class Rating(Base):
    __tablename__ = "ratings"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String, index=True)
    meal = Column(String)
    rating = Column(Integer)