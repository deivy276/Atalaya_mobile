from __future__ import annotations

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


def init_auth_db(db: Session) -> None:
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS permissions (
                id BIGSERIAL PRIMARY KEY,
                code TEXT UNIQUE NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS roles (
                id BIGSERIAL PRIMARY KEY,
                name TEXT UNIQUE NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS role_permissions (
                role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
                permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
                PRIMARY KEY (role_id, permission_id)
            )
            '''
        )
    )
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
                last_login_at TIMESTAMPTZ,
                failed_attempts INTEGER NOT NULL DEFAULT 0,
                locked_until TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS user_well_access (
                user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                well_name TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                PRIMARY KEY (user_id, well_name)
            )
            '''
        )
    )
    db.execute(
        text(
            '''
            CREATE TABLE IF NOT EXISTS auth_audit_log (
                id BIGSERIAL PRIMARY KEY,
                event_type TEXT NOT NULL,
                actor_username TEXT,
                target_username TEXT,
                metadata_json TEXT,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            '''
        )
    )

    _seed_rbac(db)
    _seed_bootstrap_admin(db)
    db.commit()


def _seed_rbac(db: Session) -> None:
    for permission in (
        'dashboard:read',
        'alerts:read',
        'control_panel:write',
        'users:manage',
    ):
        db.execute(text('INSERT INTO permissions(code) VALUES (:code) ON CONFLICT(code) DO NOTHING'), {'code': permission})

    roles = {
        'admin': ['dashboard:read', 'alerts:read', 'control_panel:write', 'users:manage'],
        'specialist': ['dashboard:read', 'alerts:read', 'control_panel:write'],
        'operator': ['dashboard:read', 'alerts:read'],
        'viewer': ['dashboard:read', 'alerts:read'],
    }

    for role_name, permissions in roles.items():
        db.execute(text('INSERT INTO roles(name) VALUES (:name) ON CONFLICT(name) DO NOTHING'), {'name': role_name})
        for permission in permissions:
            db.execute(
                text(
                    '''
                    INSERT INTO role_permissions(role_id, permission_id)
                    SELECT r.id, p.id
                    FROM roles r, permissions p
                    WHERE r.name = :role_name AND p.code = :permission_code
                    ON CONFLICT(role_id, permission_id) DO NOTHING
                    '''
                ),
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
            INSERT INTO users(username, email, password_hash, role_id, is_active)
            SELECT :username, :email, :password_hash, r.id, TRUE
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


def _audit_log(
    db: Session,
    event_type: str,
    actor_username: str | None = None,
    target_username: str | None = None,
    metadata_json: str | None = None,
) -> None:
    db.execute(
        text(
            '''
            INSERT INTO auth_audit_log (event_type, actor_username, target_username, metadata_json)
            VALUES (:event_type, :actor_username, :target_username, :metadata_json)
            '''
        ),
        {
            'event_type': event_type,
            'actor_username': actor_username,
            'target_username': target_username,
            'metadata_json': metadata_json,
        },
    )


def authenticate_user(db: Session, username: str, password: str) -> AuthUser | None:
    settings = get_settings()
    normalized = username.strip().lower()
    row = db.execute(
        text(
            '''
            SELECT u.id, u.username, u.password_hash, u.is_active, u.failed_attempts, u.locked_until, r.name AS role_name
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE lower(u.username) = :username
            '''
        ),
        {'username': normalized},
    ).mappings().first()

    if row is None or not bool(row['is_active']):
        _audit_log(db, event_type='login_failed', target_username=normalized)
        db.commit()
        return None

    now = datetime.now(tz=timezone.utc)
    locked_until = row['locked_until']
    if isinstance(locked_until, datetime) and locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=timezone.utc)
    if isinstance(locked_until, datetime) and locked_until > now:
        _audit_log(db, event_type='login_failed_locked', target_username=normalized)
        db.commit()
        return None

    if not check_password_hash(str(row['password_hash']), password):
        failed_attempts = int(row['failed_attempts'] or 0) + 1
        next_locked_until = None
        if failed_attempts >= settings.auth_login_max_attempts:
            next_locked_until = now + timedelta(minutes=settings.auth_login_lockout_minutes)
            failed_attempts = 0
        db.execute(
            text(
                '''
                UPDATE users
                SET failed_attempts = :failed_attempts,
                    locked_until = :locked_until,
                    updated_at = NOW()
                WHERE id = :user_id
                '''
            ),
            {
                'failed_attempts': failed_attempts,
                'locked_until': next_locked_until,
                'user_id': int(row['id']),
            },
        )
        _audit_log(db, event_type='login_failed', target_username=normalized)
        db.commit()
        return None

    db.execute(
        text(
            '''
            UPDATE users
            SET failed_attempts = 0,
                locked_until = NULL,
                last_login_at = NOW(),
                updated_at = NOW()
            WHERE id = :user_id
            '''
        ),
        {'user_id': int(row['id'])},
    )
    _audit_log(db, event_type='login_success', target_username=normalized)
    db.commit()
    return AuthUser(id=int(row['id']), username=str(row['username']), role=str(row['role_name']))


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
    if not user_id or not username:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session payload')

    row = db.execute(
        text(
            '''
            SELECT u.id, u.username, u.is_active, r.name AS role_name
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE u.id = :user_id AND lower(u.username) = :username
            '''
        ),
        {'user_id': user_id, 'username': username},
    ).mappings().first()

    if row is None or not bool(row['is_active']):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='User disabled or missing')

    return AuthUser(id=int(row['id']), username=str(row['username']), role=str(row['role_name']))


def require_authenticated_if_enabled(
    request: Request,
    db: Session = Depends(get_db),
) -> AuthUser | None:
    return _resolve_auth_if_enabled(request, db)


def require_roles_if_enabled(*allowed_roles: str):
    allowed = {role.strip().lower() for role in allowed_roles if role.strip()}

    def _dependency(
        request: Request,
        db: Session = Depends(get_db),
    ) -> AuthUser | None:
        user = _resolve_auth_if_enabled(request, db)
        if user is None:
            return None
        if user.role.lower() not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
        return user

    return _dependency


def create_session_cookie(response: Response, user: AuthUser) -> None:
    settings = get_settings()
    token = _serializer().dumps({'uid': user.id, 'u': user.username, 'r': user.role})
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


def record_logout(db: Session, user: AuthUser | None) -> None:
    _audit_log(db, event_type='logout', actor_username=user.username if user else None)
    db.commit()


def list_permissions(db: Session) -> list[PermissionOut]:
    rows = db.execute(text('SELECT code FROM permissions ORDER BY code ASC')).mappings().all()
    return [PermissionOut(code=str(row['code'])) for row in rows]


def list_roles(db: Session) -> list[RoleOut]:
    rows = db.execute(
        text(
            '''
            SELECT r.name AS role_name, p.code AS permission_code
            FROM roles r
            LEFT JOIN role_permissions rp ON rp.role_id = r.id
            LEFT JOIN permissions p ON p.id = rp.permission_id
            ORDER BY r.name ASC, p.code ASC
            '''
        )
    ).mappings().all()
    grouped: dict[str, list[str]] = {}
    for row in rows:
        name = str(row['role_name'])
        grouped.setdefault(name, [])
        if row['permission_code']:
            grouped[name].append(str(row['permission_code']))
    return [RoleOut(name=name, permissions=permissions) for name, permissions in grouped.items()]


def list_users(db: Session) -> list[UserAdminOut]:
    rows = db.execute(
        text(
            '''
            SELECT u.id, u.username, u.email, u.is_active, u.failed_attempts, u.locked_until, u.last_login_at, r.name AS role_name
            FROM users u
            JOIN roles r ON r.id = u.role_id
            ORDER BY lower(u.username) ASC
            '''
        )
    ).mappings().all()
    return [
        UserAdminOut(
            id=int(row['id']),
            username=str(row['username']),
            email=str(row['email']),
            role=str(row['role_name']),
            is_active=bool(row['is_active']),
            failed_attempts=int(row['failed_attempts'] or 0),
            locked_until=row['locked_until'],
            last_login_at=row['last_login_at'],
        )
        for row in rows
    ]


def create_user(db: Session, actor: AuthUser, payload: UserCreateRequest) -> UserAdminOut:
    validate_password_policy(payload.password)
    password_hash = generate_password_hash(payload.password)
    row = db.execute(
        text(
            '''
            INSERT INTO users(username, email, password_hash, role_id, is_active)
            SELECT :username, :email, :password_hash, r.id, TRUE
            FROM roles r
            WHERE r.name = :role
            RETURNING id, username, email, is_active, failed_attempts, locked_until, last_login_at
            '''
        ),
        {
            'username': payload.username.strip().lower(),
            'email': payload.email.strip().lower(),
            'password_hash': password_hash,
            'role': payload.role.lower(),
        },
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid role')
    _audit_log(db, event_type='user_created', actor_username=actor.username, target_username=str(row['username']))
    db.commit()
    return UserAdminOut(
        id=int(row['id']),
        username=str(row['username']),
        email=str(row['email']),
        role=payload.role.lower(),
        is_active=bool(row['is_active']),
        failed_attempts=int(row['failed_attempts'] or 0),
        locked_until=row['locked_until'],
        last_login_at=row['last_login_at'],
    )


def set_user_role(db: Session, actor: AuthUser, username: str, role: str) -> UserAdminOut:
    row = db.execute(
        text(
            '''
            UPDATE users u
            SET role_id = r.id, updated_at = NOW()
            FROM roles r
            WHERE lower(u.username) = :username AND r.name = :role
            RETURNING u.id, u.username, u.email, u.is_active, u.failed_attempts, u.locked_until, u.last_login_at
            '''
        ),
        {'username': username.strip().lower(), 'role': role.lower()},
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User or role not found')
    _audit_log(db, event_type='user_role_changed', actor_username=actor.username, target_username=str(row['username']))
    db.commit()
    return UserAdminOut(
        id=int(row['id']),
        username=str(row['username']),
        email=str(row['email']),
        role=role.lower(),
        is_active=bool(row['is_active']),
        failed_attempts=int(row['failed_attempts'] or 0),
        locked_until=row['locked_until'],
        last_login_at=row['last_login_at'],
    )


def set_user_activation(db: Session, actor: AuthUser, username: str, is_active: bool) -> UserAdminOut:
    role_row = db.execute(
        text(
            '''
            UPDATE users u
            SET is_active = :is_active, updated_at = NOW()
            WHERE lower(u.username) = :username
            RETURNING u.id, u.username, u.email, u.role_id, u.is_active, u.failed_attempts, u.locked_until, u.last_login_at
            '''
        ),
        {'username': username.strip().lower(), 'is_active': bool(is_active)},
    ).mappings().first()
    if role_row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    role_name = db.execute(text('SELECT name FROM roles WHERE id = :rid'), {'rid': int(role_row['role_id'])}).scalar_one()
    _audit_log(
        db,
        event_type='user_activated' if is_active else 'user_deactivated',
        actor_username=actor.username,
        target_username=str(role_row['username']),
    )
    db.commit()
    return UserAdminOut(
        id=int(role_row['id']),
        username=str(role_row['username']),
        email=str(role_row['email']),
        role=str(role_name),
        is_active=bool(role_row['is_active']),
        failed_attempts=int(role_row['failed_attempts'] or 0),
        locked_until=role_row['locked_until'],
        last_login_at=role_row['last_login_at'],
    )


def get_user_well_access(db: Session, username: str) -> list[str]:
    rows = db.execute(
        text(
            '''
            SELECT uwa.well_name
            FROM user_well_access uwa
            JOIN users u ON u.id = uwa.user_id
            WHERE lower(u.username) = :username
            ORDER BY uwa.well_name ASC
            '''
        ),
        {'username': username.strip().lower()},
    ).mappings().all()
    return [str(row['well_name']) for row in rows]


def set_user_well_access(db: Session, actor: AuthUser, username: str, wells: list[str]) -> list[str]:
    user_id = db.execute(
        text('SELECT id FROM users WHERE lower(username) = :username'),
        {'username': username.strip().lower()},
    ).scalar_one_or_none()
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    db.execute(text('DELETE FROM user_well_access WHERE user_id = :user_id'), {'user_id': int(user_id)})
    clean_wells = sorted({well.strip() for well in wells if well.strip()})
    for well_name in clean_wells:
        db.execute(
            text('INSERT INTO user_well_access(user_id, well_name) VALUES (:user_id, :well_name)'),
            {'user_id': int(user_id), 'well_name': well_name},
        )
    _audit_log(
        db,
        event_type='user_scope_changed',
        actor_username=actor.username,
        target_username=username.strip().lower(),
        metadata_json=str({'wells': clean_wells}),
    )
    db.commit()
    return clean_wells
