from pydantic import BaseModel, model_validator
from datetime import datetime, timezone
from typing import Optional
from src.schemas.resource import ResourceOut
from src.schemas.user import UserResponse


class ReservationCreate(BaseModel):
    resource_id: int
    start_at:    datetime
    end_at:      datetime
    purpose:     Optional[str] = None
    notes:       Optional[str] = None
    # Alias pour compatibilité avec le frontend qui envoie title/description
    title:       Optional[str] = None
    description: Optional[str] = None

    @model_validator(mode="after")
    def check_dates(self) -> "ReservationCreate":
        if self.end_at <= self.start_at:
            raise ValueError("La date de fin doit être postérieure à la date de début.")

        # FIX: comparaison timezone-aware
        start = self.start_at
        if start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        if start < datetime.now(timezone.utc):
            raise ValueError("La date de début ne peut pas être dans le passé.")

        # Compatibilité title → purpose
        if self.purpose is None and self.title is not None:
            self.purpose = self.title
        if self.notes is None and self.description is not None:
            self.notes = self.description

        return self


class ReservationUpdate(BaseModel):
    start_at: Optional[datetime] = None
    end_at:   Optional[datetime] = None
    purpose:  Optional[str] = None
    notes:    Optional[str] = None
    status:   Optional[str] = None


class ReservationOut(BaseModel):
    id:          int
    resource_id: int
    user_id:     int
    start_at:    datetime
    end_at:      datetime
    purpose:     Optional[str]
    notes:       Optional[str]
    status:      str
    created_at:  datetime
    resource:    ResourceOut
    user:        UserResponse
    model_config = {"from_attributes": True}


class ReservationSimple(BaseModel):
    """Version allégée pour les listes."""
    id:          int
    resource_id: int
    user_id:     int
    start_at:    datetime
    end_at:      datetime
    purpose:     Optional[str]
    status:      str
    created_at:  datetime
    model_config = {"from_attributes": True}
