import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 1. Fallback to local SQLite if Postgres URL isn't set yet (for local development)
# 1. Fallback to local SQLite if Postgres URL isn't set (for local development)
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "sqlite:///./hostel.db" # 👈 Changed fallback to local SQLite
)

# Fixes a common Render/Heroku URL quirk for production
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1).replace("postgres://", "postgresql://", 1) # Fixes a common Render/Heroku URL quirk

# 2. Create the SQLAlchemy Engine
engine = create_engine(DATABASE_URL)

# 3. Create a Session factory for handling database operations per request
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 4. Base class that our database models will inherit from
Base = declarative_base()

# 5. Dependency injection function to safely open/close DB connections in FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()