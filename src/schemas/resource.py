from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ResourceCreate(BaseModel):
    name:        str
    type:        str = "other"          # vehicle | equipment | room | other
    description: Optional[str] = None
    capacity:    Optional[int] = None
    status:      str = "available"      # available | maintenance | retired


class ResourceUpdate(BaseModel):
    name:        Optional[str] = None
    type:        Optional[str] = None
    description: Optional[str] = None
    capacity:    Optional[int] = None
    status:      Optional[str] = None


class ResourceOut(BaseModel):
    id:          int
    name:        str
    type:        str
    description: Optional[str]
    capacity:    Optional[int]
    status:      str
    created_at:  datetime

    model_config = {"from_attributes": True}
