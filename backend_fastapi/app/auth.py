from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from fastapi import Depends, HTTPException, Request, Response, status
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from pydantic import BaseModel, Field
from werkzeug.security import check_password_hash, generate_password_hash

from .config import get_settings


@dataclass(frozen=True)
class AuthUser:
    username: str
    role: str


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=256)


class UserOut(BaseModel):
    username: str
    role: str


def _db_path() -> Path:
    settings = get_settings()
    return Path(settings.auth_sqlite_path).resolve()


def _connect() -> sqlite3.Connection:
    path = _db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def init_auth_db() -> None:
    settings = get_settings()
    with _connect() as conn:
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('admin', 'operator')),
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            '''
        )
        now = datetime.now(tz=UTC).isoformat()
        if settings.bootstrap_admin_password:
            password_hash = generate_password_hash(settings.bootstrap_admin_password)
            conn.execute(
                '''
                INSERT INTO users (username, password_hash, role, created_at, updated_at)
                VALUES (?, ?, 'admin', ?, ?)
                ON CONFLICT(username) DO UPDATE SET
                    password_hash=excluded.password_hash,
                    role='admin',
                    updated_at=excluded.updated_at
                ''',
                (settings.bootstrap_admin_username, password_hash, now, now),
            )
        conn.commit()


def _serializer() -> URLSafeTimedSerializer:
    settings = get_settings()
    return URLSafeTimedSerializer(settings.auth_secret_key, salt='atalaya-session-v1')


def authenticate_user(username: str, password: str) -> AuthUser | None:
    normalized = username.strip().lower()
    with _connect() as conn:
        row = conn.execute(
            'SELECT username, password_hash, role, is_active FROM users WHERE lower(username) = ?',
            (normalized,),
        ).fetchone()

    if row is None or not bool(row['is_active']):
        return None

    if not check_password_hash(str(row['password_hash']), password):
        return None

    return AuthUser(username=str(row['username']), role=str(row['role']))


def _resolve_auth_if_enabled(request: Request) -> AuthUser | None:
    settings = get_settings()
    if not settings.auth_enabled:
        return None

    raw = request.cookies.get(settings.auth_cookie_name)
    if not raw:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Authentication required')

    try:
        data = _serializer().loads(raw, max_age=settings.auth_session_timeout_hours * 3600)
    except SignatureExpired as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Session expired') from exc
    except BadSignature as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session') from exc

    username = str(data.get('u', '')).strip()
    if not username:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session payload')

    with _connect() as conn:
        row = conn.execute(
            'SELECT username, role, is_active FROM users WHERE lower(username) = ?',
            (username.lower(),),
        ).fetchone()

    if row is None or not bool(row['is_active']):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='User disabled or missing')

    return AuthUser(username=str(row['username']), role=str(row['role']))


def require_authenticated_if_enabled(request: Request) -> AuthUser | None:
    return _resolve_auth_if_enabled(request)


def require_roles_if_enabled(*allowed_roles: str):
    allowed = {role.strip().lower() for role in allowed_roles if role.strip()}

    def _dependency(request: Request) -> AuthUser | None:
        user = _resolve_auth_if_enabled(request)
        if user is None:
            return None
        if user.role.lower() not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
        return user

    return _dependency


def create_session_cookie(response: Response, user: AuthUser) -> None:
    settings = get_settings()
    token = _serializer().dumps({'u': user.username, 'r': user.role})
    response.set_cookie(
        key=settings.auth_cookie_name,
        value=token,
        max_age=settings.auth_session_timeout_hours * 3600,
        httponly=True,
        secure=settings.auth_cookie_secure,
        samesite='lax',
        path='/',
    )


def clear_session_cookie(response: Response) -> None:
    settings = get_settings()
    response.delete_cookie(settings.auth_cookie_name, path='/')
