from time import perf_counter
import traceback
import json

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, SQLAlchemyError
from sqlalchemy.orm import Session

from .auth import (
    AuthUser,
    LoginRequest,
    UserActivationRequest,
    UserAdminOut,
    UserCreateRequest,
    PermissionOut,
    RoleOut,
    UserRoleUpdateRequest,
    UserWellAccessUpdateRequest,
    UserOut,
    authenticate_user,
    clear_session_cookie,
    create_user,
    create_session_cookie,
    get_user_well_access,
    init_auth_db,
    list_permissions,
    list_roles,
    list_users,
    record_logout,
    require_authenticated_if_enabled,
    require_roles_if_enabled,
    set_user_activation,
    set_user_well_access,
    set_user_role,
    validate_auth_runtime_security,
)
from .config import get_settings
from .database import BackendConfigurationError, get_db
from .repositories.atalaya_repository import AtalayaDataRepository
from .schemas import (
    AlertsListOut,
    AttachmentsResponseOut,
    DashboardCoreOut,
    DashboardOut,
    HealthDetailsResponse,
    HealthResponse,
    TrendResponseOut,
)

settings = get_settings()
app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.on_event('startup')
def startup_init_auth() -> None:
    validate_auth_runtime_security()
    from .database import _ensure_session_factory

    session = _ensure_session_factory()()
    try:
        init_auth_db(session)
    finally:
        session.close()


@app.middleware('http')
async def add_server_timing_header(request: Request, call_next):
    started_at = perf_counter()
    response = await call_next(request)
    elapsed_ms = (perf_counter() - started_at) * 1000.0
    response.headers['X-Process-Time-Ms'] = f'{elapsed_ms:.1f}'
    return response


@app.exception_handler(BackendConfigurationError)
async def backend_configuration_error_handler(
    request: Request,
    exc: BackendConfigurationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=503,
        content={
            'detail': str(exc),
            'path': request.url.path,
        },
    )


@app.exception_handler(OperationalError)
async def operational_error_handler(request: Request, exc: OperationalError) -> JSONResponse:
    print('[fastapi] OperationalError on', request.url.path)
    traceback.print_exc()
    return JSONResponse(
        status_code=503,
        content={
            'detail': (
                'Database connection failed. Verify DB_HOST, DB_NAME, DB_USER and '
                'DB_PASSWORD in backend_fastapi/.env, then restart FastAPI.'
            ),
            'path': request.url.path,
            'error': str(exc).splitlines()[0][:240],
        },
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_error_handler(request: Request, exc: SQLAlchemyError) -> JSONResponse:
    print('[fastapi] SQLAlchemyError on', request.url.path)
    traceback.print_exc()
    return JSONResponse(
        status_code=500,
        content={
            'detail': 'Database query failed. Check the FastAPI terminal for the exact SQL error.',
            'path': request.url.path,
            'error': str(exc).splitlines()[0][:240],
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    print('[fastapi] Unhandled exception on', request.url.path)
    traceback.print_exc()
    return JSONResponse(
        status_code=500,
        content={
            'detail': 'Unexpected server error. The backend printed the traceback in the terminal.',
            'path': request.url.path,
            'error': str(exc)[:240],
            'type': exc.__class__.__name__,
        },
    )


def get_repository(db: Session = Depends(get_db)) -> AtalayaDataRepository:
    return AtalayaDataRepository(db)


@app.get('/health', response_model=HealthResponse)
def health(_: AuthUser | None = Depends(require_authenticated_if_enabled)) -> HealthResponse:
    return HealthResponse(status='ok')


@app.get('/health/db')
def health_db(
    db: Session = Depends(get_db),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> dict[str, str]:
    db.execute(text('SELECT 1'))
    return {'status': 'ok'}


@app.get('/health/details', response_model=HealthDetailsResponse)
def health_details(
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> HealthDetailsResponse:
    db_status = 'ok'
    latest_sample_at = None
    latest_sample_age_seconds = None
    latest_sample_source = 'UNKNOWN'
    status = 'ok'
    try:
        repository.db.execute(text('SELECT 1'))
        latest_sample_at, latest_sample_age_seconds, latest_sample_source = repository.fetch_latest_sample_info()
    except SQLAlchemyError:
        db_status = 'error'
        status = 'degraded'
    return HealthDetailsResponse(
        status=status,
        dbStatus=db_status,
        staleThresholdSeconds=settings.stale_threshold_seconds,
        latestSampleAt=latest_sample_at,
        latestSampleAgeSeconds=latest_sample_age_seconds,
        latestSampleSource=latest_sample_source,
    )


@app.get(f'{settings.api_prefix}/dashboard', response_model=DashboardCoreOut)
def get_dashboard(
    response: Response,
    fresh: bool = Query(False, description='Bypass the in-memory dashboard cache for benchmarking.'),
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> DashboardCoreOut:
    started_at = perf_counter()
    payload = repository.fetch_dashboard(fresh=fresh)
    configured_variables = sum(1 for item in payload.variables if item.configured)
    print(
        '[dashboard] '
        + json.dumps(
            {
                'path': '/api/v1/dashboard',
                'elapsed_ms': round((perf_counter() - started_at) * 1000.0, 1),
                'configured_variables': configured_variables,
                'latest_sample_age_seconds': payload.latestSampleAgeSeconds,
                'cache_status': repository.last_dashboard_cache_status,
                'kp_cache_status': repository.last_kp_cache_status,
                'samples_source': repository.last_samples_source,
            }
        )
    )
    response.headers['X-Cache-Status'] = repository.last_dashboard_cache_status
    response.headers['X-KP-Cache-Status'] = repository.last_kp_cache_status
    response.headers['X-Samples-Source'] = repository.last_samples_source
    return payload


@app.get(f'{settings.api_prefix}/dashboard/full', response_model=DashboardOut)
def get_dashboard_full(
    response: Response,
    fresh: bool = Query(False, description='Bypass the in-memory dashboard cache for benchmarking.'),
    alerts_fresh: bool = Query(False, description='Bypass alerts cache too.'),
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> DashboardOut:
    started_at = perf_counter()
    payload = repository.fetch_dashboard_full(fresh=fresh, alerts_fresh=alerts_fresh)
    configured_variables = sum(1 for item in payload.variables if item.configured)
    print(
        '[dashboard] '
        + json.dumps(
            {
                'path': '/api/v1/dashboard/full',
                'elapsed_ms': round((perf_counter() - started_at) * 1000.0, 1),
                'configured_variables': configured_variables,
                'latest_sample_age_seconds': payload.latestSampleAgeSeconds,
                'cache_status': repository.last_dashboard_cache_status,
                'kp_cache_status': repository.last_kp_cache_status,
                'samples_source': repository.last_samples_source,
                'alerts_cache_status': repository.last_alerts_cache_status,
            }
        )
    )
    response.headers['X-Cache-Status'] = repository.last_dashboard_cache_status
    response.headers['X-KP-Cache-Status'] = repository.last_kp_cache_status
    response.headers['X-Samples-Source'] = repository.last_samples_source
    response.headers['X-Alerts-Cache-Status'] = repository.last_alerts_cache_status
    response.headers['X-Alerts-Source'] = repository.last_alerts_source
    response.headers['X-Alerts-Text-Repairs'] = str(repository.last_alerts_text_repairs)
    return payload


@app.get(f'{settings.api_prefix}/alerts', response_model=AlertsListOut)
def get_alerts(
    response: Response,
    limit: int = Query(settings.dashboard_alert_limit, ge=1, le=200),
    fresh: bool = Query(False, description='Bypass the in-memory alerts cache for benchmarking.'),
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> AlertsListOut:
    payload = repository.fetch_alerts_list(limit=limit, fresh=fresh)
    response.headers['X-Alerts-Cache-Status'] = repository.last_alerts_cache_status
    response.headers['X-Alerts-Source'] = repository.last_alerts_source
    response.headers['X-Alerts-Text-Repairs'] = str(repository.last_alerts_text_repairs)
    return payload


@app.get(f'{settings.api_prefix}/trends', response_model=TrendResponseOut)
def get_trends(
    tag: str = Query(..., min_length=1),
    range_value: str = Query('2h', alias='range', pattern='^(30m|2h|6h)$'),
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> TrendResponseOut:
    return repository.fetch_trend(tag=tag, range_value=range_value)


@app.get(f'{settings.api_prefix}/alerts/{{alert_id}}/attachments', response_model=AttachmentsResponseOut)
def get_alert_attachments(
    alert_id: str,
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_authenticated_if_enabled),
) -> AttachmentsResponseOut:
    return repository.fetch_alert_attachments(alert_id=alert_id)


@app.get(f'{settings.api_prefix}/debug/slots')
def get_debug_slots(
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
):
    return repository.debug_slots()


@app.get(f'{settings.api_prefix}/debug/kp-state')
def get_debug_kp_state(
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
):
    return repository.debug_kp_state()


@app.get(f'{settings.api_prefix}/debug/sample-tags')
def get_debug_sample_tags(
    limit: int = Query(60, ge=1, le=200),
    repository: AtalayaDataRepository = Depends(get_repository),
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
):
    return repository.debug_sample_tags(limit=limit)


@app.post('/auth/login', response_model=UserOut)
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)) -> UserOut:
    user = authenticate_user(db, payload.username, payload.password)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid credentials')
    create_session_cookie(response, user)
    return UserOut(username=user.username, role=user.role)


@app.post('/auth/logout')
def logout(
    response: Response,
    user: AuthUser | None = Depends(require_authenticated_if_enabled),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    clear_session_cookie(response)
    record_logout(db, user)
    return {'status': 'ok'}


@app.get('/auth/me', response_model=UserOut)
def me(user: AuthUser | None = Depends(require_authenticated_if_enabled)) -> UserOut:
    if user is None:
        return UserOut(username='anonymous', role='operator')
    return UserOut(username=user.username, role=user.role)


@app.get('/auth/users', response_model=list[UserAdminOut])
def auth_users(
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> list[UserAdminOut]:
    return list_users(db)


@app.post('/auth/users', response_model=UserAdminOut, status_code=status.HTTP_201_CREATED)
def auth_create_user(
    payload: UserCreateRequest,
    actor: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> UserAdminOut:
    if actor is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
    return create_user(db, actor, payload)


@app.patch('/auth/users/{username}/role', response_model=UserAdminOut)
def auth_update_role(
    username: str,
    payload: UserRoleUpdateRequest,
    actor: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> UserAdminOut:
    if actor is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
    return set_user_role(db, actor, username, payload.role)


@app.patch('/auth/users/{username}/activation', response_model=UserAdminOut)
def auth_update_activation(
    username: str,
    payload: UserActivationRequest,
    actor: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> UserAdminOut:
    if actor is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
    return set_user_activation(db, actor, username, payload.is_active)


@app.get('/auth/permissions', response_model=list[PermissionOut])
def auth_permissions(
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> list[PermissionOut]:
    return list_permissions(db)


@app.get('/auth/roles', response_model=list[RoleOut])
def auth_roles(
    _: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> list[RoleOut]:
    return list_roles(db)


@app.get('/auth/users/{username}/well-access', response_model=list[str])
def auth_get_user_well_access(
    username: str,
    _: AuthUser | None = Depends(require_roles_if_enabled('admin', 'specialist')),
    db: Session = Depends(get_db),
) -> list[str]:
    return get_user_well_access(db, username)


@app.put('/auth/users/{username}/well-access', response_model=list[str])
def auth_set_user_well_access(
    username: str,
    payload: UserWellAccessUpdateRequest,
    actor: AuthUser | None = Depends(require_roles_if_enabled('admin')),
    db: Session = Depends(get_db),
) -> list[str]:
    if actor is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
    return set_user_well_access(db, actor, username, payload.wells)
