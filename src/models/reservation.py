from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from src.database import Base


class Reservation(Base):
    __tablename__ = "reservations"

    id          = Column(Integer, primary_key=True, index=True)
    resource_id = Column(Integer, ForeignKey("resources.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id     = Column(Integer, ForeignKey("users.id",     ondelete="CASCADE"), nullable=False, index=True)
    start_at    = Column(DateTime, nullable=False)
    end_at      = Column(DateTime, nullable=False)
    purpose     = Column(String(500), nullable=True)
    notes       = Column(Text,        nullable=True)
    status      = Column(String(20),  nullable=False, default="confirmed")
    # statuts: confirmed | cancelled | completed
    created_at  = Column(DateTime, default=datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    resource = relationship("Resource", back_populates="reservations")
    user     = relationship("User",     back_populates="reservations")

    def __repr__(self):
        return f"<Reservation id={self.id} resource_id={self.resource_id} [{self.start_at} → {self.end_at}]>"
