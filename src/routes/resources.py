from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from src.database import get_db
from src.models.resource import Resource
from src.schemas.resource import ResourceCreate, ResourceUpdate, ResourceOut
from src.utils.dependencies import get_current_user, require_admin
from src.models.user import User

router = APIRouter()


@router.get("/", response_model=List[ResourceOut])
def list_resources(
    type: str | None = None,
    status: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Liste toutes les ressources. Filtres optionnels : type, status."""
    query = db.query(Resource)
    if type:
        query = query.filter(Resource.type == type)
    if status:
        query = query.filter(Resource.status == status)
    return query.order_by(Resource.name).all()


@router.get("/{resource_id}", response_model=ResourceOut)
def get_resource(
    resource_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Retourne une ressource par son ID."""
    resource = db.query(Resource).filter(Resource.id == resource_id).first()
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ressource introuvable.")
    return resource


@router.post("/", response_model=ResourceOut, status_code=status.HTTP_201_CREATED)
def create_resource(
    data: ResourceCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Créer une nouvelle ressource (admin uniquement)."""
    if db.query(Resource).filter(Resource.name == data.name).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Une ressource avec ce nom existe déjà.")
    resource = Resource(**data.model_dump())
    db.add(resource)
    db.commit()
    db.refresh(resource)
    return resource


@router.put("/{resource_id}", response_model=ResourceOut)
def update_resource(
    resource_id: int,
    data: ResourceUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Mettre à jour une ressource (admin uniquement)."""
    resource = db.query(Resource).filter(Resource.id == resource_id).first()
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ressource introuvable.")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(resource, field, value)
    db.commit()
    db.refresh(resource)
    return resource


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_resource(
    resource_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Supprimer une ressource (admin uniquement)."""
    resource = db.query(Resource).filter(Resource.id == resource_id).first()
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ressource introuvable.")
    db.delete(resource)
    db.commit()
