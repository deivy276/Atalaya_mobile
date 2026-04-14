from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    _backend_root = Path(__file__).resolve().parents[1]

    model_config = SettingsConfigDict(
        env_file=(
            str(_backend_root / '.env'),
            '.env',
        ),
        env_file_encoding='utf-8',
        extra='ignore',
    )

    app_name: str = 'Atalaya FastAPI'
    api_prefix: str = '/api/v1'
    cors_origins_raw: str = Field(default='*', alias='CORS_ORIGINS')
    max_request_size_bytes: int = Field(default=1048576, alias='MAX_REQUEST_SIZE_BYTES')
    enforce_https_in_prod: bool = Field(default=True, alias='ENFORCE_HTTPS_IN_PROD')
    rate_limit_auth_max_requests: int = Field(default=10, alias='RATE_LIMIT_AUTH_MAX_REQUESTS')
    rate_limit_auth_window_seconds: int = Field(default=60, alias='RATE_LIMIT_AUTH_WINDOW_SECONDS')
    rate_limit_sensitive_max_requests: int = Field(default=120, alias='RATE_LIMIT_SENSITIVE_MAX_REQUESTS')
    rate_limit_sensitive_window_seconds: int = Field(default=60, alias='RATE_LIMIT_SENSITIVE_WINDOW_SECONDS')

    db_host: str = Field(default='', alias='DB_HOST')
    db_port: int = Field(default=5432, alias='DB_PORT')
    db_name: str = Field(default='', alias='DB_NAME')
    db_user: str = Field(default='', alias='DB_USER')
    db_password: str = Field(default='', alias='DB_PASSWORD')
    db_sslmode: str = Field(default='require', alias='DB_SSLMODE')
    db_connect_timeout_seconds: int = Field(
        default=10,
        validation_alias=AliasChoices('DB_CONNECT_TIMEOUT_SECONDS', 'CONNECT_TIMEOUT_SECONDS'),
    )
    pool_size: int = Field(
        default=5,
        validation_alias=AliasChoices('POOL_SIZE', 'DB_POOL_SIZE'),
    )
    max_overflow: int = Field(
        default=10,
        validation_alias=AliasChoices('MAX_OVERFLOW', 'DB_MAX_OVERFLOW'),
    )
    pool_timeout_seconds: int = Field(
        default=30,
        validation_alias=AliasChoices('POOL_TIMEOUT', 'DB_POOL_TIMEOUT_SECONDS'),
    )
    pool_recycle_seconds: int = Field(
        default=300,
        validation_alias=AliasChoices('POOL_RECYCLE', 'DB_POOL_RECYCLE_SECONDS'),
    )
    statement_timeout_ms: int = Field(default=5000, alias='STATEMENT_TIMEOUT_MS')
    idle_in_transaction_session_timeout_ms: int = Field(default=15000, alias='IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS')
    db_retry_attempts: int = Field(default=2, alias='DB_RETRY_ATTEMPTS')
    db_retry_backoff_ms: int = Field(default=120, alias='DB_RETRY_BACKOFF_MS')

    dashboard_alert_limit: int = Field(default=25, alias='DASHBOARD_ALERT_LIMIT')
    stale_threshold_seconds: int = Field(default=10, alias='STALE_THRESHOLD_SECONDS')
    sample_slot_count: int = Field(default=8, alias='SAMPLE_SLOT_COUNT')

    dashboard_cache_ttl_seconds: int = Field(default=2, alias='DASHBOARD_CACHE_TTL_SECONDS')
    alerts_cache_ttl_seconds: int = Field(default=2, alias='ALERTS_CACHE_TTL_SECONDS')
    kp_state_cache_ttl_seconds: int = Field(default=10, alias='KP_STATE_CACHE_TTL_SECONDS')
    sample_tag_existence_cache_ttl_seconds: int = Field(default=120, alias='SAMPLE_TAG_EXISTENCE_CACHE_TTL_SECONDS')


    auth_enabled: bool = Field(default=False, alias='AUTH_ENABLED')
    auth_skip_db_init: bool = Field(default=False, alias='AUTH_SKIP_DB_INIT')
    app_env: str = Field(default='dev', alias='APP_ENV')
    auth_secret_key: str = Field(default='change-me-local-dev', alias='AUTH_SECRET_KEY')
    auth_secret_key_dev: str = Field(default='', alias='AUTH_SECRET_KEY_DEV')
    auth_secret_key_stage: str = Field(default='', alias='AUTH_SECRET_KEY_STAGE')
    auth_secret_key_prod: str = Field(default='', alias='AUTH_SECRET_KEY_PROD')
    auth_cookie_name: str = Field(default='atalaya_session', alias='AUTH_COOKIE_NAME')
    auth_cookie_secure: bool = Field(default=False, alias='AUTH_COOKIE_SECURE')
    auth_cookie_samesite: str = Field(default='lax', alias='AUTH_COOKIE_SAMESITE')
    auth_session_timeout_hours: int = Field(default=12, alias='AUTH_SESSION_TIMEOUT_HOURS')
    auth_password_min_length: int = Field(default=12, alias='AUTH_PASSWORD_MIN_LENGTH')
    auth_login_max_attempts: int = Field(default=5, alias='AUTH_LOGIN_MAX_ATTEMPTS')
    auth_login_lockout_minutes: int = Field(default=15, alias='AUTH_LOGIN_LOCKOUT_MINUTES')
    auth_banned_passwords_raw: str = Field(
        default='password,123456,123456789,qwerty,admin,letmein',
        alias='AUTH_BANNED_PASSWORDS',
    )
    bootstrap_admin_username: str = Field(default='admin', alias='BOOTSTRAP_ADMIN_USERNAME')
    bootstrap_admin_password: str = Field(default='', alias='BOOTSTRAP_ADMIN_PASSWORD')
    auth_db_init_max_retries: int = Field(default=3, alias='AUTH_DB_INIT_MAX_RETRIES')
    auth_db_init_retry_delay_seconds: float = Field(default=1.5, alias='AUTH_DB_INIT_RETRY_DELAY_SECONDS')

    latest_samples_summary_name: str = Field(
        default='public.atalaya_latest_samples_mv',
        alias='LATEST_SAMPLES_SUMMARY_NAME',
    )
    attachment_table_candidates_raw: str = Field(
        default='public.attachments,public.atalaya_attachments',
        alias='ATTACHMENT_TABLE_CANDIDATES',
    )
    allowed_attachment_hosts_raw: str = Field(default='', alias='ALLOWED_ATTACHMENT_HOSTS')

    @property
    def cors_origins(self) -> list[str]:
        raw = (self.cors_origins_raw or '*').strip()
        if raw == '*':
            return ['*']
        return [item.strip() for item in raw.split(',') if item.strip()]

    @property
    def attachment_table_candidates(self) -> list[str]:
        raw = self.attachment_table_candidates_raw or ''
        return [item.strip() for item in raw.split(',') if item.strip()]

    @property
    def allowed_attachment_hosts(self) -> list[str]:
        raw = self.allowed_attachment_hosts_raw or ''
        return [item.strip().lower() for item in raw.split(',') if item.strip()]

    @property
    def auth_cookie_samesite_normalized(self) -> str:
        normalized = (self.auth_cookie_samesite or 'lax').strip().lower()
        if normalized not in {'lax', 'strict'}:
            return 'lax'
        return normalized

    @property
    def auth_banned_passwords(self) -> set[str]:
        raw = self.auth_banned_passwords_raw or ''
        return {item.strip().lower() for item in raw.split(',') if item.strip()}

    @property
    def auth_effective_secret_key(self) -> str:
        env = (self.app_env or 'dev').strip().lower()
        per_env = {
            'dev': self.auth_secret_key_dev,
            'stage': self.auth_secret_key_stage,
            'prod': self.auth_secret_key_prod,
        }.get(env, '')
        return (per_env or self.auth_secret_key).strip()

    @property
    def database_config_error(self) -> str | None:
        missing = [
            name
            for name, value in (
                ('DB_HOST', self.db_host),
                ('DB_NAME', self.db_name),
                ('DB_USER', self.db_user),
                ('DB_PASSWORD', self.db_password),
            )
            if not str(value).strip()
        ]
        if missing:
            return f"Missing required DB env vars: {', '.join(missing)}"
        return None

    @property
    def sqlalchemy_database_url(self) -> str:
        return (
            'postgresql+psycopg://'
            f'{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}'
            f'?sslmode={self.db_sslmode}'
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
