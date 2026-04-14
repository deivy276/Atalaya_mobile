from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPO_ROOT / 'backend_fastapi'
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

"""Quick benchmark for Phase C KPI latest-samples query paths.

Runs EXPLAIN (ANALYZE, BUFFERS) on:
1) summary table/MV lookup by tag_norm
2) exact latest-by-tag for plain/dotted variants
3) normalized DISTINCT ON latest-by-tag

Usage:
  python checks/check_v4_kpi_query_paths_benchmark.py --tags spp,rpm,wob
"""

import argparse
import re
from typing import Iterable

from sqlalchemy import bindparam, text

from app.database import _ensure_session_factory


TOTAL_TIME_RE = re.compile(r"Execution Time:\s+([0-9.]+)\s+ms", re.IGNORECASE)


def _extract_execution_ms(plan_lines: Iterable[str]) -> float | None:
    for line in plan_lines:
        match = TOTAL_TIME_RE.search(line)
        if match:
            return float(match.group(1))
    return None


def _run_explain(db, sql: str, params: dict) -> tuple[list[str], float | None]:
    rows = db.execute(text(sql).bindparams(bindparam('tags', expanding=True)), params).all()
    plan_lines = [str(item[0]) for item in rows]
    return plan_lines, _extract_execution_ms(plan_lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--tags', default='spp,rpm', help='Comma-separated normalized tags')
    args = parser.parse_args()

    tags = [item.strip().lower() for item in args.tags.split(',') if item.strip()]
    if not tags:
        raise SystemExit('No tags provided')

    session_factory = _ensure_session_factory()
    with session_factory() as db:
        print('== Phase C KPI query-path benchmark ==')
        print('tags =', tags)

        summary_sql = """
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT tag_norm, actual_tag, value, created_at
        FROM public.atalaya_latest_samples_mv
        WHERE tag_norm IN :tags
        """

        dotted = [f"{tag}." for tag in tags]
        exact_candidates = list(dict.fromkeys(tags + dotted))

        exact_sql = """
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT DISTINCT ON (tag)
               tag AS actual_tag,
               value,
               created_at
        FROM public.atalaya_samples
        WHERE tag IN :tags
        ORDER BY tag, created_at DESC
        """

        normalized_sql = """
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT DISTINCT ON (LOWER(TRIM(TRAILING '.' FROM tag)))
               LOWER(TRIM(TRAILING '.' FROM tag)) AS tag_norm,
               tag AS actual_tag,
               value,
               created_at
        FROM public.atalaya_samples
        WHERE LOWER(TRIM(TRAILING '.' FROM tag)) IN :tags
        ORDER BY LOWER(TRIM(TRAILING '.' FROM tag)), created_at DESC
        """

        for name, sql in (
            ('SUMMARY_MV', summary_sql),
            ('BASE_TABLE_EXACT', exact_sql),
            ('BASE_TABLE_NORM', normalized_sql),
        ):
            print()
            print(f'-- {name} --')
            params = {'tags': exact_candidates} if name == 'BASE_TABLE_EXACT' else {'tags': tags}
            lines, elapsed = _run_explain(db, sql, params)
            for line in lines:
                print(line)
            print('execution_ms =', elapsed)


if __name__ == '__main__':
    main()
