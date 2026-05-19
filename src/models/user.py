from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from src.database import Base


class User(Base):
    __tablename__ = "users"

    id         = Column(Integer, primary_key=True, index=True)
    email      = Column(String(255), unique=True, index=True, nullable=False)
    password   = Column(String(255), nullable=False)           # hashed
    full_name  = Column(String(255), nullable=False, default="")
    role       = Column(String(20),  nullable=False, default="user")   # user | admin
    is_active  = Column(Boolean,     nullable=False, default=True)
    created_at = Column(DateTime,    default=datetime.utcnow)

    reservations = relationship("Reservation", back_populates="user", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<User id={self.id} email={self.email} role={self.role}>"
