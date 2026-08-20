"""Queries backing the admin dashboard ``/admin/stats`` endpoint.

Every number is computed live from the platform database (the same SQLite
file that owns documents, chunks and generation history), so the dashboard
reflects the real site state rather than a mirror or mock.
"""

from __future__ import annotations

import sqlite3

from backend.admin.schemas import AdminRecentDocument, AdminStatsResponse
from backend.db import connect

# ``history.agent`` values persisted by the generation service.
AGENT_QUESTION_BANK = "Question Bank"
AGENT_TEST_HELP = "Test Help"
AGENT_FLASHCARDS = "Flashcards"
AGENT_STUDY_PLAN = "Study Plan"

_RECENT_LIMIT = 5


def _scalar(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> int:
    return int(conn.execute(sql, params).fetchone()[0])


def _row_to_recent_document(row: sqlite3.Row) -> AdminRecentDocument:
    return AdminRecentDocument(
        id=row["id"],
        title=row["title"],
        kind=row["kind"],
        pages=row["pages"],
        chunks=int(row["chunk_count"]),
        status=row["status"],
    )


def get_admin_stats(db_path: str) -> AdminStatsResponse:
    """Compute live site-wide totals from the platform database."""
    conn = connect(db_path)
    try:
        documents = _scalar(conn, "SELECT COUNT(*) FROM documents")
        chunks_indexed = _scalar(
            conn, "SELECT COALESCE(SUM(chunk_count), 0) FROM documents"
        )
        workspaces = _scalar(conn, "SELECT COUNT(*) FROM workspaces")
        users = _scalar(conn, "SELECT COUNT(*) FROM users")
        questions = _scalar(
            conn,
            "SELECT COALESCE(SUM(items), 0) FROM history WHERE agent IN (?, ?)",
            (AGENT_QUESTION_BANK, AGENT_TEST_HELP),
        )
        flashcards = _scalar(
            conn,
            "SELECT COALESCE(SUM(items), 0) FROM history WHERE agent = ?",
            (AGENT_FLASHCARDS,),
        )
        study_plans = _scalar(
            conn, "SELECT COUNT(*) FROM history WHERE agent = ?", (AGENT_STUDY_PLAN,)
        )
        quality_row = conn.execute("SELECT AVG(quality) FROM history").fetchone()[0]
        quality = float(quality_row) if quality_row is not None else None
        recent_rows = conn.execute(
            "SELECT id, title, kind, pages, chunk_count, status "
            "FROM documents ORDER BY created_at DESC LIMIT ?",
            (_RECENT_LIMIT,),
        ).fetchall()
        return AdminStatsResponse(
            documents=documents,
            chunks_indexed=chunks_indexed,
            workspaces=workspaces,
            users=users,
            questions=questions,
            flashcards=flashcards,
            study_plans=study_plans,
            quality=quality,
            recent_documents=[_row_to_recent_document(r) for r in recent_rows],
        )
    finally:
        conn.close()


def get_all_student_chat_logs(db_path: str) -> list[dict]:
    """Retrieve all student chats and messages for admin review."""
    conn = connect(db_path)
    try:
        rows = conn.execute(
            """
            SELECT c.id AS chat_id, c.title, c.kind, c.model, c.created_at,
                   u.id AS user_id, u.email, p.full_name, st.pin_code
            FROM chats c
            JOIN users u ON u.id = c.user_id
            LEFT JOIN profiles p ON p.id = u.id
            LEFT JOIN students st ON st.user_id = u.id
            ORDER BY c.updated_at DESC
            """
        ).fetchall()
        result = []
        for r in rows:
            chat_id = r["chat_id"]
            msgs = conn.execute(
                """
                SELECT id, role, content, created_at
                FROM chat_messages
                WHERE chat_id = ?
                ORDER BY created_at ASC
                """,
                (chat_id,),
            ).fetchall()
            result.append(
                {
                    "chat_id": chat_id,
                    "title": r["title"],
                    "kind": r["kind"],
                    "model": r["model"],
                    "created_at": r["created_at"],
                    "user_id": r["user_id"],
                    "user_name": r["full_name"] or r["email"],
                    "pin_code": r["pin_code"] or "N/A",
                    "messages": [dict(m) for m in msgs],
                }
            )
        return result
    finally:
        conn.close()

