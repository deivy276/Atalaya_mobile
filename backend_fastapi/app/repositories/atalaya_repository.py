from __future__ import annotations

import copy
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import html
import re
import unicodedata
from threading import Lock
from time import monotonic
from typing import Any
from urllib.parse import urlparse

from sqlalchemy import bindparam, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..schemas import (
    AttachmentOut,
    AlertOut,
    AlertsListOut,
    AttachmentsResponseOut,
    DashboardCoreOut,
    DashboardOut,
    TrendPointOut,
    TrendResponseOut,
    WellVariableOut,
)

settings = get_settings()


@dataclass(frozen=True)
class AttachmentMeta:
    schema: str
    table: str
    fk: str
    id_col: str | None = None
    name_col: str | None = None
    url_col: str | None = None
    mime_col: str | None = None
    size_col: str | None = None
    created_at_col: str | None = None


@dataclass(frozen=True)
class AlertTableMeta:
    schema: str
    table: str
    id_col: str | None = None
    description_col: str | None = None
    severity_col: str | None = None
    created_at_col: str | None = None


@dataclass(frozen=True)
class SampleTableMeta:
    schema: str
    table: str
    tag_col: str | None = None
    value_col: str | None = None
    created_at_col: str | None = None
    id_col: str | None = None


@dataclass(frozen=True)
class LatestSamplesSummaryMeta:
    schema: str
    table: str
    tag_norm_col: str
    actual_tag_col: str
    value_col: str
    created_at_col: str


@dataclass(frozen=True)
class AlertsSummaryMeta:
    schema: str
    table: str
    alert_id_text_col: str
    raw_id_text_col: str
    description_col: str
    severity_col: str
    created_at_col: str


class AtalayaDataRepository:
    _attachment_detection_done = False
    _attachment_meta_cache: AttachmentMeta | None = None
    _alert_detection_done = False
    _alert_meta_cache: AlertTableMeta | None = None
    _sample_detection_done = False
    _sample_meta_cache: SampleTableMeta | None = None
    _latest_samples_summary_detection_done = False
    _latest_samples_summary_meta_cache: LatestSamplesSummaryMeta | None = None
    _alerts_summary_detection_done = False
    _alerts_summary_meta_cache: AlertsSummaryMeta | None = None

    _dashboard_cache_lock = Lock()
    _dashboard_cache_value: DashboardCoreOut | None = None
    _dashboard_cache_expires_at: float = 0.0

    _alerts_cache_lock = Lock()
    _alerts_cache_value: AlertsListOut | None = None
    _alerts_cache_expires_at: float = 0.0

    _kp_cache_lock = Lock()
    _kp_cache_value: dict[str, Any] | None = None
    _kp_cache_expires_at: float = 0.0

    _sample_exists_cache_lock = Lock()
    _sample_exists_cache: dict[str, tuple[bool, float]] = {}

    def __init__(self, db: Session) -> None:
        self.db = db
        self.last_dashboard_cache_status = 'MISS'
        self.last_alerts_cache_status = 'MISS'
        self.last_alerts_source = 'BASE_TABLE'
        self.last_alerts_text_repairs = 0
        self.last_kp_cache_status = 'MISS'
        self.last_samples_source = 'BASE_TABLE'
        self.last_samples_missing_tags = 0
        self.last_samples_missing_ratio = 0.0
        self.last_samples_resolution_ms = 0.0
        self.last_samples_fallback_used = False
        self.last_samples_fallback_blocked = False

    def fetch_dashboard(self, *, fresh: bool = False) -> DashboardCoreOut:
        now = monotonic()
        if not fresh and settings.dashboard_cache_ttl_seconds > 0:
            with self.__class__._dashboard_cache_lock:
                cached = self.__class__._dashboard_cache_value
                expires_at = self.__class__._dashboard_cache_expires_at
                if cached is not None and now < expires_at:
                    self.last_dashboard_cache_status = 'HIT'
                    self.last_kp_cache_status = 'SKIP'
                    self.last_samples_source = 'CACHE'
                    self.last_samples_missing_tags = 0
                    self.last_samples_missing_ratio = 0.0
                    self.last_samples_resolution_ms = 0.0
                    self.last_samples_fallback_used = False
                    self.last_samples_fallback_blocked = False
                    return copy.deepcopy(cached)

        self.last_dashboard_cache_status = 'MISS'
        payload = self._build_dashboard_core(force_kp_fresh=fresh)

        if settings.dashboard_cache_ttl_seconds > 0:
            with self.__class__._dashboard_cache_lock:
                self.__class__._dashboard_cache_value = copy.deepcopy(payload)
                self.__class__._dashboard_cache_expires_at = monotonic() + float(settings.dashboard_cache_ttl_seconds)

        return payload

    def fetch_alerts_list(self, *, limit: int | None = None, fresh: bool = False) -> AlertsListOut:
        limit_value = int(limit or settings.dashboard_alert_limit)
        now = monotonic()
        if not fresh and settings.alerts_cache_ttl_seconds > 0:
            with self.__class__._alerts_cache_lock:
                cached = self.__class__._alerts_cache_value
                expires_at = self.__class__._alerts_cache_expires_at
                if cached is not None and now < expires_at and int(cached.limit) == limit_value:
                    self.last_alerts_cache_status = 'HIT'
                    self.last_alerts_source = 'CACHE'
                    self.last_alerts_text_repairs = 0
                    return copy.deepcopy(cached)

        self.last_alerts_cache_status = 'MISS'
        alerts = self._fetch_alerts(limit=limit_value)
        latest_alert_at = max((item.createdAt for item in alerts), default=None)
        payload = AlertsListOut(
            latestAlertAt=latest_alert_at,
            limit=limit_value,
            alerts=alerts,
        )

        if settings.alerts_cache_ttl_seconds > 0:
            with self.__class__._alerts_cache_lock:
                self.__class__._alerts_cache_value = copy.deepcopy(payload)
                self.__class__._alerts_cache_expires_at = monotonic() + float(settings.alerts_cache_ttl_seconds)

        return payload

    def fetch_dashboard_full(self, *, fresh: bool = False, alerts_fresh: bool = False) -> DashboardOut:
        core = self.fetch_dashboard(fresh=fresh)
        alerts_payload = self.fetch_alerts_list(limit=settings.dashboard_alert_limit, fresh=alerts_fresh or fresh)
        return DashboardOut(
            well=core.well,
            job=core.job,
            latestSampleAt=core.latestSampleAt,
            latestSampleAgeSeconds=core.latestSampleAgeSeconds,
            staleThresholdSeconds=core.staleThresholdSeconds,
            variables=core.variables,
            alerts=alerts_payload.alerts,
        )

    def _build_dashboard_core(self, *, force_kp_fresh: bool = False) -> DashboardCoreOut:
        try:
            kp_map = self._fetch_kp_state_cached(force_fresh=force_kp_fresh)
        except SQLAlchemyError:
            kp_map = {}

        well = str(kp_map.get('CURRENT_WELL', '---'))
        job = str(kp_map.get('CURRENT_JOB', '---'))

        slot_configs = self._configured_slots(kp_map, validate_candidates=False)
        latest_samples = self._fetch_latest_samples_by_tag(
            [str(slot['tag']) for slot in slot_configs if slot['tag']]
        )

        variables: list[WellVariableOut] = []
        for slot_config in slot_configs:
            slot = int(slot_config['slot'])
            tag = str(slot_config['tag'] or '')
            raw_unit = str(slot_config['raw_unit'] or '')
            configured_label = str(slot_config.get('label') or '').strip()

            if not tag:
                variables.append(
                    WellVariableOut(
                        slot=slot,
                        label=configured_label or f'VAR {slot}',
                        tag='',
                        rawUnit=raw_unit,
                        value=None,
                        sampleAt=None,
                        configured=False,
                    )
                )
                continue

            normalized_tag = self._norm_tag(tag)
            normalized_match = self._norm_tag_match(tag)
            sample_row = latest_samples.get(normalized_match) or latest_samples.get(normalized_tag)
            value = self._coerce_sample_value(sample_row.get('value')) if sample_row else None
            sample_at = sample_row.get('created_at') if sample_row else None
            if not isinstance(sample_at, datetime):
                sample_at = None

            variables.append(
                WellVariableOut(
                    slot=slot,
                    label=configured_label or self._humanize_label(normalized_tag),
                    tag=tag,
                    rawUnit=raw_unit,
                    value=value,
                    sampleAt=sample_at,
                    configured=True,
                )
            )

        latest_sample_at = max(
            (item.sampleAt for item in variables if item.sampleAt is not None),
            default=None,
        )
        latest_sample_age_seconds = self._compute_age_seconds(latest_sample_at)

        return DashboardCoreOut(
            well=well,
            job=job,
            latestSampleAt=latest_sample_at,
            latestSampleAgeSeconds=latest_sample_age_seconds,
            staleThresholdSeconds=settings.stale_threshold_seconds,
            variables=variables,
        )

    def fetch_latest_sample_info(self) -> tuple[datetime | None, int | None, str]:
        latest_sample_at: datetime | None = None
        source = 'NONE'

        summary_meta = self._latest_samples_summary_meta()
        if summary_meta is not None:
            row = self.db.execute(
                text(
                    f"""
                    SELECT MAX({self._qid(summary_meta.created_at_col)}) AS latest_sample_at
                    FROM {self._qtable(summary_meta.schema, summary_meta.table)}
                    """
                )
            ).mappings().first()
            candidate = row.get('latest_sample_at') if row else None
            if isinstance(candidate, datetime):
                latest_sample_at = candidate
                source = 'MATVIEW'

        if latest_sample_at is None:
            sample_meta = self._sample_table_meta()
            if sample_meta is not None and sample_meta.created_at_col is not None:
                row = self.db.execute(
                    text(
                        f"""
                        SELECT MAX({self._qid(sample_meta.created_at_col)}) AS latest_sample_at
                        FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                        """
                    )
                ).mappings().first()
                candidate = row.get('latest_sample_at') if row else None
                if isinstance(candidate, datetime):
                    latest_sample_at = candidate
                    source = 'BASE_TABLE'

        return latest_sample_at, self._compute_age_seconds(latest_sample_at), source

    @staticmethod
    def _compute_age_seconds(sample_at: datetime | None) -> int | None:
        if sample_at is None:
            return None
        now = datetime.now(tz=sample_at.tzinfo) if sample_at.tzinfo else datetime.now(timezone.utc).replace(tzinfo=None)
        age_seconds = int((now - sample_at).total_seconds())
        return max(age_seconds, 0)

    def fetch_trend(self, tag: str, range_value: str) -> TrendResponseOut:
        normalized_tag = self._norm_tag(tag)
        normalized_match = self._norm_tag_match(tag)
        if not normalized_tag:
            return TrendResponseOut(tag=tag, rawUnit='', points=[])

        sample_meta = self._sample_table_meta()
        if sample_meta is None or sample_meta.tag_col is None or sample_meta.value_col is None or sample_meta.created_at_col is None:
            kp_map = self._fetch_kp_state_cached()
            raw_unit = self._raw_unit_for_tag(kp_map, normalized_tag)
            return TrendResponseOut(tag=tag, rawUnit=raw_unit, points=[])

        interval_sql = {
            '30m': '30 minutes',
            '2h': '2 hours',
            '6h': '6 hours',
        }.get(range_value, '2 hours')

        kp_map = self._fetch_kp_state_cached()
        raw_unit = self._raw_unit_for_tag(kp_map, normalized_tag)

        tag_sql = self._qid(sample_meta.tag_col)
        value_sql = self._qid(sample_meta.value_col)
        created_sql = self._qid(sample_meta.created_at_col)
        order_sql = self._order_suffix(sample_meta.created_at_col, sample_meta.id_col, ascending=True)

        exact_variants = self._exact_tag_variants(tag)
        rows = self.db.execute(
            text(
                f"""
                SELECT {created_sql} AS created_at,
                       {value_sql} AS value
                FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                WHERE {tag_sql} IN :exact_tags
                  AND {created_sql} >= NOW() - INTERVAL '{interval_sql}'
                {order_sql}
                """
            ).bindparams(bindparam('exact_tags', expanding=True)),
            {'exact_tags': exact_variants},
        ).mappings().all()

        if not rows:
            rows = self.db.execute(
                text(
                    f"""
                    SELECT {created_sql} AS created_at,
                           {value_sql} AS value
                    FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                    WHERE LOWER(TRIM(TRAILING '.' FROM {tag_sql})) = :tag
                      AND {created_sql} >= NOW() - INTERVAL '{interval_sql}'
                    {order_sql}
                    """
                ),
                {'tag': normalized_match},
            ).mappings().all()

        points: list[TrendPointOut] = []
        for row in rows:
            value = self._as_float(row.get('value'))
            if value is None:
                continue
            created_at = row.get('created_at')
            if not isinstance(created_at, datetime):
                continue
            points.append(TrendPointOut(timestamp=created_at, value=value))

        return TrendResponseOut(tag=tag, rawUnit=raw_unit, points=points)

    def fetch_alert_attachments(self, alert_id: str) -> AttachmentsResponseOut:
        meta = self._attachment_meta()
        if meta is None:
            return AttachmentsResponseOut(attachments=[])

        id_col = f"{self._qid(meta.id_col)}::text AS id" if meta.id_col else "''::text AS id"
        name_col = f"COALESCE({self._qid(meta.name_col)}, '') AS name" if meta.name_col else "''::text AS name"
        url_col = f"COALESCE({self._qid(meta.url_col)}, '') AS url" if meta.url_col else "''::text AS url"
        mime_col = f"COALESCE({self._qid(meta.mime_col)}, '') AS mime_type" if meta.mime_col else "''::text AS mime_type"
        size_col = f"{self._qid(meta.size_col)} AS size_bytes" if meta.size_col else 'NULL::bigint AS size_bytes'
        created_col = (
            f"{self._qid(meta.created_at_col)} AS created_at" if meta.created_at_col else 'NULL::timestamptz AS created_at'
        )
        order_col = self._qid(meta.created_at_col or meta.id_col or meta.fk)

        rows = self.db.execute(
            text(
                f"""
                SELECT {id_col}, {name_col}, {url_col}, {mime_col}, {size_col}, {created_col}
                FROM {self._qtable(meta.schema, meta.table)}
                WHERE {self._qid(meta.fk)}::text = :alert_id
                ORDER BY {order_col} DESC
                LIMIT 50
                """
            ),
            {'alert_id': str(alert_id)},
        ).mappings().all()

        attachments: list[AttachmentOut] = []
        for row in rows:
            raw_url = str(row.get('url') or '')
            safe_url = raw_url if self._is_allowed_attachment_url(raw_url) else ''
            attachment_id = str(row.get('id') or '')
            attachment_name, _ = self._clean_alert_text(row.get('name') or f'Attachment {attachment_id}'.strip())
            attachments.append(
                AttachmentOut(
                    id=attachment_id,
                    name=attachment_name or 'Attachment',
                    url=safe_url,
                    mimeType=str(row.get('mime_type') or ''),
                    sizeBytes=self._as_int(row.get('size_bytes')),
                    createdAt=row.get('created_at') if isinstance(row.get('created_at'), datetime) else None,
                )
            )

        return AttachmentsResponseOut(attachments=attachments)

    def debug_slots(self) -> dict[str, Any]:
        kp_map = self._fetch_kp_state_cached(force_fresh=True)
        slots = [
            self._resolve_slot_config(kp_map, slot, include_debug=True, validate_candidates=True)
            for slot in range(1, settings.sample_slot_count + 1)
        ]
        return {
            'well': str(kp_map.get('CURRENT_WELL', '---')),
            'job': str(kp_map.get('CURRENT_JOB', '---')),
            'slots': slots,
        }

    def debug_kp_state(self) -> dict[str, Any]:
        rows, columns = self._fetch_kp_state_rows_raw()
        interesting_rows: list[dict[str, Any]] = []
        duplicates: dict[str, list[str]] = defaultdict(list)
        for row in rows:
            key_raw = str(row.get('key') or '').strip()
            key_norm = self._norm_key(key_raw)
            value_raw = row.get('value')
            value_text = '' if value_raw is None else str(value_raw)
            preview = self._preview_value(value_text)
            if self._is_interesting_kp_key(key_norm) or self._looks_like_css_or_blob(value_text):
                interesting_rows.append(
                    {
                        'key': key_raw,
                        'keyNorm': key_norm,
                        'valuePreview': preview,
                        'looksLikeCssOrBlob': self._looks_like_css_or_blob(value_text),
                        'looksLikeTag': self._looks_like_tag(value_text),
                        'looksLikeUnit': bool(self._sanitize_raw_unit(value_text)),
                    }
                )
            duplicates[key_norm].append(preview)

        duplicate_rows = [
            {
                'keyNorm': key_norm,
                'count': len(values),
                'valuesPreview': values[:6],
            }
            for key_norm, values in duplicates.items()
            if len(values) > 1 and self._is_interesting_kp_key(key_norm)
        ]
        duplicate_rows.sort(key=lambda item: (-int(item['count']), str(item['keyNorm'])))
        interesting_rows.sort(key=lambda item: str(item['keyNorm']))
        return {
            'columns': columns,
            'rowCount': len(rows),
            'interestingRows': interesting_rows,
            'duplicates': duplicate_rows,
        }

    def debug_sample_tags(self, limit: int = 60) -> dict[str, Any]:
        sample_meta = self._sample_table_meta()
        if sample_meta is None or sample_meta.tag_col is None:
            return {'sampleTags': []}

        tag_sql = self._qid(sample_meta.tag_col)
        created_sql = self._qid(sample_meta.created_at_col) if sample_meta.created_at_col else None
        order_sql = self._order_suffix(sample_meta.created_at_col, sample_meta.id_col, ascending=False)
        rows = self.db.execute(
            text(
                f"""
                SELECT {tag_sql} AS tag,
                       {created_sql if created_sql else 'NULL::timestamptz'} AS created_at
                FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                {order_sql}
                LIMIT :limit
                """
            ),
            {'limit': max(100, int(limit) * 5)},
        ).mappings().all()

        out: list[dict[str, Any]] = []
        seen: set[str] = set()
        for row in rows:
            tag = str(row.get('tag') or '').strip()
            if not tag:
                continue
            tag_norm = self._norm_tag_match(tag)
            if not tag_norm or tag_norm in seen:
                continue
            seen.add(tag_norm)
            out.append(
                {
                    'tag': tag,
                    'tagNorm': tag_norm,
                    'latestAt': row.get('created_at') if isinstance(row.get('created_at'), datetime) else None,
                }
            )
            if len(out) >= int(limit):
                break

        return {'sampleTags': out}

    def _fetch_kp_state_cached(self, *, force_fresh: bool = False) -> dict[str, Any]:
        now = monotonic()
        if not force_fresh and settings.kp_state_cache_ttl_seconds > 0:
            with self.__class__._kp_cache_lock:
                cached = self.__class__._kp_cache_value
                expires_at = self.__class__._kp_cache_expires_at
                if cached is not None and now < expires_at:
                    self.last_kp_cache_status = 'HIT'
                    return copy.deepcopy(cached)

        self.last_kp_cache_status = 'MISS'
        fresh_value = self._fetch_kp_state()
        if settings.kp_state_cache_ttl_seconds > 0:
            with self.__class__._kp_cache_lock:
                self.__class__._kp_cache_value = copy.deepcopy(fresh_value)
                self.__class__._kp_cache_expires_at = monotonic() + float(settings.kp_state_cache_ttl_seconds)
        return fresh_value

    def _fetch_kp_state(self) -> dict[str, Any]:
        rows, columns = self._fetch_kp_state_rows_raw()
        out: dict[str, Any] = {}

        key_columns = {str(c).lower() for c in columns}
        preferred_order_columns = [c for c in ('updated_at', 'created_at', 'timestamp', 'ts', 'id') if c in key_columns]

        if preferred_order_columns:
            for row in rows:
                key_norm = self._norm_key(row.get('key'))
                if key_norm and key_norm not in out:
                    out[key_norm] = row.get('value')
            return out

        for row in rows:
            key_norm = self._norm_key(row.get('key'))
            if not key_norm:
                continue
            if key_norm in out:
                continue
            out[key_norm] = row.get('value')
        return out

    def _fetch_kp_state_rows_raw(self) -> tuple[list[dict[str, Any]], list[str]]:
        schema, table = 'public', 'kp_state'
        if not self._table_exists(schema, table):
            return [], []

        columns = self._get_columns(schema, table)
        if 'key' not in columns or 'value' not in columns:
            return [], columns

        select_cols = [f"{self._qid('key')} AS key", f"{self._qid('value')} AS value"]
        extra_cols = [c for c in ('updated_at', 'created_at', 'timestamp', 'ts', 'id') if c in columns]
        select_cols.extend(f"{self._qid(c)} AS {self._qid(c)}" for c in extra_cols)

        order_sql = ''
        if extra_cols:
            order_parts = ', '.join(f"{self._qid(c)} DESC" for c in extra_cols)
            order_sql = f"ORDER BY UPPER(BTRIM({self._qid('key')})), {order_parts}"
            query = f"SELECT DISTINCT ON (UPPER(BTRIM({self._qid('key')}))) {', '.join(select_cols)} FROM {self._qtable(schema, table)} WHERE {self._qid('key')} IS NOT NULL {order_sql}"
        else:
            query = f"SELECT {', '.join(select_cols)} FROM {self._qtable(schema, table)} WHERE {self._qid('key')} IS NOT NULL"

        rows = self.db.execute(text(query)).mappings().all()
        return [dict(row) for row in rows], columns

    def _configured_slots(self, kp_map: dict[str, Any], *, validate_candidates: bool) -> list[dict[str, Any]]:
        return [
            self._resolve_slot_config(kp_map, slot, include_debug=False, validate_candidates=validate_candidates)
            for slot in range(1, settings.sample_slot_count + 1)
        ]

    def _resolve_slot_config(
        self,
        kp_map: dict[str, Any],
        slot: int,
        include_debug: bool = False,
        validate_candidates: bool = False,
    ) -> dict[str, Any]:
        exact_explicit_keys = (
            f'VAR_{slot}_TAG',
            f'VARIABLE_{slot}_TAG',
            f'VAR_{slot}_SIGNAL',
            f'VARIABLE_{slot}_SIGNAL',
            f'VAR_{slot}_SIGNAL_TAG',
            f'VARIABLE_{slot}_SIGNAL_TAG',
            f'VAR_{slot}_POINT',
            f'VARIABLE_{slot}_POINT',
            f'VAR_{slot}_SOURCE',
            f'VARIABLE_{slot}_SOURCE',
            f'VAR_{slot}_SOURCE_TAG',
            f'VARIABLE_{slot}_SOURCE_TAG',
            f'VAR_{slot}_CHANNEL',
            f'VARIABLE_{slot}_CHANNEL',
            f'TAG_{slot}',
            f'SIGNAL_{slot}',
            f'POINT_{slot}',
        )
        generic_keys = (
            f'VAR_{slot}',
            f'VARIABLE_{slot}',
        )
        label_keys = (
            f'VAR_{slot}_LABEL',
            f'VARIABLE_{slot}_LABEL',
            f'VAR_{slot}_NAME',
            f'VARIABLE_{slot}_NAME',
            f'VAR_{slot}_DESC',
            f'VARIABLE_{slot}_DESC',
            f'VAR_{slot}_TEXT',
            f'VARIABLE_{slot}_TEXT',
        )

        explicit_candidates: list[tuple[str, str]] = []
        for key in exact_explicit_keys:
            value = kp_map.get(self._norm_key(key))
            candidate = self._sanitize_candidate(value)
            if candidate:
                explicit_candidates.append((self._norm_key(key), candidate))

        prefixes = (f'VAR_{slot}_', f'VARIABLE_{slot}_', f'SLOT_{slot}_')
        for raw_key, raw_value in kp_map.items():
            key = self._norm_key(raw_key)
            candidate = self._sanitize_candidate(raw_value)
            if not candidate:
                continue
            if (key.startswith(prefixes) or key in {f'TAG_{slot}', f'SIGNAL_{slot}', f'POINT_{slot}'}) and any(
                marker in key for marker in ('TAG', 'SIGNAL', 'POINT', 'CHANNEL', 'SOURCE')
            ):
                pair = (key, candidate)
                if pair not in explicit_candidates:
                    explicit_candidates.append(pair)

        generic_value = self._sanitize_candidate(self._first_non_empty(kp_map, generic_keys), allow_plain_text=True)
        label_value = self._sanitize_label(self._first_non_empty(kp_map, label_keys))
        raw_unit = self._sanitize_raw_unit(self._first_non_empty(kp_map, (f'VAR_{slot}_UNIT', f'VARIABLE_{slot}_UNIT')))

        selected_tag = ''
        selected_from = ''
        for key, candidate in explicit_candidates:
            if not validate_candidates:
                selected_tag = candidate
                selected_from = key
                break
            if self._looks_like_tag(candidate) or self._candidate_matches_sample(candidate):
                selected_tag = candidate
                selected_from = key
                break

        if not selected_tag and generic_value:
            if validate_candidates:
                if self._candidate_matches_sample(generic_value):
                    selected_tag = generic_value
                    selected_from = 'GENERIC_MATCH'
                elif self._looks_like_tag(generic_value) and not explicit_candidates:
                    selected_tag = generic_value
                    selected_from = 'GENERIC_SHAPE'
            else:
                if self._looks_like_tag(generic_value) and not explicit_candidates:
                    selected_tag = generic_value
                    selected_from = 'GENERIC_SHAPE'

        label = label_value
        if selected_tag:
            if generic_value and self._norm_tag_match(generic_value) != self._norm_tag_match(selected_tag):
                label = label or self._sanitize_label(generic_value)
        else:
            label = label or self._sanitize_label(generic_value)

        result: dict[str, Any] = {
            'slot': slot,
            'tag': str(selected_tag or '').strip(),
            'raw_unit': str(raw_unit or '').strip(),
            'label': str(label or '').strip(),
        }
        if include_debug:
            result.update(
                {
                    'generic_value': generic_value,
                    'label_value': label_value,
                    'selected_from': selected_from,
                    'explicit_candidates': [
                        {
                            'key': key,
                            'value': value,
                            'looks_like_tag': self._looks_like_tag(value),
                            'matches_sample': self._candidate_matches_sample(value),
                        }
                        for key, value in explicit_candidates
                    ],
                    'generic_matches_sample': self._candidate_matches_sample(generic_value) if generic_value else False,
                }
            )
        return result

    def _fetch_latest_samples_by_tag(self, tags: list[str]) -> dict[str, dict[str, Any]]:
        started_at = monotonic()
        self.last_samples_fallback_used = False
        self.last_samples_fallback_blocked = False
        try:
            normalized_tags: list[str] = []
            wanted_rows: list[tuple[str, str, str]] = []
            seen: set[str] = set()
            for raw_tag in tags:
                normalized_match = self._norm_tag_match(raw_tag)
                if not normalized_match or normalized_match in seen:
                    continue
                seen.add(normalized_match)
                plain = self._norm_tag(raw_tag)
                normalized_tags.append(normalized_match)
                wanted_rows.append((normalized_match, f'{plain}.', plain))

            if not normalized_tags:
                self.last_samples_source = 'EMPTY'
                self.last_samples_missing_tags = 0
                self.last_samples_missing_ratio = 0.0
                return {}

            sample_meta = self._sample_table_meta()
            if sample_meta is None or sample_meta.tag_col is None or sample_meta.value_col is None:
                self.last_samples_source = 'NO_SAMPLE_META'
                self.last_samples_missing_tags = len(normalized_tags)
                self.last_samples_missing_ratio = 1.0
                return {}

            def _reduce_rows(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
                out: dict[str, dict[str, Any]] = {}
                wanted = set(normalized_tags)
                for row in rows:
                    tag_norm = self._norm_tag_match(row.get('tag_norm') or row.get('actual_tag') or row.get('tag'))
                    if not tag_norm or tag_norm not in wanted or tag_norm in out:
                        continue
                    out[tag_norm] = {
                        'tag_norm': tag_norm,
                        'actual_tag': row.get('actual_tag') or row.get('tag') or tag_norm,
                        'value': row.get('value'),
                        'created_at': row.get('created_at') if isinstance(row.get('created_at'), datetime) else None,
                    }
                    if len(out) >= len(wanted):
                        break
                return out

            summary_rows = self._fetch_latest_samples_from_summary(normalized_tags)
            reduced = _reduce_rows(summary_rows)
            if len(reduced) == len(set(normalized_tags)):
                self.last_samples_missing_tags = 0
                self.last_samples_missing_ratio = 0.0
                return reduced

            missing = [tag_norm for tag_norm in normalized_tags if tag_norm not in reduced]
            if not missing:
                self.last_samples_missing_tags = 0
                self.last_samples_missing_ratio = 0.0
                return reduced

            missing_set = set(missing)
            fast_rows = self._fetch_latest_samples_by_tag_exact(
                sample_meta,
                [row for row in wanted_rows if row[0] in missing_set],
            )
            fast_reduced = _reduce_rows(fast_rows)
            if fast_reduced:
                reduced.update(fast_reduced)

            missing = [tag_norm for tag_norm in normalized_tags if tag_norm not in reduced]
            if not missing:
                if self.last_samples_source != 'MATVIEW':
                    self.last_samples_source = 'BASE_TABLE_EXACT'
                self.last_samples_missing_tags = 0
                self.last_samples_missing_ratio = 0.0
                return reduced

            normalized_rows = self._fetch_latest_samples_by_tag_normalized(sample_meta, missing)
            normalized_reduced = _reduce_rows(normalized_rows)
            if normalized_reduced:
                reduced.update(normalized_reduced)

            missing = [tag_norm for tag_norm in normalized_tags if tag_norm not in reduced]
            if not missing:
                if self.last_samples_source != 'MATVIEW':
                    self.last_samples_source = 'BASE_TABLE_NORM'
                self.last_samples_missing_tags = 0
                self.last_samples_missing_ratio = 0.0
                return reduced

            missing_ratio = (len(missing) / max(1, len(normalized_tags))) if normalized_tags else 0.0
            self.last_samples_missing_tags = len(missing)
            self.last_samples_missing_ratio = missing_ratio
            allow_fallback = (
                len(missing) <= max(0, int(settings.latest_samples_fallback_max_missing_tags))
                and missing_ratio <= max(0.0, float(settings.latest_samples_fallback_max_missing_ratio))
            )
            if not allow_fallback:
                self.last_samples_fallback_blocked = True
                if self.last_samples_source == 'MATVIEW':
                    self.last_samples_source = 'MATVIEW_PARTIAL'
                elif normalized_reduced:
                    self.last_samples_source = 'BASE_TABLE_NORM_PARTIAL'
                else:
                    self.last_samples_source = 'BASE_TABLE_EXACT_PARTIAL'
                return reduced

            self.last_samples_fallback_used = True
            fallback_rows = self._fetch_latest_samples_by_tag_fallback(sample_meta, missing)
            fallback_reduced = _reduce_rows(fallback_rows)
            if fallback_reduced:
                reduced.update(fallback_reduced)
                if self.last_samples_source != 'MATVIEW':
                    self.last_samples_source = 'BASE_TABLE_FALLBACK'
                self.last_samples_missing_tags = max(0, len(normalized_tags) - len(reduced))
                self.last_samples_missing_ratio = self.last_samples_missing_tags / max(1, len(normalized_tags))
            return reduced
        finally:
            self.last_samples_resolution_ms = max(0.0, (monotonic() - started_at) * 1000.0)

    def _fetch_latest_samples_by_tag_normalized(
        self,
        sample_meta: SampleTableMeta,
        missing_tags: list[str],
    ) -> list[dict[str, Any]]:
        if not missing_tags or sample_meta.tag_col is None or sample_meta.value_col is None:
            return []

        tag_sql = self._qid(sample_meta.tag_col)
        value_sql = self._qid(sample_meta.value_col)
        created_sql = self._qid(sample_meta.created_at_col) if sample_meta.created_at_col else 'NULL::timestamptz'

        if sample_meta.created_at_col:
            try:
                stmt = text(
                    f"""
                    SELECT DISTINCT ON (LOWER(TRIM(TRAILING '.' FROM {tag_sql})))
                           LOWER(TRIM(TRAILING '.' FROM {tag_sql})) AS tag_norm,
                           {tag_sql} AS actual_tag,
                           {value_sql} AS value,
                           {created_sql} AS created_at
                    FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                    WHERE LOWER(TRIM(TRAILING '.' FROM {tag_sql})) IN :tags
                    ORDER BY LOWER(TRIM(TRAILING '.' FROM {tag_sql})), {self._qid(sample_meta.created_at_col)} DESC{', ' + self._qid(sample_meta.id_col) + ' DESC' if sample_meta.id_col else ''}
                    """
                ).bindparams(bindparam('tags', expanding=True))
                rows = self.db.execute(stmt, {'tags': missing_tags}).mappings().all()
                reduced = [dict(row) for row in rows]
                if reduced:
                    return reduced
            except SQLAlchemyError:
                pass

        if sample_meta.id_col:
            try:
                stmt = text(
                    f"""
                    SELECT DISTINCT ON (LOWER(TRIM(TRAILING '.' FROM {tag_sql})))
                           LOWER(TRIM(TRAILING '.' FROM {tag_sql})) AS tag_norm,
                           {tag_sql} AS actual_tag,
                           {value_sql} AS value,
                           {created_sql} AS created_at
                    FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                    WHERE LOWER(TRIM(TRAILING '.' FROM {tag_sql})) IN :tags
                    ORDER BY LOWER(TRIM(TRAILING '.' FROM {tag_sql})), {self._qid(sample_meta.id_col)} DESC
                    """
                ).bindparams(bindparam('tags', expanding=True))
                rows = self.db.execute(stmt, {'tags': missing_tags}).mappings().all()
                reduced = [dict(row) for row in rows]
                if reduced:
                    return reduced
            except SQLAlchemyError:
                pass

        return []

    def _fetch_latest_samples_from_summary(self, normalized_tags: list[str]) -> list[dict[str, Any]]:
        summary_meta = self._latest_samples_summary_meta()
        if summary_meta is None or not normalized_tags:
            self.last_samples_source = 'BASE_TABLE'
            return []

        rows = self.db.execute(
            text(
                f"""
                SELECT {self._qid(summary_meta.tag_norm_col)} AS tag_norm,
                       {self._qid(summary_meta.actual_tag_col)} AS actual_tag,
                       {self._qid(summary_meta.value_col)} AS value,
                       {self._qid(summary_meta.created_at_col)} AS created_at
                FROM {self._qtable(summary_meta.schema, summary_meta.table)}
                WHERE {self._qid(summary_meta.tag_norm_col)} IN :tags
                """
            ).bindparams(bindparam('tags', expanding=True)),
            {'tags': normalized_tags},
        ).mappings().all()
        self.last_samples_source = 'MATVIEW'
        return [dict(row) for row in rows]

    def _fetch_latest_samples_by_tag_exact(
        self,
        sample_meta: SampleTableMeta,
        wanted_rows: list[tuple[str, str, str]],
    ) -> list[dict[str, Any]]:
        if not wanted_rows or sample_meta.tag_col is None or sample_meta.value_col is None:
            return []

        tag_sql = self._qid(sample_meta.tag_col)
        value_sql = self._qid(sample_meta.value_col)
        created_sql = self._qid(sample_meta.created_at_col) if sample_meta.created_at_col else 'NULL::timestamptz'
        order_sql = self._order_suffix(sample_meta.created_at_col, sample_meta.id_col, ascending=False)

        values_sql: list[str] = []
        params: dict[str, Any] = {}
        for idx, (tag_norm, tag_dot, tag_plain) in enumerate(wanted_rows):
            values_sql.append(f'(:tag_norm_{idx}, :tag_dot_{idx}, :tag_plain_{idx})')
            params[f'tag_norm_{idx}'] = tag_norm
            params[f'tag_dot_{idx}'] = tag_dot
            params[f'tag_plain_{idx}'] = tag_plain

        query = text(
            f"""
            WITH wanted(tag_norm, tag_dot, tag_plain) AS (
                VALUES {', '.join(values_sql)}
            )
            SELECT w.tag_norm,
                   s.actual_tag,
                   s.value,
                   s.created_at
            FROM wanted w
            LEFT JOIN LATERAL (
                SELECT {tag_sql} AS actual_tag,
                       {value_sql} AS value,
                       {created_sql} AS created_at
                FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                WHERE {tag_sql} IN (w.tag_dot, w.tag_plain)
                {order_sql}
                LIMIT 1
            ) s ON TRUE
            WHERE s.actual_tag IS NOT NULL
            """
        )
        rows = self.db.execute(query, params).mappings().all()
        return [dict(row) for row in rows]

    def _fetch_latest_samples_by_tag_fallback(
        self,
        sample_meta: SampleTableMeta,
        missing_tags: list[str],
    ) -> list[dict[str, Any]]:
        if not missing_tags or sample_meta.tag_col is None or sample_meta.value_col is None:
            return []

        tag_sql = self._qid(sample_meta.tag_col)
        value_sql = self._qid(sample_meta.value_col)
        created_sql = self._qid(sample_meta.created_at_col) if sample_meta.created_at_col else 'NULL::timestamptz'
        recent_limit = max(300, len(missing_tags) * 50)

        try:
            stmt = text(
                f"""
                SELECT LOWER(TRIM(TRAILING '.' FROM {tag_sql})) AS tag_norm,
                       {tag_sql} AS actual_tag,
                       {value_sql} AS value,
                       {created_sql} AS created_at
                FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                WHERE LOWER(TRIM(TRAILING '.' FROM {tag_sql})) IN :tags
                {self._order_suffix(sample_meta.created_at_col, sample_meta.id_col, ascending=False)}
                LIMIT :limit
                """
            ).bindparams(bindparam('tags', expanding=True))
            rows = self.db.execute(stmt, {'tags': missing_tags, 'limit': recent_limit}).mappings().all()
            reduced = [dict(row) for row in rows]
            if reduced:
                return reduced
        except SQLAlchemyError:
            pass

        try:
            rows = self.db.execute(
                text(
                    f"""
                    SELECT {tag_sql} AS actual_tag,
                           {value_sql} AS value,
                           {created_sql} AS created_at
                    FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                    {self._order_suffix(sample_meta.created_at_col, sample_meta.id_col, ascending=False)}
                    LIMIT :limit
                    """
                ),
                {'limit': max(1000, recent_limit)},
            ).mappings().all()
            return [dict(row) for row in rows]
        except SQLAlchemyError:
            return []

    def _latest_samples_summary_meta(self) -> LatestSamplesSummaryMeta | None:
        cls = self.__class__
        if cls._latest_samples_summary_detection_done:
            return cls._latest_samples_summary_meta_cache

        schema, table = self._split_qualified_name(settings.latest_samples_summary_name)
        if not self._matview_exists(schema, table) and not self._table_exists(schema, table):
            cls._latest_samples_summary_detection_done = True
            cls._latest_samples_summary_meta_cache = None
            return None

        # PostgreSQL materialized views are visible in pg_matviews, but in some
        # environments they do not surface through information_schema.columns.
        # Use pg_catalog for column discovery so we can reliably detect the MV
        # and also support plain tables used as latest-by-tag stores.
        columns = self._get_relation_columns(schema, table)
        required = {'tag_norm', 'actual_tag', 'value', 'created_at'}
        if not required.issubset(set(columns)):
            cls._latest_samples_summary_detection_done = True
            cls._latest_samples_summary_meta_cache = None
            return None

        cls._latest_samples_summary_meta_cache = LatestSamplesSummaryMeta(
            schema=schema,
            table=table,
            tag_norm_col='tag_norm',
            actual_tag_col='actual_tag',
            value_col='value',
            created_at_col='created_at',
        )
        cls._latest_samples_summary_detection_done = True
        return cls._latest_samples_summary_meta_cache

    def _matview_exists(self, schema: str, table: str) -> bool:
        result = self.db.execute(
            text(
                """
                SELECT 1
                FROM pg_matviews
                WHERE schemaname = :schema AND matviewname = :table
                LIMIT 1
                """
            ),
            {'schema': schema, 'table': table},
        ).first()
        return result is not None


    def _alerts_summary_name(self) -> str:
        return str(getattr(settings, 'alerts_summary_name', 'public.atalaya_alerts_feed_mv'))

    def _alerts_summary_meta(self) -> AlertsSummaryMeta | None:
        cls = self.__class__
        if cls._alerts_summary_detection_done:
            return cls._alerts_summary_meta_cache

        schema, table = self._split_qualified_name(self._alerts_summary_name())
        if not self._matview_exists(schema, table) and not self._table_exists(schema, table):
            cls._alerts_summary_detection_done = True
            cls._alerts_summary_meta_cache = None
            return None

        columns = self._get_columns(schema, table)
        required = {'alert_id_text', 'raw_id_text', 'description', 'severity', 'created_at'}
        if not required.issubset(set(columns)):
            cls._alerts_summary_detection_done = True
            cls._alerts_summary_meta_cache = None
            return None

        cls._alerts_summary_meta_cache = AlertsSummaryMeta(
            schema=schema,
            table=table,
            alert_id_text_col='alert_id_text',
            raw_id_text_col='raw_id_text',
            description_col='description',
            severity_col='severity',
            created_at_col='created_at',
        )
        cls._alerts_summary_detection_done = True
        return cls._alerts_summary_meta_cache

    def _fetch_alert_rows_from_summary(self, limit: int) -> list[dict[str, Any]]:
        summary_meta = self._alerts_summary_meta()
        if summary_meta is None:
            self.last_alerts_source = 'BASE_TABLE'
            return []

        rows = self.db.execute(
            text(
                f"""
                SELECT {self._qid(summary_meta.alert_id_text_col)} AS id,
                       {self._qid(summary_meta.raw_id_text_col)} AS _raw_id,
                       COALESCE({self._qid(summary_meta.description_col)}, '') AS description,
                       UPPER(COALESCE({self._qid(summary_meta.severity_col)}, 'OK')) AS severity,
                       {self._qid(summary_meta.created_at_col)} AS created_at
                FROM {self._qtable(summary_meta.schema, summary_meta.table)}
                ORDER BY {self._qid(summary_meta.created_at_col)} DESC,
                         {self._qid(summary_meta.alert_id_text_col)} DESC
                LIMIT :limit
                """
            ),
            {'limit': limit},
        ).mappings().all()
        self.last_alerts_source = 'SUMMARY_MV'
        return [dict(row) for row in rows]

    def _build_attachment_counts(self, attachment_meta: AttachmentMeta | None, raw_ids: list[str]) -> dict[str, int]:
        if attachment_meta is None or not raw_ids:
            return {}

        try:
            count_rows = self.db.execute(
                text(
                    f"""
                    SELECT {self._qid(attachment_meta.fk)}::text AS alert_id_text,
                           COUNT(*) AS cnt
                    FROM {self._qtable(attachment_meta.schema, attachment_meta.table)}
                    WHERE {self._qid(attachment_meta.fk)}::text IN :alert_ids
                    GROUP BY {self._qid(attachment_meta.fk)}::text
                    """
                ).bindparams(bindparam('alert_ids', expanding=True)),
                {'alert_ids': raw_ids},
            ).mappings().all()
        except SQLAlchemyError:
            return {}

        return {
            str(row.get('alert_id_text')): int(row.get('cnt') or 0)
            for row in count_rows
        }

    def _looks_like_mojibake(self, text_value: str) -> bool:
        if not text_value:
            return False
        markers = ('Ã', 'Â', 'â', 'ð', '�')
        return any(marker in text_value for marker in markers)

    def _try_redecode(self, text_value: str, source_encoding: str, target_encoding: str) -> str:
        try:
            repaired = text_value.encode(source_encoding, errors='strict').decode(target_encoding, errors='strict')
        except Exception:
            return text_value
        repaired = html.unescape(repaired)
        repaired = unicodedata.normalize('NFC', repaired)
        repaired = re.sub(r'[\u0000-\u001F\u007F]+', ' ', repaired)
        repaired = re.sub(r'\s+', ' ', repaired).strip()
        return repaired or text_value

    def _text_quality_score(self, text_value: str) -> int:
        if not text_value:
            return -10_000
        score = 0
        score -= text_value.count('�') * 300
        score -= text_value.count('Ã') * 120
        score -= text_value.count('Â') * 80
        score -= text_value.count('â') * 60
        score += sum(1 for ch in text_value if ch in 'áéíóúÁÉÍÓÚñÑüÜ¿¡') * 6
        score += sum(1 for ch in text_value if ch.isalnum()) // 8
        return score

    def _clean_alert_text(self, raw: Any) -> tuple[str, bool]:
        text_value = '' if raw is None else str(raw)
        text_value = html.unescape(text_value)
        text_value = unicodedata.normalize('NFC', text_value)
        text_value = re.sub(r'[\u0000-\u001F\u007F]+', ' ', text_value)
        text_value = re.sub(r'\s+', ' ', text_value).strip()
        if not text_value:
            return '', False

        candidates = [text_value]
        if self._looks_like_mojibake(text_value):
            candidates.extend(
                [
                    self._try_redecode(text_value, 'latin-1', 'utf-8'),
                    self._try_redecode(text_value, 'cp1252', 'utf-8'),
                    self._try_redecode(text_value, 'latin-1', 'cp1252'),
                ]
            )

        best = max(candidates, key=self._text_quality_score)
        return best, best != text_value


    def _fetch_alerts(self, limit: int) -> list[AlertOut]:
        alert_meta = self._alert_table_meta()
        if alert_meta is None or alert_meta.created_at_col is None:
            return []

        attachment_meta: AttachmentMeta | None
        try:
            attachment_meta = self._attachment_meta()
        except SQLAlchemyError:
            attachment_meta = None

        rows = self._fetch_alert_rows_from_summary(limit=limit)

        if not rows:
            a_created = self._qcol('a', alert_meta.created_at_col)
            a_id = self._qcol('a', alert_meta.id_col) if alert_meta.id_col else None
            a_desc = self._qcol('a', alert_meta.description_col) if alert_meta.description_col else None
            a_sev = self._qcol('a', alert_meta.severity_col) if alert_meta.severity_col else None

            id_expr = f'{a_id}::text' if a_id else 'NULL::text'
            raw_id_expr = f'{a_id}::text AS _raw_id' if a_id else 'NULL::text AS _raw_id'
            desc_expr = f"COALESCE({a_desc}, '')" if a_desc else "''::text"
            sev_expr = f"UPPER(COALESCE({a_sev}, 'OK'))" if a_sev else "'OK'::text"

            order_sql = f'ORDER BY {a_created} DESC'
            if a_id is not None:
                order_sql += f', {a_id} DESC'

            rows = [dict(row) for row in self.db.execute(
                text(
                    f"""
                    SELECT {id_expr} AS id,
                           {raw_id_expr},
                           {desc_expr} AS description,
                           {sev_expr} AS severity,
                           {a_created} AS created_at
                    FROM {self._qtable(alert_meta.schema, alert_meta.table)} a
                    {order_sql}
                    LIMIT :limit
                    """
                ),
                {'limit': limit},
            ).mappings().all()]
            self.last_alerts_source = 'BASE_TABLE'

        raw_ids = [str(row.get('_raw_id')).strip() for row in rows if str(row.get('_raw_id') or '').strip()]
        attachment_counts = self._build_attachment_counts(attachment_meta, raw_ids)

        alerts: list[AlertOut] = []
        repairs = 0
        for index, row in enumerate(rows):
            created_at = row.get('created_at')
            if not isinstance(created_at, datetime):
                continue

            severity = self._normalize_severity(row.get('severity'))
            description_raw = str(row.get('description') or '')
            description, changed = self._clean_alert_text(description_raw)
            if changed:
                repairs += 1

            row_id = str(row.get('id') or '').strip()
            if not row_id:
                row_id = self._synthetic_alert_id(created_at, description, severity, index)

            raw_id = str(row.get('_raw_id') or '').strip()
            attachments_count = attachment_counts.get(raw_id, 0) if raw_id else 0

            alerts.append(
                AlertOut(
                    id=row_id,
                    description=description,
                    severity=severity,
                    createdAt=created_at,
                    attachmentsCount=attachments_count,
                    attachments=[],
                )
            )

        self.last_alerts_text_repairs = repairs
        return alerts

    def _alert_table_meta(self) -> AlertTableMeta | None:
        cls = self.__class__
        if cls._alert_detection_done:
            return cls._alert_meta_cache

        schema, table = 'public', 'atalaya_alerts'
        if not self._table_exists(schema, table):
            cls._alert_detection_done = True
            cls._alert_meta_cache = None
            return None

        columns = self._get_columns(schema, table)
        if not columns:
            cls._alert_detection_done = True
            cls._alert_meta_cache = None
            return None

        cls._alert_meta_cache = AlertTableMeta(
            schema=schema,
            table=table,
            id_col=self._pick_first(columns, 'id', 'alert_id', 'atalaya_alert_id'),
            description_col=self._pick_first(columns, 'description', 'message', 'comment', 'comments', 'text', 'details', 'alert_description'),
            severity_col=self._pick_first(columns, 'severity', 'level', 'status', 'priority'),
            created_at_col=self._pick_first(columns, 'created_at', 'created', 'alert_time', 'timestamp', 'ts', 'event_time', 'time'),
        )
        cls._alert_detection_done = True
        return cls._alert_meta_cache

    def _attachment_meta(self) -> AttachmentMeta | None:
        cls = self.__class__
        if cls._attachment_detection_done:
            return cls._attachment_meta_cache

        for candidate in settings.attachment_table_candidates:
            schema, table = self._split_qualified_name(candidate)
            if not self._table_exists(schema, table):
                continue
            columns = self._get_columns(schema, table)
            if not columns:
                continue

            fk = self._pick_first(columns, 'alert_id', 'atalaya_alert_id', 'atalaya_alerts_id')
            if fk is None:
                continue

            cls._attachment_meta_cache = AttachmentMeta(
                schema=schema,
                table=table,
                fk=fk,
                id_col=self._pick_first(columns, 'id', 'attachment_id', 'file_id'),
                name_col=self._pick_first(columns, 'file_name', 'filename', 'name', 'original_name'),
                url_col=self._pick_first(columns, 'file_url', 'url', 'href', 'download_url', 's3_url', 'path'),
                mime_col=self._pick_first(columns, 'mime_type', 'content_type', 'mime'),
                size_col=self._pick_first(columns, 'file_size', 'size', 'bytes'),
                created_at_col=self._pick_first(columns, 'created_at', 'created', 'uploaded_at'),
            )
            cls._attachment_detection_done = True
            return cls._attachment_meta_cache

        cls._attachment_detection_done = True
        cls._attachment_meta_cache = None
        return None

    def _sample_table_meta(self) -> SampleTableMeta | None:
        cls = self.__class__
        if cls._sample_detection_done:
            return cls._sample_meta_cache

        schema, table = 'public', 'atalaya_samples'
        if not self._table_exists(schema, table):
            cls._sample_detection_done = True
            cls._sample_meta_cache = None
            return None

        columns = self._get_columns(schema, table)
        if not columns:
            cls._sample_detection_done = True
            cls._sample_meta_cache = None
            return None

        cls._sample_meta_cache = SampleTableMeta(
            schema=schema,
            table=table,
            tag_col=self._pick_first(columns, 'tag', 'signal', 'name'),
            value_col=self._pick_first(columns, 'value', 'val', 'reading', 'sample_value'),
            created_at_col=self._pick_first(columns, 'created_at', 'created', 'timestamp', 'ts', 'sample_time', 'event_time', 'time'),
            id_col=self._pick_first(columns, 'id', 'sample_id', 'atalaya_sample_id'),
        )
        cls._sample_detection_done = True
        return cls._sample_meta_cache

    def _table_exists(self, schema: str, table: str) -> bool:
        result = self.db.execute(
            text(
                """
                SELECT 1
                FROM information_schema.tables
                WHERE table_schema = :schema AND table_name = :table
                LIMIT 1
                """
            ),
            {'schema': schema, 'table': table},
        ).first()
        return result is not None

    def _get_columns(self, schema: str, table: str) -> list[str]:
        rows = self.db.execute(
            text(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = :schema AND table_name = :table
                ORDER BY ordinal_position
                """
            ),
            {'schema': schema, 'table': table},
        ).all()
        columns = [str(row[0]) for row in rows]
        if columns:
            return columns

        # PostgreSQL materialized views may be queryable even when they do not
        # appear in information_schema.columns for the current session. Fall back
        # to pg_catalog so v3 can detect the MV and stop dropping to BASE_TABLE_EXACT.
        rows = self.db.execute(
            text(
                """
                SELECT a.attname
                FROM pg_catalog.pg_attribute a
                JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
                JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
                WHERE n.nspname = :schema
                  AND c.relname = :table
                  AND a.attnum > 0
                  AND NOT a.attisdropped
                ORDER BY a.attnum
                """
            ),
            {'schema': schema, 'table': table},
        ).all()
        return [str(row[0]) for row in rows]

    def _get_relation_columns(self, schema: str, table: str) -> list[str]:
        """Return relation columns for tables/views/materialized views via pg_catalog."""
        rows = self.db.execute(
            text(
                """
                SELECT a.attname
                FROM pg_catalog.pg_attribute a
                JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = :schema
                  AND c.relname = :table
                  AND a.attnum > 0
                  AND NOT a.attisdropped
                ORDER BY a.attnum
                """
            ),
            {'schema': schema, 'table': table},
        ).all()
        return [str(row[0]) for row in rows]


    def _raw_unit_for_tag(self, kp_map: dict[str, Any], normalized_tag: str) -> str:
        normalized_match = self._norm_tag_match(normalized_tag)
        for slot in self._configured_slots(kp_map, validate_candidates=False):
            if self._norm_tag_match(str(slot['tag'])) == normalized_match:
                return self._sanitize_raw_unit(slot['raw_unit'])
        return ''

    def _candidate_matches_sample(self, candidate: str) -> bool:
        candidate = self._sanitize_candidate(candidate)
        tag = self._norm_tag_match(candidate)
        if not tag:
            return False

        now = monotonic()
        with self.__class__._sample_exists_cache_lock:
            cached = self.__class__._sample_exists_cache.get(tag)
            if cached is not None and now < cached[1]:
                return cached[0]

        sample_meta = self._sample_table_meta()
        if sample_meta is None or sample_meta.tag_col is None:
            return False
        try:
            row = self.db.execute(
                text(
                    f"""
                    SELECT 1
                    FROM {self._qtable(sample_meta.schema, sample_meta.table)}
                    WHERE LOWER(TRIM(TRAILING '.' FROM {self._qid(sample_meta.tag_col)})) = :tag
                    LIMIT 1
                    """
                ),
                {'tag': tag},
            ).first()
            exists = row is not None
        except SQLAlchemyError:
            exists = False

        ttl = max(1.0, float(settings.sample_tag_existence_cache_ttl_seconds))
        with self.__class__._sample_exists_cache_lock:
            self.__class__._sample_exists_cache[tag] = (exists, now + ttl)
        return exists

    def _exact_tag_variants(self, raw_tag: str) -> list[str]:
        plain = self._norm_tag(raw_tag)
        if not plain:
            return []
        dot = f'{plain}.'
        return [dot, plain] if dot != plain else [plain]

    def _looks_like_tag(self, value: str) -> bool:
        text_value = self._sanitize_candidate(value)
        if not text_value:
            return False
        upper = text_value.upper()
        if upper in {'RAW', 'TRUE', 'FALSE', 'ON', 'OFF'}:
            return False
        if ' ' in text_value:
            return False
        if any(ch in text_value for ch in ('.', ':', '/', '-')):
            return True
        if '_' in text_value and any(ch.isdigit() for ch in text_value):
            return True
        return False

    def _looks_like_css_or_blob(self, value: Any) -> bool:
        text_value = str(value or '').strip()
        if not text_value:
            return False
        if len(text_value) > 80:
            return True
        lowered = text_value.lower()
        blob_markers = ('{', '}', ':root', '--blue-', '--green-', '<html', '<body', 'background:', 'color:')
        return any(marker in lowered for marker in blob_markers)

    def _sanitize_candidate(self, value: Any, *, allow_plain_text: bool = False) -> str:
        text_value = str(value or '').strip()
        if not text_value:
            return ''
        if self._looks_like_css_or_blob(text_value):
            return ''
        if len(text_value) > 64:
            return ''
        if not allow_plain_text and text_value.lower() in {'raw', 'true', 'false', 'on', 'off'}:
            return ''
        return text_value

    def _sanitize_label(self, value: Any) -> str:
        text_value = str(value or '').strip()
        if not text_value:
            return ''
        if self._looks_like_css_or_blob(text_value):
            return ''
        if len(text_value) > 48:
            return ''
        if text_value.lower() in {'raw', 'true', 'false', 'on', 'off'}:
            return ''
        return text_value

    def _sanitize_raw_unit(self, value: Any) -> str:
        text_value = str(value or '').strip()
        if not text_value:
            return ''
        if self._looks_like_css_or_blob(text_value):
            return ''
        if len(text_value) > 24:
            return ''
        normalized = text_value.strip()
        lowered = normalized.lower().replace(' ', '')
        allowed = {
            'psi': 'psi',
            'psia': 'psi',
            'bar': 'bar',
            'kpa': 'kPa',
            'mpa': 'MPa',
            'm': 'm',
            'ft': 'ft',
            'm/min': 'm/min',
            'ft/min': 'ft/min',
            'm3/min': 'm3/min',
            'm³/min': 'm3/min',
            'bbl/min': 'bbl/min',
            'bpm': 'bbl/min',
            'lb': 'lbs',
            'lbs': 'lbs',
            'lbf': 'lbs',
            'klbf': 'klbf',
            'kn': 'kN',
            'ton': 'ton',
            'ton(us)': 'ton (US)',
            'ton(us': 'ton (US)',
            '°c': '°C',
            'degc': '°C',
            'c': '°C',
            '°f': '°F',
            'degf': '°F',
            'f': '°F',
        }
        return allowed.get(lowered, '')

    def _preview_value(self, value: Any, limit: int = 160) -> str:
        text_value = str(value or '').strip()
        if len(text_value) <= limit:
            return text_value
        return text_value[:limit] + '…'

    def _is_interesting_kp_key(self, key_norm: str) -> bool:
        if not key_norm:
            return False
        prefixes = ('CURRENT_', 'VAR_', 'VARIABLE_', 'SLOT_', 'TAG_', 'SIGNAL_', 'POINT_')
        if key_norm.startswith(prefixes):
            return True
        markers = ('_TAG', '_UNIT', '_LABEL', '_NAME', '_DESC', '_TEXT', '_SIGNAL', '_SOURCE', '_CHANNEL', '_POINT')
        return any(marker in key_norm for marker in markers)

    def _is_allowed_attachment_url(self, raw_url: str) -> bool:
        url = (raw_url or '').strip()
        if not url:
            return False

        parsed = urlparse(url)
        if parsed.scheme.lower() != 'https':
            return False

        hostname = (parsed.hostname or '').lower()
        if not settings.allowed_attachment_hosts:
            return True

        for allowed in settings.allowed_attachment_hosts:
            allowed_host = allowed.lower().strip()
            if hostname == allowed_host or hostname.endswith(f'.{allowed_host}'):
                return True
        return False

    def _normalize_severity(self, raw: Any) -> str:
        value = str(raw or 'OK').strip().upper()
        if value in {'OK', 'ATTENTION', 'CRITICAL'}:
            return value
        return 'OK'

    def _coerce_sample_value(self, raw: Any) -> float | str | None:
        if raw is None:
            return None
        numeric = self._as_float(raw)
        if numeric is not None:
            return numeric
        text_value = str(raw).strip()
        return text_value or None

    def _norm_key(self, value: Any) -> str:
        return str(value or '').strip().upper()

    def _norm_tag(self, value: Any) -> str:
        tag = str(value or '').strip()
        while tag.endswith('.'):
            tag = tag[:-1]
        return tag.strip()

    def _norm_tag_match(self, value: Any) -> str:
        return self._norm_tag(value).lower()

    def _humanize_label(self, normalized_tag: str) -> str:
        value = normalized_tag.replace('.', '').replace('_', ' ').strip()
        return value or normalized_tag or 'VAR'

    def _split_qualified_name(self, candidate: str) -> tuple[str, str]:
        if '.' not in candidate:
            return 'public', candidate
        schema, table = candidate.split('.', 1)
        return schema, table

    def _pick_first(self, columns: list[str], *candidates: str) -> str | None:
        for candidate in candidates:
            if candidate in columns:
                return candidate
        return None

    def _first_non_empty(self, mapping: dict[str, Any], keys: tuple[str, ...]) -> str:
        for key in keys:
            value = mapping.get(self._norm_key(key))
            if value not in (None, ''):
                return str(value).strip()
        return ''

    def _synthetic_alert_id(self, created_at: datetime, description: str, severity: str, position: int) -> str:
        basis = f'{created_at.isoformat()}|{description}|{severity}|{position}'
        return 'synthetic-' + hashlib.sha1(basis.encode('utf-8')).hexdigest()[:16]

    def _qid(self, identifier: str | None) -> str:
        if not identifier:
            return ''
        return '"' + str(identifier).replace('"', '""') + '"'

    def _qtable(self, schema: str, table: str) -> str:
        return f'{self._qid(schema)}.{self._qid(table)}'

    def _qcol(self, alias: str, column: str | None) -> str:
        return f'{alias}.{self._qid(column)}' if column else ''

    def _order_suffix(self, created_at_col: str | None, id_col: str | None, *, ascending: bool) -> str:
        direction = 'ASC' if ascending else 'DESC'
        if created_at_col and id_col:
            return f'ORDER BY {self._qid(created_at_col)} {direction}, {self._qid(id_col)} {direction}'
        if created_at_col:
            return f'ORDER BY {self._qid(created_at_col)} {direction}'
        if id_col:
            return f'ORDER BY {self._qid(id_col)} {direction}'
        return f'ORDER BY ctid {direction}'

    def _as_float(self, raw: Any) -> float | None:
        if raw is None:
            return None
        if isinstance(raw, (int, float)):
            return float(raw)
        try:
            return float(str(raw).strip())
        except (TypeError, ValueError):
            return None

    def _as_int(self, raw: Any) -> int | None:
        if raw is None:
            return None
        if isinstance(raw, int):
            return raw
        try:
            return int(str(raw).strip())
        except (TypeError, ValueError):
            return None
