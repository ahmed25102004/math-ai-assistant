"""FastAPI router for admin dashboard endpoints.

Exposes GET /admin/stats — live site-wide totals computed from the platform
database, gated to staff (admin / reviewer) like the review endpoints.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from backend.admin.schemas import AdminStatsResponse
from backend.admin.service import get_admin_stats, get_all_student_chat_logs
from backend.auth import service as auth_service
from backend.auth.schemas import AuthUser, CreateStudentRequest
from backend.config import Settings
from backend.db import connect
from backend.deps import get_settings, require_role

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=AdminStatsResponse)
async def admin_stats(
    current_user: Annotated[AuthUser, Depends(require_role("admin", "reviewer"))],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AdminStatsResponse:
    """Live site-wide totals for the admin dashboard (staff only)."""
    return get_admin_stats(settings.platform_db_path)


@router.get("/students")
async def admin_list_students(
    current_user: Annotated[AuthUser, Depends(require_role("admin", "reviewer"))],
    settings: Annotated[Settings, Depends(get_settings)],
) -> list[dict]:
    """List all student accounts (admin/staff only)."""
    conn = connect(settings.platform_db_path)
    try:
        return auth_service.list_students(conn)
    finally:
        conn.close()


@router.post("/students")
async def admin_create_student(
    payload: CreateStudentRequest,
    current_user: Annotated[AuthUser, Depends(require_role("admin", "reviewer"))],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    """Create a new student account (admin/staff only)."""
    import random
    pin = payload.pin_code or str(random.randint(100000, 999999))
    conn = connect(settings.platform_db_path)
    try:
        return auth_service.create_student_account(
            conn=conn,
            full_name=payload.full_name,
            pin_code=pin,
            start_date=payload.start_date,
            end_date=payload.end_date,
        )
    finally:
        conn.close()


@router.patch("/students/{student_id}/toggle")
async def admin_toggle_student(
    student_id: str,
    is_active: bool,
    current_user: Annotated[AuthUser, Depends(require_role("admin", "reviewer"))],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    """Toggle student active status."""
    conn = connect(settings.platform_db_path)
    try:
        auth_service.toggle_student_active(conn, student_id, is_active)
        return {"status": "ok", "student_id": student_id, "is_active": is_active}
    finally:
        conn.close()


@router.get("/chat-logs")
async def admin_chat_logs(
    current_user: Annotated[AuthUser, Depends(require_role("admin", "reviewer"))],
    settings: Annotated[Settings, Depends(get_settings)],
) -> list[dict]:
    """View all student chat logs and history for pedagogical audit."""
    return get_all_student_chat_logs(settings.platform_db_path)

