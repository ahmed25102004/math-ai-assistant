"""Service functions for the auth domain (M1) — TEMPORARY SCAFFOLD.

Supabase is the single auth provider (milestone decision); this password,
session and demo-user implementation exists so the API runs without a
Supabase project and must be replaced by Supabase JWT verification during the
Supabase integration milestone. Do not build M3+ features on top of it.
"""

from __future__ import annotations

import json
import logging
import sqlite3
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

from .security import (
    generate_token,
    hash_password,
    hash_token,
    initials_for,
    verify_password,
)

logger = logging.getLogger(__name__)

# How long a resolved Supabase role is trusted before re-syncing.
_ROLE_SYNC_TTL_SECONDS = 120
_role_sync_cache: dict[str, tuple[float, str | None]] = {}


def now() -> datetime:
    return datetime.now(timezone.utc)


def sync_role_from_supabase(
    conn: sqlite3.Connection,
    *,
    user_id: str,
    access_token: str,
    supabase_url: str,
    anon_key: str,
) -> None:
    """Best-effort mirror of the authoritative Supabase role onto the platform.

    The frontend treats ``public.user_roles`` (read through the Data API with
    the user's own token) as the role source of truth. This function reads the
    same row the same way and keeps the platform ``user_roles`` table in sync,
    so staff-gated endpoints agree with what the UI shows.

    Results are cached per user for ``_ROLE_SYNC_TTL_SECONDS`` so at most one
    REST call happens per user per window. The sync never raises — auth must
    keep working even when Supabase is unreachable.
    """
    if not supabase_url:
        return
    now_ts = time.time()
    cached = _role_sync_cache.get(user_id)
    if cached is not None and now_ts - cached[0] < _ROLE_SYNC_TTL_SECONDS:
        return
    url = (
        f"{supabase_url.rstrip('/')}/rest/v1/user_roles"
        f"?user_id=eq.{user_id}&select=role"
    )
    req = urllib.request.Request(
        url,
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        role = body[0].get("role") if isinstance(body, list) and body else None
        _role_sync_cache[user_id] = (now_ts, role)
        if not role:
            return
        conn.execute(
            "UPDATE user_roles SET role = ? WHERE user_id = ?", (role, user_id)
        )
        conn.commit()
    except Exception as exc:  # noqa: BLE001 - auth must never fail on sync
        _role_sync_cache[user_id] = (now_ts, None)
        logger.warning("Supabase role sync failed for %s: %s", user_id, exc)


def create_user(
    conn: sqlite3.Connection,
    email: str,
    password: str,
    name: str,
    role: str,
) -> str:
    user_id = str(uuid.uuid4())
    conn.execute(
        "INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)",
        (user_id, email.strip().lower(), hash_password(password), now().isoformat()),
    )
    conn.execute(
        "INSERT INTO profiles (id, full_name, initials, created_at) VALUES (?, ?, ?, ?)",
        (user_id, name, initials_for(name), now().isoformat()),
    )
    conn.execute(
        "INSERT INTO user_roles (id, user_id, role) VALUES (?, ?, ?)",
        (str(uuid.uuid4()), user_id, role),
    )
    conn.commit()
    return user_id


def find_user_by_email(conn: sqlite3.Connection, email: str) -> dict | None:
    row = conn.execute(
        """
        SELECT u.id, u.email, u.password_hash, p.full_name, p.initials, r.role
        FROM users u
        LEFT JOIN profiles p ON p.id = u.id
        LEFT JOIN user_roles r ON r.user_id = u.id
        WHERE u.email = ?
        """,
        (email.strip().lower(),),
    ).fetchone()
    if row is None:
        return None
    user = dict(row)
    user["role"] = user["role"] or "student"
    return user


def authenticate_user(
    conn: sqlite3.Connection, email: str, password: str
) -> dict | None:
    user = find_user_by_email(conn, email)
    if user is None or not verify_password(password, user["password_hash"]):
        return None
    return user


def create_session(
    conn: sqlite3.Connection, user_id: str, access_ttl: int, refresh_ttl: int
) -> dict:
    access_token = generate_token()
    refresh_token = generate_token()
    session_id = str(uuid.uuid4())
    now_dt = now()
    expires_at = now_dt + timedelta(seconds=access_ttl)
    refresh_expires_at = now_dt + timedelta(seconds=refresh_ttl)
    conn.execute(
        """
        INSERT INTO sessions
            (id, user_id, access_token_hash, refresh_token_hash, expires_at, refresh_expires_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            session_id,
            user_id,
            hash_token(access_token),
            hash_token(refresh_token),
            expires_at.isoformat(),
            refresh_expires_at.isoformat(),
            now_dt.isoformat(),
        ),
    )
    conn.commit()
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_at": expires_at,
        "refresh_expires_at": refresh_expires_at,
    }


def revoke_session(conn: sqlite3.Connection, access_token: str) -> None:
    conn.execute(
        "UPDATE sessions SET revoked = 1 WHERE access_token_hash = ?",
        (hash_token(access_token),),
    )
    conn.commit()


def refresh_session(
    conn: sqlite3.Connection,
    refresh_token: str,
    access_ttl: int,
    refresh_ttl: int,
) -> dict | None:
    row = conn.execute(
        """
        SELECT id, user_id, revoked, refresh_expires_at
        FROM sessions
        WHERE refresh_token_hash = ?
        """,
        (hash_token(refresh_token),),
    ).fetchone()
    if row is None or row["revoked"]:
        return None
    expires_at = datetime.fromisoformat(row["refresh_expires_at"])
    if expires_at < now():
        return None
    conn.execute("UPDATE sessions SET revoked = 1 WHERE id = ?", (row["id"],))
    conn.commit()
    return create_session(conn, row["user_id"], access_ttl, refresh_ttl)


def find_user_by_id(conn: sqlite3.Connection, user_id: str) -> dict | None:
    row = conn.execute(
        """
        SELECT u.id, u.email, p.full_name, p.initials, r.role
        FROM users u
        LEFT JOIN profiles p ON p.id = u.id
        LEFT JOIN user_roles r ON r.user_id = u.id
        WHERE u.id = ?
        """,
        (user_id,),
    ).fetchone()
    if row is None:
        return None
    return {
        "id": row["id"],
        "email": row["email"],
        "name": row["full_name"] or "",
        "initials": row["initials"] or "",
        "role": row["role"] or "student",
    }


def ensure_supabase_user(
    conn: sqlite3.Connection,
    *,
    sub: str,
    email: str,
    name: str,
    role: str = "student",
) -> dict:
    """Return the platform user for a verified Supabase ``sub``, creating it on first login.

    This is the bridge between Supabase Auth (the single identity provider) and
    the platform's own tables: the workspace / document / review rows key off the
    platform ``users.id``, which is set to the Supabase user id. Because a
    Supabase user has no platform password, a placeholder hash is stored so the
    ``password_hash NOT NULL`` constraint is satisfied without ever being used.
    """
    existing = find_user_by_id(conn, sub)
    if existing is not None:
        return existing

    safe_email = (email or sub).strip().lower()
    user_id = sub

    # If a user with this email already exists in local SQLite under an old/demo ID,
    # update that user's ID to match the verified Supabase sub UUID.
    existing_by_email = find_user_by_email(conn, safe_email)
    if existing_by_email is not None:
        old_id = existing_by_email["id"]
        if old_id != sub:
            conn.execute("PRAGMA foreign_keys = OFF")
            conn.execute("UPDATE users SET id = ? WHERE id = ?", (sub, old_id))
            conn.execute("UPDATE profiles SET id = ? WHERE id = ?", (sub, old_id))
            conn.execute("UPDATE user_roles SET user_id = ? WHERE user_id = ?", (sub, old_id))
            conn.execute("UPDATE workspaces SET owner_id = ? WHERE owner_id = ?", (sub, old_id))
            conn.execute("PRAGMA foreign_keys = ON")
            conn.commit()
        return find_user_by_id(conn, sub) or {
            "id": sub,
            "email": safe_email,
            "name": name or existing_by_email.get("full_name") or safe_email.split("@")[0],
            "initials": initials_for(name or safe_email.split("@")[0]),
            "role": role,
        }

    conn.execute(
        "INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)",
        (user_id, safe_email, hash_password("supabase-unused"), now().isoformat()),
    )
    display = name or safe_email.split("@")[0] or "User"
    conn.execute(
        "INSERT INTO profiles (id, full_name, initials, created_at) VALUES (?, ?, ?, ?)",
        (user_id, display, initials_for(display), now().isoformat()),
    )
    conn.execute(
        "INSERT INTO user_roles (id, user_id, role) VALUES (?, ?, ?)",
        (str(uuid.uuid4()), user_id, role),
    )
    conn.commit()
    return {
        "id": user_id,
        "email": safe_email,
        "name": display,
        "initials": initials_for(display),
        "role": role,
    }


def user_for_token(conn: sqlite3.Connection, access_token: str) -> dict | None:
    row = conn.execute(
        """
        SELECT s.id, s.expires_at, s.revoked, u.id AS user_id, u.email,
               p.full_name, p.initials, r.role
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        LEFT JOIN profiles p ON p.id = u.id
        LEFT JOIN user_roles r ON r.user_id = u.id
        WHERE s.access_token_hash = ?
        """,
        (hash_token(access_token),),
    ).fetchone()
    if row is None or row["revoked"]:
        return None
    expires_at = datetime.fromisoformat(row["expires_at"])
    if expires_at < now():
        return None
    return {
        "id": row["user_id"],
        "email": row["email"],
        "name": row["full_name"],
        "initials": row["initials"],
        "role": row["role"] or "student",
    }


def create_student_account(
    conn: sqlite3.Connection,
    full_name: str,
    pin_code: str,
    start_date: str,
    end_date: str,
) -> dict:
    """Create a new student account with PIN code and date-based activation window."""
    clean_name = full_name.strip()
    clean_pin = pin_code.strip()
    student_email = f"student_{clean_pin}@math.app"
    user_id = create_user(
        conn=conn,
        email=student_email,
        password=f"pin_{clean_pin}_pass",
        name=clean_name,
        role="student",
    )
    student_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO students (id, user_id, full_name, pin_code, start_date, end_date, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, 1, ?)
        """,
        (student_id, user_id, clean_name, clean_pin, start_date, end_date, now().isoformat()),
    )
    conn.commit()
    return {
        "id": student_id,
        "user_id": user_id,
        "full_name": clean_name,
        "pin_code": clean_pin,
        "start_date": start_date,
        "end_date": end_date,
        "is_active": 1,
    }


def authenticate_student_by_pin(
    conn: sqlite3.Connection,
    full_name: str,
    pin_code: str,
) -> tuple[dict | None, str]:
    """Authenticate a student by full_name and PIN code, verifying date bounds.

    Returns:
        (user_dict_or_none, status_message)
    """
    clean_pin = pin_code.strip()
    row = conn.execute(
        """
        SELECT s.id AS student_id, s.user_id, s.full_name, s.pin_code, s.start_date, s.end_date, s.is_active,
               u.email
        FROM students s
        JOIN users u ON u.id = s.user_id
        WHERE s.pin_code = ?
        """,
        (clean_pin,),
    ).fetchone()

    if row is None:
        return None, "الرمز السري غير صحيح"

    if row["is_active"] != 1:
        return None, "حسابك الدراسي معطل حالياً. يرجى التواصل مع المعلم"

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    start_d = row["start_date"]
    end_d = row["end_date"]

    if today < start_d or today > end_d:
        return None, f"عذراً، تفعيل حسابك متاح فقط من {start_d} إلى {end_d}. حسابك غير فعال اليوم"

    user = find_user_by_id(conn, row["user_id"])
    return user, "OK"


def list_students(conn: sqlite3.Connection) -> list[dict]:
    """List all student accounts with active date windows."""
    rows = conn.execute(
        """
        SELECT s.id, s.user_id, s.full_name, s.pin_code, s.start_date, s.end_date, s.is_active, s.created_at
        FROM students s
        ORDER BY s.created_at DESC
        """
    ).fetchall()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    result = []
    for r in rows:
        d = dict(r)
        is_in_date_range = d["start_date"] <= today <= d["end_date"]
        d["currently_active"] = bool(d["is_active"] and is_in_date_range)
        result.append(d)
    return result


def toggle_student_active(conn: sqlite3.Connection, student_id: str, is_active: bool) -> bool:
    """Toggle a student account active/inactive."""
    conn.execute(
        "UPDATE students SET is_active = ? WHERE id = ?",
        (1 if is_active else 0, student_id),
    )
    conn.commit()
    return True

