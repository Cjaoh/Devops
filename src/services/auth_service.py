from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.models.user import User
from src.utils.security import hash_password, verify_password, create_access_token
from src.schemas.user import UserCreate, Token


def register_user(db: Session, data: UserCreate) -> User:
    """Crée un nouvel utilisateur après vérification de l'unicité de l'email."""
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte avec cet email existe déjà.",
        )
    user = User(
        email=data.email,
        password=hash_password(data.password),
        full_name=data.full_name,
        role="user",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    """Vérifie email + mot de passe. Retourne l'utilisateur ou lève une exception."""
    user = db.query(User).filter(User.email == email, User.is_active == True).first()  # noqa: E712
    if not user or not verify_password(password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect.",
        )
    return user


def build_token(user: User) -> Token:
    """Génère le JWT pour l'utilisateur authentifié."""
    access_token = create_access_token({"sub": str(user.id), "role": user.role})
    return Token(access_token=access_token)
