"""
Configuration base de données.
Supporte PostgreSQL (production) et SQLite (tests CI).
Utilise l'API SYNCHRONE pour être compatible avec les services existants.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://reserv_user:password@localhost:5432/reservations"
)

# Convertit postgresql+asyncpg:// → postgresql:// si besoin
if DATABASE_URL.startswith("postgresql+asyncpg://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://", 1)

# Convertit sqlite+aiosqlite:// → sqlite:// si besoin
if DATABASE_URL.startswith("sqlite+aiosqlite://"):
    DATABASE_URL = DATABASE_URL.replace("sqlite+aiosqlite://", "sqlite://", 1)

# ── Engine synchrone ──────────────────────────────────────────────
connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(DATABASE_URL, connect_args=connect_args, echo=False)

SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)

Base = declarative_base()


def get_db():
    """Dépendance FastAPI — fournit une session DB par requête."""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def init_db():
    """Crée toutes les tables (démarrage app + tests)."""
    Base.metadata.create_all(bind=engine)
