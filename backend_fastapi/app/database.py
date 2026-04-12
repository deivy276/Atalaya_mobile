from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings


class BackendConfigurationError(RuntimeError):
    """Raised when backend DB configuration is incomplete."""


settings = get_settings()
_engine = None
_session_factory = None


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
        pool_recycle=300,
        pool_size=5,
        max_overflow=10,
        pool_timeout=30,
        future=True,
    )
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
