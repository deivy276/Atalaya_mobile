from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, Request, Response, status
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session
from werkzeug.security import check_password_hash, generate_password_hash

from .config import get_settings
from .database import get_db


@dataclass(frozen=True)
class AuthUser:
    id: int
    username: str
    role: str


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=256)
    otp_code: str | None = Field(default=None, min_length=6, max_length=8)
    new_password: str | None = Field(default=None, min_length=12, max_length=256)


class UserOut(BaseModel):
    username: str
    role: str


class PermissionOut(BaseModel):
    code: str


class RoleOut(BaseModel):
    name: str
    permissions: list[str]


class UserCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=80)
    email: str = Field(min_length=5, max_length=180)
    password: str = Field(min_length=12, max_length=256)
    role: str = Field(default='viewer', pattern='^(admin|specialist|operator|viewer)$')


class UserRoleUpdateRequest(BaseModel):
    role: str = Field(pattern='^(admin|specialist|operator|viewer)$')


class UserActivationRequest(BaseModel):
    is_active: bool


class UserWellAccessUpdateRequest(BaseModel):
    wells: list[str] = Field(default_factory=list)


class UserAdminOut(BaseModel):
    id: int
    username: str
    email: str
    role: str
    is_active: bool
    failed_attempts: int
    locked_until: datetime | None
    last_login_at: datetime | None
    force_password_change: bool
    mfa_enabled: bool


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=256)
    new_password: str = Field(min_length=12, max_length=256)


class PasswordResetTokenOut(BaseModel):
    token: str
    expiresAt: datetime


class PasswordResetConfirmRequest(BaseModel):
    token: str = Field(min_length=12, max_length=240)
    new_password: str = Field(min_length=12, max_length=256)


class SessionOut(BaseModel):
    sessionId: str
    username: str
    createdAt: datetime
    expiresAt: datetime
    revokedAt: datetime | None
    revokeReason: str | None


class SessionRevokeRequest(BaseModel):
    reason: str = Field(default='manual_revoke', min_length=3, max_length=120)


class MfaSetupOut(BaseModel):
    secret: str
    otpauthUri: str


class MfaEnableRequest(BaseModel):
    otp_code: str = Field(min_length=6, max_length=8)


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
    if env == 'prod' and '*' in settings.cors_origins:
        raise RuntimeError('CORS_ORIGINS cannot be * in prod.')


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


def _base32_secret(length: int = 20) -> str:
    raw = secrets.token_bytes(length)
    return base64.b32encode(raw).decode('utf-8').rstrip('=')


def _totp_now(secret: str, timestep: int = 30, digits: int = 6, at: datetime | None = None) -> str:
    now = at or datetime.now(timezone.utc)
    counter = int(now.timestamp() // timestep)
    padded_secret = secret + ('=' * ((8 - len(secret) % 8) % 8))
    key = base64.b32decode(padded_secret, casefold=True)
    msg = counter.to_bytes(8, 'big')
    digest = hmac.new(key, msg, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code_int = int.from_bytes(digest[offset : offset + 4], 'big') & 0x7FFFFFFF
    return str(code_int % (10**digits)).zfill(digits)


def _verify_totp(secret: str, otp_code: str, window_steps: int = 1) -> bool:
    now = datetime.now(timezone.utc)
    for step in range(-window_steps, window_steps + 1):
        at = now + timedelta(seconds=step * 30)
        if hmac.compare_digest(_totp_now(secret, at=at), otp_code):
            return True
    return False


def init_auth_db(db: Session) -> None:
    db.execute(text('CREATE TABLE IF NOT EXISTS permissions (id BIGSERIAL PRIMARY KEY, code TEXT UNIQUE NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())'))
    db.execute(text('CREATE TABLE IF NOT EXISTS roles (id BIGSERIAL PRIMARY KEY, name TEXT UNIQUE NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())'))
    db.execute(text('CREATE TABLE IF NOT EXISTS role_permissions (role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE, permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE, PRIMARY KEY (role_id, permission_id))'))
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS users (
                id BIGSERIAL PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role_id BIGINT NOT NULL REFERENCES roles(id),
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                force_password_change BOOLEAN NOT NULL DEFAULT TRUE,
                mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                mfa_secret TEXT,
                last_login_at TIMESTAMPTZ,
                failed_attempts INTEGER NOT NULL DEFAULT 0,
                locked_until TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )
    db.execute(text('CREATE TABLE IF NOT EXISTS user_well_access (user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, well_name TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY (user_id, well_name))'))
    db.execute(text('CREATE TABLE IF NOT EXISTS auth_audit_log (id BIGSERIAL PRIMARY KEY, event_type TEXT NOT NULL, actor_username TEXT, target_username TEXT, metadata_json TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())'))
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS auth_sessions (
                session_id UUID PRIMARY KEY,
                user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                expires_at TIMESTAMPTZ NOT NULL,
                revoked_at TIMESTAMPTZ,
                revoke_reason TEXT,
                last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS password_reset_tokens (
                token_hash TEXT PRIMARY KEY,
                user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                expires_at TIMESTAMPTZ NOT NULL,
                used_at TIMESTAMPTZ,
                created_by BIGINT REFERENCES users(id),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )

    _seed_rbac(db)
    _seed_bootstrap_admin(db)
    db.commit()


def _seed_rbac(db: Session) -> None:
    for permission in ('dashboard:read', 'alerts:read', 'control_panel:write', 'users:manage', 'sessions:revoke', 'mfa:manage'):
        db.execute(text('INSERT INTO permissions(code) VALUES (:code) ON CONFLICT(code) DO NOTHING'), {'code': permission})

    roles = {
        'admin': ['dashboard:read', 'alerts:read', 'control_panel:write', 'users:manage', 'sessions:revoke', 'mfa:manage'],
        'specialist': ['dashboard:read', 'alerts:read', 'control_panel:write', 'mfa:manage'],
        'operator': ['dashboard:read', 'alerts:read'],
        'viewer': ['dashboard:read', 'alerts:read'],
    }
    for role_name, permissions in roles.items():
        db.execute(text('INSERT INTO roles(name) VALUES (:name) ON CONFLICT(name) DO NOTHING'), {'name': role_name})
        for permission in permissions:
            db.execute(
                text('INSERT INTO role_permissions(role_id, permission_id) SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = :role_name AND p.code = :permission_code ON CONFLICT(role_id, permission_id) DO NOTHING'),
                {'role_name': role_name, 'permission_code': permission},
            )

    _seed_rbac(db)
    _seed_bootstrap_admin(db)
    db.commit()


def _seed_rbac(db: Session) -> None:
    for permission in ('dashboard:read', 'alerts:read', 'control_panel:write', 'users:manage', 'sessions:revoke', 'mfa:manage'):
        db.execute(text('INSERT INTO permissions(code) VALUES (:code) ON CONFLICT(code) DO NOTHING'), {'code': permission})

    roles = {
        'admin': ['dashboard:read', 'alerts:read', 'control_panel:write', 'users:manage', 'sessions:revoke', 'mfa:manage'],
        'specialist': ['dashboard:read', 'alerts:read', 'control_panel:write', 'mfa:manage'],
        'operator': ['dashboard:read', 'alerts:read'],
        'viewer': ['dashboard:read', 'alerts:read'],
    }
    for role_name, permissions in roles.items():
        db.execute(text('INSERT INTO roles(name) VALUES (:name) ON CONFLICT(name) DO NOTHING'), {'name': role_name})
        for permission in permissions:
            db.execute(
                text('INSERT INTO role_permissions(role_id, permission_id) SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = :role_name AND p.code = :permission_code ON CONFLICT(role_id, permission_id) DO NOTHING'),
                {'role_name': role_name, 'permission_code': permission},
            )

def _seed_bootstrap_admin(db: Session) -> None:
    settings = get_settings()
    if not settings.bootstrap_admin_password:
        return
    validate_password_policy(settings.bootstrap_admin_password)
    password_hash = generate_password_hash(settings.bootstrap_admin_password)
    db.execute(
        text(
            '''
            INSERT INTO users(username, email, password_hash, role_id, is_active, force_password_change)
            SELECT :username, :email, :password_hash, r.id, TRUE, TRUE
            FROM roles r WHERE r.name = 'admin'
            ON CONFLICT(username) DO UPDATE
            SET password_hash = EXCLUDED.password_hash,
                role_id = EXCLUDED.role_id,
                updated_at = NOW()
            '''
        ),
        {
            'username': settings.bootstrap_admin_username.strip().lower(),
            'email': f"{settings.bootstrap_admin_username.strip().lower()}@local.invalid",
            'password_hash': password_hash,
        },
    )


def _audit_log(db: Session, event_type: str, actor_username: str | None = None, target_username: str | None = None, metadata: dict | None = None) -> None:
    db.execute(
        text('INSERT INTO auth_audit_log (event_type, actor_username, target_username, metadata_json) VALUES (:event_type, :actor_username, :target_username, :metadata_json)'),
        {
            'event_type': event_type,
            'actor_username': actor_username,
            'target_username': target_username,
            'metadata_json': json.dumps(metadata or {}, ensure_ascii=False),
        },
    )


def _find_user_by_username(db: Session, username: str):
    return db.execute(
        text(
            '''
            SELECT u.id, u.username, u.email, u.password_hash, u.is_active, u.force_password_change, u.mfa_enabled, u.mfa_secret,
                   u.failed_attempts, u.locked_until, r.name AS role_name
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE lower(u.username) = :username
            '''
        ),
        {'username': username.strip().lower()},
    ).mappings().first()


def _open_session(db: Session, user_id: int, ttl_seconds: int) -> str:
    session_id = str(uuid.uuid4())
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds)
    db.execute(
        text('INSERT INTO auth_sessions(session_id, user_id, expires_at) VALUES (:sid, :uid, :exp)'),
        {'sid': session_id, 'uid': user_id, 'exp': expires_at},
    )
    return session_id


def authenticate_user(db: Session, payload: LoginRequest) -> AuthUser | None:
    settings = get_settings()
    normalized = payload.username.strip().lower()
    row = _find_user_by_username(db, normalized)
    if row is None or not bool(row['is_active']):
        _audit_log(db, 'login_failed', target_username=normalized)
        db.commit()
        return None

    now = datetime.now(timezone.utc)
    locked_until = row['locked_until']
    if isinstance(locked_until, datetime) and locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=timezone.utc)
    if isinstance(locked_until, datetime) and locked_until > now:
        _audit_log(db, 'login_failed_locked', target_username=normalized)
        db.commit()
        return None

    if not check_password_hash(str(row['password_hash']), payload.password):
        failed_attempts = int(row['failed_attempts'] or 0) + 1
        next_locked_until = None
        if failed_attempts >= settings.auth_login_max_attempts:
            next_locked_until = now + timedelta(minutes=settings.auth_login_lockout_minutes)
            failed_attempts = 0
        db.execute(text('UPDATE users SET failed_attempts = :fa, locked_until = :lu, updated_at = NOW() WHERE id = :uid'), {'fa': failed_attempts, 'lu': next_locked_until, 'uid': int(row['id'])})
        _audit_log(db, 'login_failed', target_username=normalized)
        db.commit()
        return None

    role = str(row['role_name'])
    if bool(row['mfa_enabled']) and role in {'admin', 'specialist'}:
        if not payload.otp_code or not _verify_totp(str(row['mfa_secret']), payload.otp_code.strip()):
            _audit_log(db, 'login_failed_mfa', target_username=normalized)
            db.commit()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='MFA code required or invalid')

    if bool(row['force_password_change']):
        if not payload.new_password:
            raise HTTPException(status_code=status.HTTP_428_PRECONDITION_REQUIRED, detail='Password change required at first login')
        validate_password_policy(payload.new_password)
        db.execute(
            text('UPDATE users SET password_hash = :ph, force_password_change = FALSE, updated_at = NOW() WHERE id = :uid'),
            {'ph': generate_password_hash(payload.new_password), 'uid': int(row['id'])},
        )

    db.execute(text('UPDATE users SET failed_attempts = 0, locked_until = NULL, last_login_at = NOW(), updated_at = NOW() WHERE id = :uid'), {'uid': int(row['id'])})
    _audit_log(db, 'login_success', target_username=normalized)
    db.commit()
    return AuthUser(id=int(row['id']), username=str(row['username']), role=role)


def _resolve_auth_if_enabled(request: Request, db: Session) -> AuthUser | None:
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

    user_id = int(data.get('uid', 0) or 0)
    username = str(data.get('u', '')).strip().lower()
    session_id = str(data.get('sid', '')).strip()
    if not user_id or not username or not session_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session payload')

    session_row = db.execute(
        text('SELECT session_id, expires_at, revoked_at FROM auth_sessions WHERE session_id = :sid AND user_id = :uid'),
        {'sid': session_id, 'uid': user_id},
    ).mappings().first()
    if session_row is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Session not found')
    if session_row['revoked_at'] is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Session revoked')
    expires_at = session_row['expires_at']
    if isinstance(expires_at, datetime) and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if isinstance(expires_at, datetime) and expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Session expired')

    row = db.execute(
        text('SELECT u.id, u.username, u.is_active, r.name AS role_name FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id = :uid AND lower(u.username)=:username'),
        {'uid': user_id, 'username': username},
    ).mappings().first()
    if row is None or not bool(row['is_active']):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='User disabled or missing')

    db.execute(text('UPDATE auth_sessions SET last_seen_at = NOW() WHERE session_id = :sid'), {'sid': session_id})
    db.commit()
    return AuthUser(id=int(row['id']), username=str(row['username']), role=str(row['role_name']))


def require_authenticated_if_enabled(request: Request, db: Session = Depends(get_db)) -> AuthUser | None:
    return _resolve_auth_if_enabled(request, db)


def require_roles_if_enabled(*allowed_roles: str):
    allowed = {role.strip().lower() for role in allowed_roles if role.strip()}

    def _dependency(request: Request, db: Session = Depends(get_db)) -> AuthUser | None:
        user = _resolve_auth_if_enabled(request, db)
        if user is None:
            return None
        if user.role.lower() not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
        return user

    return _dependency


def create_session_cookie(db: Session, response: Response, user: AuthUser) -> None:
    settings = get_settings()
    ttl_seconds = settings.auth_session_timeout_hours * 3600
    session_id = _open_session(db, user.id, ttl_seconds)
    token = _serializer().dumps({'uid': user.id, 'u': user.username, 'r': user.role, 'sid': session_id})
    response.set_cookie(
        key=settings.auth_cookie_name,
        value=token,
        max_age=ttl_seconds,
        httponly=True,
        secure=settings.auth_cookie_secure,
        samesite=settings.auth_cookie_samesite_normalized,
        path='/',
    )
    db.commit()


def clear_session_cookie(response: Response) -> None:
    settings = get_settings()
    response.delete_cookie(settings.auth_cookie_name, path='/')


def revoke_current_session(db: Session, request: Request, reason: str = 'logout') -> None:
    settings = get_settings()
    raw = request.cookies.get(settings.auth_cookie_name)
    if not raw:
        return
    try:
        data = _serializer().loads(raw, max_age=settings.auth_session_timeout_hours * 3600)
    except Exception:
        return
    sid = str(data.get('sid', '')).strip()
    if not sid:
        return
    db.execute(text('UPDATE auth_sessions SET revoked_at = NOW(), revoke_reason = :reason WHERE session_id = :sid AND revoked_at IS NULL'), {'reason': reason, 'sid': sid})
    db.commit()


def record_logout(db: Session, user: AuthUser | None) -> None:
    _audit_log(db, event_type='logout', actor_username=user.username if user else None)
    db.commit()


def list_permissions(db: Session) -> list[PermissionOut]:
    rows = db.execute(text('SELECT code FROM permissions ORDER BY code ASC')).mappings().all()
    return [PermissionOut(code=str(row['code'])) for row in rows]


def list_roles(db: Session) -> list[RoleOut]:
    rows = db.execute(text('SELECT r.name AS role_name, p.code AS permission_code FROM roles r LEFT JOIN role_permissions rp ON rp.role_id = r.id LEFT JOIN permissions p ON p.id = rp.permission_id ORDER BY r.name ASC, p.code ASC')).mappings().all()
    grouped: dict[str, list[str]] = {}
    for row in rows:
        name = str(row['role_name'])
        grouped.setdefault(name, [])
        if row['permission_code']:
            grouped[name].append(str(row['permission_code']))
    return [RoleOut(name=name, permissions=permissions) for name, permissions in grouped.items()]


def list_users(db: Session) -> list[UserAdminOut]:
    rows = db.execute(text('SELECT u.id, u.username, u.email, u.is_active, u.failed_attempts, u.locked_until, u.last_login_at, u.force_password_change, u.mfa_enabled, r.name AS role_name FROM users u JOIN roles r ON r.id=u.role_id ORDER BY lower(u.username) ASC')).mappings().all()
    return [UserAdminOut(id=int(r['id']), username=str(r['username']), email=str(r['email']), role=str(r['role_name']), is_active=bool(r['is_active']), failed_attempts=int(r['failed_attempts'] or 0), locked_until=r['locked_until'], last_login_at=r['last_login_at'], force_password_change=bool(r['force_password_change']), mfa_enabled=bool(r['mfa_enabled'])) for r in rows]


def create_user(db: Session, actor: AuthUser, payload: UserCreateRequest) -> UserAdminOut:
    validate_password_policy(payload.password)
    row = db.execute(
        text('INSERT INTO users(username, email, password_hash, role_id, is_active, force_password_change) SELECT :username, :email, :password_hash, r.id, TRUE, TRUE FROM roles r WHERE r.name = :role RETURNING id, username, email, is_active, failed_attempts, locked_until, last_login_at, force_password_change, mfa_enabled'),
        {'username': payload.username.strip().lower(), 'email': payload.email.strip().lower(), 'password_hash': generate_password_hash(payload.password), 'role': payload.role.lower()},
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid role')
    _audit_log(db, 'user_created', actor_username=actor.username, target_username=str(row['username']))
    db.commit()
    return UserAdminOut(id=int(row['id']), username=str(row['username']), email=str(row['email']), role=payload.role.lower(), is_active=bool(row['is_active']), failed_attempts=int(row['failed_attempts'] or 0), locked_until=row['locked_until'], last_login_at=row['last_login_at'], force_password_change=bool(row['force_password_change']), mfa_enabled=bool(row['mfa_enabled']))


def set_user_role(db: Session, actor: AuthUser, username: str, role: str) -> UserAdminOut:
    row = db.execute(text('UPDATE users u SET role_id = r.id, updated_at = NOW() FROM roles r WHERE lower(u.username) = :username AND r.name = :role RETURNING u.id, u.username, u.email, u.is_active, u.failed_attempts, u.locked_until, u.last_login_at, u.force_password_change, u.mfa_enabled'), {'username': username.strip().lower(), 'role': role.lower()}).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User or role not found')
    _audit_log(db, 'user_role_changed', actor_username=actor.username, target_username=str(row['username']))
    db.commit()
    return UserAdminOut(id=int(row['id']), username=str(row['username']), email=str(row['email']), role=role.lower(), is_active=bool(row['is_active']), failed_attempts=int(row['failed_attempts'] or 0), locked_until=row['locked_until'], last_login_at=row['last_login_at'], force_password_change=bool(row['force_password_change']), mfa_enabled=bool(row['mfa_enabled']))


def set_user_activation(db: Session, actor: AuthUser, username: str, is_active: bool) -> UserAdminOut:
    row = db.execute(text('UPDATE users SET is_active = :active, updated_at = NOW() WHERE lower(username) = :username RETURNING id, username, email, role_id, is_active, failed_attempts, locked_until, last_login_at, force_password_change, mfa_enabled'), {'active': bool(is_active), 'username': username.strip().lower()}).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    role_name = db.execute(text('SELECT name FROM roles WHERE id = :rid'), {'rid': int(row['role_id'])}).scalar_one()
    _audit_log(db, 'user_activated' if is_active else 'user_deactivated', actor_username=actor.username, target_username=str(row['username']))
    db.commit()
    return UserAdminOut(id=int(row['id']), username=str(row['username']), email=str(row['email']), role=str(role_name), is_active=bool(row['is_active']), failed_attempts=int(row['failed_attempts'] or 0), locked_until=row['locked_until'], last_login_at=row['last_login_at'], force_password_change=bool(row['force_password_change']), mfa_enabled=bool(row['mfa_enabled']))


def get_user_well_access(db: Session, username: str) -> list[str]:
    rows = db.execute(text('SELECT uwa.well_name FROM user_well_access uwa JOIN users u ON u.id = uwa.user_id WHERE lower(u.username)=:username ORDER BY uwa.well_name ASC'), {'username': username.strip().lower()}).mappings().all()
    return [str(r['well_name']) for r in rows]


def set_user_well_access(db: Session, actor: AuthUser, username: str, wells: list[str]) -> list[str]:
    uid = db.execute(text('SELECT id FROM users WHERE lower(username)=:username'), {'username': username.strip().lower()}).scalar_one_or_none()
    if uid is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    db.execute(text('DELETE FROM user_well_access WHERE user_id=:uid'), {'uid': int(uid)})
    clean = sorted({w.strip() for w in wells if w.strip()})
    for well in clean:
        db.execute(text('INSERT INTO user_well_access(user_id, well_name) VALUES (:uid,:well)'), {'uid': int(uid), 'well': well})
    _audit_log(db, 'user_scope_changed', actor_username=actor.username, target_username=username.strip().lower(), metadata={'wells': clean})
    db.commit()
    return clean


def change_own_password(db: Session, user: AuthUser, payload: PasswordChangeRequest) -> None:
    row = db.execute(text('SELECT password_hash FROM users WHERE id=:uid'), {'uid': user.id}).mappings().first()
    if row is None or not check_password_hash(str(row['password_hash']), payload.current_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Current password invalid')
    validate_password_policy(payload.new_password)
    db.execute(text('UPDATE users SET password_hash=:ph, force_password_change=FALSE, updated_at=NOW() WHERE id=:uid'), {'ph': generate_password_hash(payload.new_password), 'uid': user.id})
    _audit_log(db, 'password_changed', actor_username=user.username, target_username=user.username)
    db.commit()


def issue_password_reset_token(db: Session, actor: AuthUser, username: str, ttl_minutes: int = 15) -> PasswordResetTokenOut:
    row = _find_user_by_username(db, username)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    raw_token = secrets.token_urlsafe(36)
    token_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes)
    db.execute(text('INSERT INTO password_reset_tokens(token_hash, user_id, expires_at, created_by) VALUES (:th,:uid,:exp,:cb)'), {'th': token_hash, 'uid': int(row['id']), 'exp': expires_at, 'cb': actor.id})
    _audit_log(db, 'password_reset_issued', actor_username=actor.username, target_username=str(row['username']), metadata={'ttl_minutes': ttl_minutes})
    db.commit()
    return PasswordResetTokenOut(token=raw_token, expiresAt=expires_at)


def consume_password_reset_token(db: Session, payload: PasswordResetConfirmRequest) -> None:
    validate_password_policy(payload.new_password)
    token_hash = hashlib.sha256(payload.token.encode('utf-8')).hexdigest()
    row = db.execute(text('SELECT token_hash, user_id, expires_at, used_at FROM password_reset_tokens WHERE token_hash=:th'), {'th': token_hash}).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid reset token')
    if row['used_at'] is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Reset token already used')
    expires_at = row['expires_at']
    if isinstance(expires_at, datetime) and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if isinstance(expires_at, datetime) and expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Reset token expired')

    db.execute(text('UPDATE users SET password_hash=:ph, force_password_change=FALSE, failed_attempts=0, locked_until=NULL, updated_at=NOW() WHERE id=:uid'), {'ph': generate_password_hash(payload.new_password), 'uid': int(row['user_id'])})
    db.execute(text('UPDATE password_reset_tokens SET used_at=NOW() WHERE token_hash=:th'), {'th': token_hash})
    db.execute(text('UPDATE auth_sessions SET revoked_at=NOW(), revoke_reason=:reason WHERE user_id=:uid AND revoked_at IS NULL'), {'reason': 'password_reset', 'uid': int(row['user_id'])})
    db.commit()


def list_active_sessions(db: Session, actor: AuthUser, username: str | None = None) -> list[SessionOut]:
    target = (username or actor.username).strip().lower()
    rows = db.execute(
        text('SELECT s.session_id, u.username, s.created_at, s.expires_at, s.revoked_at, s.revoke_reason FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE lower(u.username)=:username ORDER BY s.created_at DESC'),
        {'username': target},
    ).mappings().all()
    return [SessionOut(sessionId=str(r['session_id']), username=str(r['username']), createdAt=r['created_at'], expiresAt=r['expires_at'], revokedAt=r['revoked_at'], revokeReason=r['revoke_reason']) for r in rows]


def revoke_session(db: Session, actor: AuthUser, session_id: str, reason: str) -> None:
    db.execute(text('UPDATE auth_sessions SET revoked_at = NOW(), revoke_reason = :reason WHERE session_id = :sid AND revoked_at IS NULL'), {'reason': reason, 'sid': session_id})
    _audit_log(db, 'session_revoked', actor_username=actor.username, metadata={'session_id': session_id, 'reason': reason})
    db.commit()


def mfa_setup_secret(db: Session, user: AuthUser) -> MfaSetupOut:
    secret = _base32_secret()
    db.execute(text('UPDATE users SET mfa_secret=:secret, mfa_enabled=FALSE, updated_at=NOW() WHERE id=:uid'), {'secret': secret, 'uid': user.id})
    db.commit()
    uri = f"otpauth://totp/Atalaya:{user.username}?secret={secret}&issuer=Atalaya"
    return MfaSetupOut(secret=secret, otpauthUri=uri)


def mfa_enable(db: Session, user: AuthUser, otp_code: str) -> None:
    row = db.execute(text('SELECT mfa_secret FROM users WHERE id=:uid'), {'uid': user.id}).mappings().first()
    if row is None or not row['mfa_secret']:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='MFA setup required first')
    if not _verify_totp(str(row['mfa_secret']), otp_code.strip()):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid OTP code')
    db.execute(text('UPDATE users SET mfa_enabled=TRUE, updated_at=NOW() WHERE id=:uid'), {'uid': user.id})
    _audit_log(db, 'mfa_enabled', actor_username=user.username)
    db.commit()


def mfa_disable(db: Session, actor: AuthUser, username: str) -> None:
    db.execute(text('UPDATE users SET mfa_enabled=FALSE, mfa_secret=NULL, updated_at=NOW() WHERE lower(username)=:username'), {'username': username.strip().lower()})
    _audit_log(db, 'mfa_disabled', actor_username=actor.username, target_username=username.strip().lower())
    db.commit()
