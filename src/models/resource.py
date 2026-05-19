from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from src.database import Base


class Resource(Base):
    __tablename__ = "resources"

    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String(255), unique=True, nullable=False, index=True)
    type        = Column(String(50),  nullable=False, default="other")
    # types: vehicle | equipment | room | other
    description = Column(Text,        nullable=True)
    capacity    = Column(Integer,     nullable=True)
    status      = Column(String(20),  nullable=False, default="available")
    # statuts: available | maintenance | retired
    created_at  = Column(DateTime,    default=datetime.utcnow)
    updated_at  = Column(DateTime,    default=datetime.utcnow, onupdate=datetime.utcnow)

    reservations = relationship("Reservation", back_populates="resource", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Resource id={self.id} name={self.name} type={self.type}>"
