from datetime import date, datetime, timezone
from typing import List, Optional

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Organization(Base):
    """Space agencies (ISRO, NSIL, IN-SPACe) and Indian space startups."""

    __tablename__ = "organizations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(150), unique=True, nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(150), unique=True, nullable=False, index=True)
    org_type: Mapped[str] = mapped_column(
        String(50), nullable=False, default="startup", index=True
    )  # e.g. agency, startup, psu
    focus_area: Mapped[str] = mapped_column(
        String(120), nullable=False, default="Space Systems", index=True
    )
    is_startup: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    founded_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    headquarters: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    funding_stage: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    website: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    last_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )

    # Relationships
    launch_vehicles: Mapped[List["LaunchVehicle"]] = relationship(
        back_populates="organization", cascade="all, delete-orphan"
    )
    missions: Mapped[List["Mission"]] = relationship(
        back_populates="organization", cascade="all, delete-orphan"
    )
    payloads: Mapped[List["Payload"]] = relationship(back_populates="organization")

    __table_args__ = (
        Index("ix_organizations_startup_focus", "is_startup", "focus_area"),
    )


class LaunchVehicle(Base):
    """ISRO and private Indian launch vehicles (PSLV, GSLV, LVM3, Vikram-1, Agnibaan, etc.)."""

    __tablename__ = "launch_vehicles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True, nullable=False, index=True)
    organization_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(
        String(50), nullable=False, default="Operational", index=True
    )  # Operational, In Development, Retired
    stages: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    height_m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    liftoff_mass_tonnes: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    leo_payload_kg: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    gto_payload_kg: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    sso_payload_kg: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    first_flight_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    total_launches: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    successful_launches: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    last_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )

    # Relationships
    organization: Mapped["Organization"] = relationship(back_populates="launch_vehicles")
    missions: Mapped[List["Mission"]] = relationship(back_populates="vehicle")

    __table_args__ = (
        Index("ix_launch_vehicles_org_status", "organization_id", "status"),
    )


class Mission(Base):
    """Indian space launches, Gaganyaan milestones, and upcoming/historical missions."""

    __tablename__ = "missions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    mission_code: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    program: Mapped[str] = mapped_column(
        String(100), nullable=False, default="General", index=True
    )  # e.g. Gaganyaan, Chandrayaan, NavIC, Earth Observation, Commercial
    status: Mapped[str] = mapped_column(
        String(50), nullable=False, default="Upcoming", index=True
    )  # Upcoming, Scheduled, Successful, In Progress, Failed

    organization_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    vehicle_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("launch_vehicles.id", ondelete="SET NULL"), nullable=True, index=True
    )

    launch_site: Mapped[Optional[str]] = mapped_column(String(180), nullable=True)
    launch_pad: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    orbit_type: Mapped[Optional[str]] = mapped_column(String(80), nullable=True, index=True)
    launch_date_utc: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    is_crewed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    source_name: Mapped[str] = mapped_column(String(80), nullable=False, default="seed")
    external_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True, index=True)

    last_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )

    # Relationships
    organization: Mapped["Organization"] = relationship(back_populates="missions")
    vehicle: Mapped[Optional["LaunchVehicle"]] = relationship(back_populates="missions")
    payloads: Mapped[List["Payload"]] = relationship(
        back_populates="mission", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_missions_program_status", "program", "status"),
        Index("ix_missions_status_launch_date", "status", "launch_date_utc"),
    )


class Payload(Base):
    """Satellites, orbital modules, and hosted payloads aboard each mission."""

    __tablename__ = "payloads"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    mission_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("missions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    organization_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("organizations.id", ondelete="SET NULL"), nullable=True, index=True
    )
    payload_type: Mapped[str] = mapped_column(
        String(100), nullable=False, default="Satellite", index=True
    )
    mass_kg: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    orbit: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    customer: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )

    # Relationships
    mission: Mapped["Mission"] = relationship(back_populates="payloads")
    organization: Mapped[Optional["Organization"]] = relationship(back_populates="payloads")

    __table_args__ = (
        UniqueConstraint("mission_id", "name", name="uq_payloads_mission_name"),
    )


class ISROCentre(Base):
    """ISRO research, launch, and tracking centres across India."""

    __tablename__ = "isro_centres"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    state: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    specialization: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    established_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    website: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    last_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )