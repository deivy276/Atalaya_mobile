"""Print EXPLAIN plan for normalized latest-by-tag lookup and index-usage hint."""

from pathlib import Path
import sys

from sqlalchemy import text

REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPO_ROOT / 'backend_fastapi'
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.database import BackendConfigurationError, _ensure_session_factory


def main() -> int:
    try:
        session_factory = _ensure_session_factory()
    except BackendConfigurationError as exc:
        print('Backend DB configuration is incomplete for plan check execution.')
        print(f'detail: {exc}')
        return 2

    with session_factory() as db:
        print('== explain normalized latest-by-tag lookup ==')
        rows = db.execute(
            text(
                """
                EXPLAIN
                SELECT DISTINCT ON (LOWER(TRIM(TRAILING '.' FROM tag)))
                       LOWER(TRIM(TRAILING '.' FROM tag)) AS tag_norm,
                       tag AS actual_tag,
                       value,
                       created_at
                FROM public.atalaya_samples
                WHERE LOWER(TRIM(TRAILING '.' FROM tag)) IN ('spp','rpm')
                ORDER BY LOWER(TRIM(TRAILING '.' FROM tag)), created_at DESC
                """
            )
        ).all()
        plan_lines = [str(item[0]) for item in rows]
        for line in plan_lines:
            print(line)

        has_idx = any('idx_samples_tag_norm_created_at_desc' in line for line in plan_lines)
        print()
        print('uses idx_samples_tag_norm_created_at_desc =', has_idx)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
