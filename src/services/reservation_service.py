from datetime import datetime
from fastapi import HTTPException, status
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from src.models.reservation import Reservation
from src.models.resource import Resource
from src.models.user import User
from src.schemas.reservation import ReservationCreate, ReservationUpdate


# ── Helpers ───────────────────────────────────────────────────────

def _get_reservation_or_404(db: Session, reservation_id: int) -> Reservation:
    r = db.query(Reservation).filter(Reservation.id == reservation_id).first()
    if not r:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Réservation introuvable.")
    return r


def _check_conflict(
    db: Session,
    resource_id: int,
    start_at: datetime,
    end_at: datetime,
    exclude_id: int | None = None,
) -> None:
    """Lève HTTP 409 si le créneau chevauche une réservation active existante."""
    query = db.query(Reservation).filter(
        Reservation.resource_id == resource_id,
        Reservation.status.in_(["confirmed", "pending"]),
        or_(
            and_(Reservation.start_at < end_at, Reservation.end_at > start_at),
        ),
    )
    if exclude_id:
        query = query.filter(Reservation.id != exclude_id)
    if query.first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce créneau est déjà réservé pour cette ressource.",
        )


def _assert_can_modify(reservation: Reservation, user: User) -> None:
    """Vérifie que l'utilisateur peut modifier cette réservation."""
    if user.role == "admin":
        return
    if reservation.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez modifier que vos propres réservations.",
        )
    if reservation.status in ("cancelled", "completed"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de modifier une réservation terminée ou annulée.",
        )


# ── Opérations CRUD ───────────────────────────────────────────────

def create_reservation(db: Session, data: ReservationCreate, current_user: User) -> Reservation:
    """Crée une réservation après vérification de la ressource et des conflits."""
    resource = db.query(Resource).filter(Resource.id == data.resource_id).first()
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ressource introuvable.")
    if resource.status != "available":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La ressource n'est pas disponible (statut actuel : {resource.status}).",
        )
    _check_conflict(db, data.resource_id, data.start_at, data.end_at)

    reservation = Reservation(
        resource_id=data.resource_id,
        user_id=current_user.id,
        start_at=data.start_at,
        end_at=data.end_at,
        purpose=data.purpose,
        notes=data.notes,
        status="confirmed",
    )
    db.add(reservation)
    db.commit()
    db.refresh(reservation)
    return reservation


def list_reservations(
    db: Session,
    current_user: User,
    resource_id: int | None = None,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> list[Reservation]:
    """Liste les réservations. Un admin voit tout, un user voit les siennes."""
    query = db.query(Reservation)
    if current_user.role != "admin":
        query = query.filter(Reservation.user_id == current_user.id)
    if resource_id:
        query = query.filter(Reservation.resource_id == resource_id)
    if from_date:
        query = query.filter(Reservation.start_at >= from_date)
    if to_date:
        query = query.filter(Reservation.end_at <= to_date)
    return query.order_by(Reservation.start_at).all()


def update_reservation(
    db: Session,
    reservation_id: int,
    data: ReservationUpdate,
    current_user: User,
) -> Reservation:
    """Met à jour les champs modifiables d'une réservation."""
    reservation = _get_reservation_or_404(db, reservation_id)
    _assert_can_modify(reservation, current_user)

    if data.start_at or data.end_at:
        new_start = data.start_at or reservation.start_at
        new_end   = data.end_at   or reservation.end_at
        _check_conflict(db, reservation.resource_id, new_start, new_end, exclude_id=reservation_id)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(reservation, field, value)

    db.commit()
    db.refresh(reservation)
    return reservation


def cancel_reservation(db: Session, reservation_id: int, current_user: User) -> Reservation:
    """Annule une réservation."""
    reservation = _get_reservation_or_404(db, reservation_id)
    _assert_can_modify(reservation, current_user)
    if reservation.status == "cancelled":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Réservation déjà annulée.")
    reservation.status = "cancelled"
    db.commit()
    db.refresh(reservation)
    return reservation


def get_reservation(db: Session, reservation_id: int, current_user: User) -> Reservation:
    """Retourne une réservation. Restreint aux admins ou au propriétaire."""
    reservation = _get_reservation_or_404(db, reservation_id)
    if current_user.role != "admin" and reservation.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return reservation
