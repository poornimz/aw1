from datetime import date, datetime, timezone
from typing import Annotated, Any, Dict, List, Optional

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


UTCDatetime = Annotated[datetime, AfterValidator(_ensure_utc)]


class PaginationMeta(BaseModel):
    total: int
    limit: int
    offset: int
    has_more: bool


class OrganizationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str
    org_type: str
    focus_area: str
    is_startup: bool
    founded_year: Optional[int] = None
    headquarters: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    funding_stage: Optional[str] = None
    website: Optional[str] = None
    description: Optional[str] = None
    last_synced_at: UTCDatetime


class StartupListResponse(BaseModel):
    items: List[OrganizationOut]
    pagination: PaginationMeta
    last_synced_at: Optional[UTCDatetime] = None
    cache_hit: bool = False


class LaunchVehicleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str
    organization_id: int
    organization_name: Optional[str] = None
    status: str
    stages: Optional[int] = None
    height_m: Optional[float] = None
    liftoff_mass_tonnes: Optional[float] = None
    leo_payload_kg: Optional[int] = None
    gto_payload_kg: Optional[int] = None
    sso_payload_kg: Optional[int] = None
    first_flight_date: Optional[date] = None
    total_launches: int
    successful_launches: int
    description: Optional[str] = None
    image_url: Optional[str] = None
    last_synced_at: UTCDatetime


class VehicleListResponse(BaseModel):
    items: List[LaunchVehicleOut]
    pagination: PaginationMeta
    last_synced_at: Optional[UTCDatetime] = None
    cache_hit: bool = False


class PayloadOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    payload_type: str
    mass_kg: Optional[float] = None
    orbit: Optional[str] = None
    customer: Optional[str] = None
    description: Optional[str] = None


class MissionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    mission_code: str
    name: str
    program: str
    status: str
    organization_id: int
    organization_name: Optional[str] = None
    vehicle_id: Optional[int] = None
    vehicle_name: Optional[str] = None
    launch_site: Optional[str] = None
    launch_pad: Optional[str] = None
    orbit_type: Optional[str] = None
    launch_date_utc: Optional[UTCDatetime] = None
    is_crewed: bool
    summary: Optional[str] = None
    source_name: str
    last_synced_at: UTCDatetime
    payloads: List[PayloadOut] = Field(default_factory=list)


class MissionListResponse(BaseModel):
    items: List[MissionOut]
    pagination: PaginationMeta
    last_synced_at: Optional[UTCDatetime] = None
    cache_hit: bool = False


class NextMissionResponse(BaseModel):
    mission: Optional[MissionOut] = None
    server_time_utc: UTCDatetime
    last_synced_at: Optional[UTCDatetime] = None


class ISROCentreOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    city: str
    state: str
    latitude: float
    longitude: float
    specialization: str
    established_year: Optional[int] = None
    website: Optional[str] = None
    description: Optional[str] = None
    last_synced_at: UTCDatetime


class CentreListResponse(BaseModel):
    items: List[ISROCentreOut]
    pagination: PaginationMeta
    last_synced_at: Optional[UTCDatetime] = None
    cache_hit: bool = False


class SyncTriggerRequest(BaseModel):
    use_seed_only: bool = False


class SyncTriggerResponse(BaseModel):
    job_id: str
    status: str
    mode: str
    result: Optional[Dict[str, Any]] = None


class SyncStatusResponse(BaseModel):
    job_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None