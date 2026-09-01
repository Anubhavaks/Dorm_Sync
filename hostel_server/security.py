import os
from datetime import datetime, timedelta
import jwt
import bcrypt # 👈 Using native bcrypt instead of passlib
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

# 1. Configuration Setup
SECRET_KEY = os.getenv("JWT_SECRET", "YOUR_SUPER_SECRET_COMPLEX_KEY_HERE_123456")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
security_bearer = HTTPBearer()

# 2. Hashing Utilities (Native)
def hash_password(password: str) -> str:
    """Converts a plain-text password into a secure bcrypt hash."""
    salt = bcrypt.gensalt()
    hashed_bytes = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed_bytes.decode('utf-8') # Return as string for the database

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Compares a plain password against the saved hash to see if they match."""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'), 
        hashed_password.encode('utf-8')
    )

# 3. JWT Token Utilities
def create_access_token(data: dict) -> str:
    """Generates a cryptographically signed JWT token that expires in 30 minutes."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security_bearer)) -> dict:
    """
    FastAPI dependency that intercepts requests, decodes the JWT, 
    and validates if the token is legit or expired.
    """
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        role: str = payload.get("role")
        if username is None or role is None:
            raise HTTPException(status_code=401, detail="Invalid token claims")
        return {"username": username, "role": role}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Session expired. Please log in again.")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
    