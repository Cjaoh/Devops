from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List

from src.database import get_db
from src.schemas.reservation import ReservationCreate, ReservationUpdate, ReservationOut, ReservationSimple
from src.services.reservation_service import (
    create_reservation,
    list_reservations,
    get_reservation,
    update_reservation,
    cancel_reservation,
)
from src.services.email_service import send_reservation_confirmation, send_reservation_cancellation
from src.utils.dependencies import get_current_user
from src.models.user import User

router = APIRouter()


@router.get("/", response_model=List[ReservationSimple])
def list_my_reservations(
    resource_id: int | None = None,
    from_date:   datetime | None = None,
    to_date:     datetime | None = None,
    db:          Session = Depends(get_db),
    current_user: User   = Depends(get_current_user),
):
    """Liste les réservations. Admin = tout ; utilisateur = les siennes uniquement."""
    return list_reservations(db, current_user, resource_id, from_date, to_date)


@router.get("/{reservation_id}", response_model=ReservationOut)
def get_one_reservation(
    reservation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Détail d'une réservation (avec ressource et utilisateur)."""
    return get_reservation(db, reservation_id, current_user)


@router.post("/", response_model=ReservationOut, status_code=status.HTTP_201_CREATED)
def make_reservation(
    data: ReservationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Créer une réservation. Détecte automatiquement les conflits de créneaux."""
    reservation = create_reservation(db, data, current_user)
    # Notification email (non bloquant)
    try:
        send_reservation_confirmation(reservation)
    except Exception:
        pass
    return reservation


@router.put("/{reservation_id}", response_model=ReservationOut)
def modify_reservation(
    reservation_id: int,
    data: ReservationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Modifier une réservation existante."""
    return update_reservation(db, reservation_id, data, current_user)


@router.delete("/{reservation_id}", response_model=ReservationOut)
def cancel(
    reservation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Annuler une réservation. Envoie un email de confirmation d'annulation."""
    reservation = cancel_reservation(db, reservation_id, current_user)
    try:
        send_reservation_cancellation(reservation)
    except Exception:
        pass
    return reservation
