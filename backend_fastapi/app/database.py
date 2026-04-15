from collections.abc import Generator
from time import sleep
from typing import Any

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings


class BackendConfigurationError(RuntimeError):
    """Raised when backend DB configuration is incomplete."""


settings = get_settings()
_engine = None
_session_factory = None


def _is_transient_operational_error(exc: Exception) -> bool:
    message = str(exc).lower()
    transient_markers = (
        'could not connect',
        'connection refused',
        'server closed the connection unexpectedly',
        'connection reset by peer',
        'connection not open',
        'timeout expired',
        'timed out',
        'temporary failure',
        'name or service not known',
        'failed to resolve host',
        'could not translate host name',
        'network is unreachable',
        'connection timed out',
    )
    return any(marker in message for marker in transient_markers)


def _timeout_options_sql() -> str:
    return (
        f"-c statement_timeout={max(0, int(settings.statement_timeout_ms))} "
        f"-c idle_in_transaction_session_timeout={max(0, int(settings.idle_in_transaction_session_timeout_ms))}"
    )


def _merge_connect_options(existing: str | None) -> str:
    base = (existing or '').strip()
    parts: list[str] = []
    if base:
        parts.append(base)
    if 'statement_timeout=' not in base:
        parts.append(f"-c statement_timeout={max(0, int(settings.statement_timeout_ms))}")
    if 'idle_in_transaction_session_timeout=' not in base:
        parts.append(
            f"-c idle_in_transaction_session_timeout={max(0, int(settings.idle_in_transaction_session_timeout_ms))}"
        )
    return ' '.join(part for part in parts if part).strip()


def _connect_with_retry(dialect: Any, cargs: tuple[Any, ...], cparams: dict[str, Any]):
    attempts = max(1, int(settings.db_retry_attempts))
    backoff_seconds = max(0, int(settings.db_retry_backoff_ms)) / 1000.0
    connect_kwargs = dict(cparams)
    connect_kwargs.setdefault('connect_timeout', max(1, int(settings.db_connect_timeout_seconds)))
    connect_kwargs['options'] = _merge_connect_options(connect_kwargs.get('options'))
    for attempt in range(attempts):
        try:
            return dialect.dbapi.connect(*cargs, **connect_kwargs)
        except Exception as exc:
            operational_error_type = getattr(dialect.dbapi, 'OperationalError', None)
            if operational_error_type is None or not isinstance(exc, operational_error_type):
                raise
            if not _is_transient_operational_error(exc) or attempt == attempts - 1:
                raise
            sleep(backoff_seconds * (2**attempt))


def _ensure_session_factory():
    global _engine, _session_factory

    if _session_factory is not None:
        return _session_factory

    config_error = settings.database_config_error
    if config_error:
        raise BackendConfigurationError(config_error)

    _engine = create_engine(
        settings.sqlalchemy_database_url,
        pool_pre_ping=True,
        pool_recycle=settings.db_pool_recycle_seconds,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_timeout=settings.db_pool_timeout_seconds,
        future=True,
    )

    @event.listens_for(_engine, 'do_connect')
    def _on_do_connect(dialect: Any, _conn_rec: Any, cargs: tuple[Any, ...], cparams: dict[str, Any]):
        return _connect_with_retry(dialect, cargs, cparams)

    _session_factory = sessionmaker(
        bind=_engine,
        autoflush=False,
        autocommit=False,
        future=True,
    )
    return _session_factory


def get_db() -> Generator[Session, None, None]:
    session_factory = _ensure_session_factory()
    db: Session | None = None
    attempts = max(1, int(settings.db_retry_attempts))
    backoff_seconds = max(0, int(settings.db_retry_backoff_ms)) / 1000.0
    for attempt in range(attempts):
        candidate = session_factory()
        try:
            candidate.connection()
            db = candidate
            break
        except OperationalError as exc:
            candidate.close()
            if not _is_transient_operational_error(exc) or attempt == attempts - 1:
                raise
            sleep(backoff_seconds * (2**attempt))
    if db is None:
        raise RuntimeError('Failed to initialize DB session.')
    try:
        yield db
    finally:
        db.close()
