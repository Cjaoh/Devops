import os


class Settings:
    # ── Application ───────────────────────────────────────────────
    APP_NAME: str = "Gestion de Réservation"
    APP_VERSION: str = "1.0.0"

    # ── PostgreSQL ────────────────────────────────────────────────
    DATABASE_URL: str = os.getenv("DATABASE_URL")
    if not DATABASE_URL:
        raise ValueError("La variable d'environnement DATABASE_URL doit être définie")

    # ── JWT ───────────────────────────────────────────────────────
    SECRET_KEY: str = os.getenv("SECRET_KEY")
    if not SECRET_KEY:
        raise ValueError("La variable d'environnement SECRET_KEY doit être définie pour la sécurité JWT")
    
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 60))

    # ── SMTP / Email ──────────────────────────────────────────────
    SMTP_HOST: str = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", 587))
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM: str = os.getenv("SMTP_FROM", "noreply@reservation.local")
    EMAIL_FROM_NAME: str = "Système de Réservation"

    # ── CORS ──────────────────────────────────────────────────────
    CORS_ORIGINS: list = [
        "http://localhost",
        "http://localhost:80",
        "http://192.168.43.130",
        "http://192.168.43.130:80",
    ]


settings = Settings()
