from fastapi import APIRouter

from app.api.v1.endpoints import admin, centres, missions, startups, vehicles

api_router = APIRouter()
api_router.include_router(missions.router, prefix="/missions", tags=["Missions"])
api_router.include_router(vehicles.router, prefix="/vehicles", tags=["Launch Vehicles"])
api_router.include_router(startups.router, prefix="/startups", tags=["Space Startups"])
api_router.include_router(centres.router, prefix="/centres", tags=["ISRO Centres"])
api_router.include_router(admin.router, prefix="/admin", tags=["Admin"])