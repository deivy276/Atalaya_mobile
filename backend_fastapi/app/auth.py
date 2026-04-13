from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
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


class UserCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=80)
    password: str = Field(min_length=12, max_length=256)
    role: str = Field(default='operator', pattern='^(admin|operator)$')


class UserRoleUpdateRequest(BaseModel):
    role: str = Field(pattern='^(admin|operator)$')


class UserActivationRequest(BaseModel):
    is_active: bool


class UserAdminOut(BaseModel):
    username: str
    role: str
    is_active: bool


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
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS auth_login_attempts (
                username TEXT PRIMARY KEY,
                attempts INTEGER NOT NULL DEFAULT 0,
                locked_until TEXT,
                updated_at TEXT NOT NULL
            )
            '''
        )
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS auth_audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                actor_username TEXT,
                target_username TEXT,
                metadata_json TEXT,
                created_at TEXT NOT NULL
            )
            '''
        )
        now = datetime.now(tz=UTC).isoformat()
        if settings.bootstrap_admin_password:
            validate_password_policy(settings.bootstrap_admin_password)
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
    return URLSafeTimedSerializer(settings.auth_effective_secret_key, salt='atalaya-session-v1')


def validate_auth_runtime_security() -> None:
    settings = get_settings()
    env = (settings.app_env or 'dev').strip().lower()
    if env == 'prod' and not settings.auth_cookie_secure:
        raise RuntimeError('AUTH_COOKIE_SECURE must be true in prod.')
    if env == 'prod' and settings.auth_cookie_samesite_normalized not in {'lax', 'strict'}:
        raise RuntimeError('AUTH_COOKIE_SAMESITE must be Lax or Strict in prod.')
    if not settings.auth_effective_secret_key or settings.auth_effective_secret_key.startswith('change-me'):
        raise RuntimeError('AUTH_SECRET_KEY for current environment is not configured safely.')


def _password_has_required_complexity(password: str) -> bool:
    has_upper = any(char.isupper() for char in password)
    has_lower = any(char.islower() for char in password)
    has_digit = any(char.isdigit() for char in password)
    has_symbol = any(not char.isalnum() for char in password)
    return has_upper and has_lower and has_digit and has_symbol


def validate_password_policy(password: str) -> None:
    settings = get_settings()
    if len(password) < settings.auth_password_min_length:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f'Password must be at least {settings.auth_password_min_length} characters long.',
        )
    if password.lower() in settings.auth_banned_passwords:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Password is not allowed.')
    if not _password_has_required_complexity(password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Password must include uppercase, lowercase, numeric and symbol characters.',
        )


def _audit_log(
    event_type: str,
    actor_username: str | None = None,
    target_username: str | None = None,
    metadata_json: str | None = None,
) -> None:
    now = datetime.now(tz=UTC).isoformat()
    with _connect() as conn:
        conn.execute(
            '''
            INSERT INTO auth_audit_log (event_type, actor_username, target_username, metadata_json, created_at)
            VALUES (?, ?, ?, ?, ?)
            ''',
            (event_type, actor_username, target_username, metadata_json, now),
        )
        conn.commit()


def _is_locked_out(row: sqlite3.Row | None) -> tuple[bool, datetime | None]:
    if row is None or not row['locked_until']:
        return False, None
    locked_until = datetime.fromisoformat(str(row['locked_until']))
    if locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=UTC)
    now = datetime.now(tz=UTC)
    return locked_until > now, locked_until


def _record_failed_login(username: str) -> tuple[int, datetime | None]:
    settings = get_settings()
    now = datetime.now(tz=UTC)
    with _connect() as conn:
        row = conn.execute(
            'SELECT username, attempts, locked_until FROM auth_login_attempts WHERE username = ?',
            (username.lower(),),
        ).fetchone()
        attempts = int(row['attempts']) + 1 if row else 1
        locked_until = None
        if attempts >= settings.auth_login_max_attempts:
            locked_until = now + timedelta(minutes=settings.auth_login_lockout_minutes)
            attempts = 0
        conn.execute(
            '''
            INSERT INTO auth_login_attempts (username, attempts, locked_until, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(username) DO UPDATE SET
                attempts=excluded.attempts,
                locked_until=excluded.locked_until,
                updated_at=excluded.updated_at
            ''',
            (
                username.lower(),
                attempts,
                locked_until.isoformat() if locked_until else None,
                now.isoformat(),
            ),
        )
        conn.commit()
    return attempts, locked_until


def _clear_failed_login_state(username: str) -> None:
    with _connect() as conn:
        conn.execute('DELETE FROM auth_login_attempts WHERE username = ?', (username.lower(),))
        conn.commit()


def authenticate_user(username: str, password: str) -> AuthUser | None:
    normalized = username.strip().lower()
    with _connect() as conn:
        row = conn.execute(
            'SELECT username, password_hash, role, is_active FROM users WHERE lower(username) = ?',
            (normalized,),
        ).fetchone()

    if row is None or not bool(row['is_active']):
        _record_failed_login(normalized)
        _audit_log(event_type='login_failed', target_username=normalized)
        return None

    with _connect() as conn:
        lock_row = conn.execute(
            'SELECT username, attempts, locked_until FROM auth_login_attempts WHERE username = ?',
            (normalized,),
        ).fetchone()
    is_locked, _ = _is_locked_out(lock_row)
    if is_locked:
        _audit_log(event_type='login_failed_locked', target_username=normalized)
        return None

    if not check_password_hash(str(row['password_hash']), password):
        _record_failed_login(normalized)
        _audit_log(event_type='login_failed', target_username=normalized)
        return None

    _clear_failed_login_state(normalized)
    _audit_log(event_type='login_success', target_username=normalized)
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
        samesite=settings.auth_cookie_samesite_normalized,
        path='/',
    )


def clear_session_cookie(response: Response) -> None:
    settings = get_settings()
    response.delete_cookie(settings.auth_cookie_name, path='/')


def record_logout(user: AuthUser | None) -> None:
    _audit_log(event_type='logout', actor_username=user.username if user else None)


def list_users() -> list[UserAdminOut]:
    with _connect() as conn:
        rows = conn.execute(
            'SELECT username, role, is_active FROM users ORDER BY lower(username) ASC',
        ).fetchall()
    return [
        UserAdminOut(username=str(row['username']), role=str(row['role']), is_active=bool(row['is_active']))
        for row in rows
    ]


def create_user(actor: AuthUser, payload: UserCreateRequest) -> UserAdminOut:
    validate_password_policy(payload.password)
    now = datetime.now(tz=UTC).isoformat()
    normalized = payload.username.strip().lower()
    password_hash = generate_password_hash(payload.password)
    with _connect() as conn:
        conn.execute(
            '''
            INSERT INTO users (username, password_hash, role, is_active, created_at, updated_at)
            VALUES (?, ?, ?, 1, ?, ?)
            ''',
            (normalized, password_hash, payload.role.lower(), now, now),
        )
        conn.commit()
    _audit_log(event_type='user_created', actor_username=actor.username, target_username=normalized)
    return UserAdminOut(username=normalized, role=payload.role.lower(), is_active=True)


def set_user_role(actor: AuthUser, username: str, role: str) -> UserAdminOut:
    normalized = username.strip().lower()
    with _connect() as conn:
        conn.execute(
            '''
            UPDATE users
            SET role = ?, updated_at = ?
            WHERE lower(username) = ?
            ''',
            (role.lower(), datetime.now(tz=UTC).isoformat(), normalized),
        )
        row = conn.execute(
            'SELECT username, role, is_active FROM users WHERE lower(username) = ?',
            (normalized,),
        ).fetchone()
        conn.commit()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    _audit_log(event_type='user_role_changed', actor_username=actor.username, target_username=normalized)
    return UserAdminOut(username=str(row['username']), role=str(row['role']), is_active=bool(row['is_active']))


def set_user_activation(actor: AuthUser, username: str, is_active: bool) -> UserAdminOut:
    normalized = username.strip().lower()
    with _connect() as conn:
        conn.execute(
            '''
            UPDATE users
            SET is_active = ?, updated_at = ?
            WHERE lower(username) = ?
            ''',
            (1 if is_active else 0, datetime.now(tz=UTC).isoformat(), normalized),
        )
        row = conn.execute(
            'SELECT username, role, is_active FROM users WHERE lower(username) = ?',
            (normalized,),
        ).fetchone()
        conn.commit()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    _audit_log(
        event_type='user_activated' if is_active else 'user_deactivated',
        actor_username=actor.username,
        target_username=normalized,
    )
    return UserAdminOut(username=str(row['username']), role=str(row['role']), is_active=bool(row['is_active']))
