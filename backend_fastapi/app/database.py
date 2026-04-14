from collections.abc import Generator
from time import sleep

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
    )
    return any(marker in message for marker in transient_markers)


def _timeout_options_sql() -> str:
    return (
        f"-c statement_timeout={max(0, int(settings.statement_timeout_ms))} "
        f"-c idle_in_transaction_session_timeout={max(0, int(settings.idle_in_transaction_session_timeout_ms))}"
    )


def _merge_connect_options(existing: str | None) -> str:
    base = (existing or '').strip()
    extra = _timeout_options_sql().strip()
    return f'{base} {extra}'.strip() if base else extra


def _connect_with_retry(dialect, cargs, cparams):
    attempts = max(1, int(settings.db_retry_attempts))
    backoff_seconds = max(0, int(settings.db_retry_backoff_ms)) / 1000.0
    connect_kwargs = dict(cparams)
    connect_kwargs.setdefault('connect_timeout', max(1, int(settings.db_connect_timeout_seconds)))
    connect_kwargs['options'] = _merge_connect_options(connect_kwargs.get('options'))
    for attempt in range(attempts):
        try:
            return dialect.dbapi.connect(*cargs, **connect_kwargs)
        except Exception as exc:
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
        pool_recycle=max(0, int(settings.pool_recycle_seconds)),
        pool_size=max(1, int(settings.pool_size)),
        max_overflow=max(0, int(settings.max_overflow)),
        pool_timeout=max(1, int(settings.pool_timeout_seconds)),
        connect_args={
            'connect_timeout': max(1, int(settings.db_connect_timeout_seconds)),
            'options': _timeout_options_sql(),
        },
        future=True,
    )

    @event.listens_for(_engine, 'do_connect')
    def _on_do_connect(dialect, conn_rec, cargs, cparams):
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
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
