from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file='backend_fastapi/.env',
        env_file_encoding='utf-8',
        extra='ignore',
    )

    app_name: str = 'Atalaya FastAPI'
    api_prefix: str = '/api/v1'
    cors_origins_raw: str = Field(default='*', alias='CORS_ORIGINS')

    db_host: str = Field(default='', alias='DB_HOST')
    db_port: int = Field(default=5432, alias='DB_PORT')
    db_name: str = Field(default='', alias='DB_NAME')
    db_user: str = Field(default='', alias='DB_USER')
    db_password: str = Field(default='', alias='DB_PASSWORD')
    db_sslmode: str = Field(default='require', alias='DB_SSLMODE')

    dashboard_alert_limit: int = Field(default=25, alias='DASHBOARD_ALERT_LIMIT')
    stale_threshold_seconds: int = Field(default=10, alias='STALE_THRESHOLD_SECONDS')
    sample_slot_count: int = Field(default=8, alias='SAMPLE_SLOT_COUNT')

    dashboard_cache_ttl_seconds: int = Field(default=2, alias='DASHBOARD_CACHE_TTL_SECONDS')
    alerts_cache_ttl_seconds: int = Field(default=2, alias='ALERTS_CACHE_TTL_SECONDS')
    kp_state_cache_ttl_seconds: int = Field(default=10, alias='KP_STATE_CACHE_TTL_SECONDS')
    sample_tag_existence_cache_ttl_seconds: int = Field(default=120, alias='SAMPLE_TAG_EXISTENCE_CACHE_TTL_SECONDS')

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
