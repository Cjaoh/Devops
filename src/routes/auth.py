from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from src.database import get_db
from src.schemas.user import UserCreate, UserLogin, UserResponse, Token
from src.services.auth_service import register_user, authenticate_user, build_token
from src.utils.dependencies import get_current_user
from src.models.user import User

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(data: UserCreate, db: Session = Depends(get_db)):
    """Créer un nouveau compte utilisateur."""
    return register_user(db, data)


@router.post("/login", response_model=Token)
def login(data: UserLogin, db: Session = Depends(get_db)):
    """Connexion — retourne un JWT."""
    user = authenticate_user(db, data.email, data.password)
    return build_token(user)


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    """Retourne le profil de l'utilisateur connecté."""
    return current_user
